# streamlit_app/llm_client.py
# Minimal helper to call an LLM and extract a JSON of parameters.
# Designed for Mistral-like APIs if configured, otherwise attempts to parse JSON from text.

import os
import json
import re
from typing import Dict, Optional
import logging
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("llm_client")

API_URL = os.getenv("API_URL")
API_KEY = os.getenv("API_KEY")
LLM_MODEL = os.getenv("LLM_MODEL", "deepseek-r1:1.5b")

# Try to load API key from env or local file
def load_api_key() -> Optional[str]:
    k = os.environ.get("API_KEY")
    if k:
        return k
    # fallback to reading ./api.key if present
    try:
        here = os.path.dirname(__file__)
        candidate = os.path.join(here, "..", "llm_api.key")
        if os.path.exists(candidate):
            with open(candidate, "r") as fh:
                return fh.read().strip()
        # also check repo root path
        if os.path.exists("llm_api.key"):
            with open("llm_api.key", "r") as fh:
                return fh.read().strip()
    except Exception:
        pass
    return None

def extract_json(text: str):
    """
    Extract a JSON object from a model response that may include markdown
    code fences (```json ... ```). Returns a dict or {}.
    """
    if not text:
        return {}

    # Remove code fences
    cleaned = text.strip()
    cleaned = re.sub(r"^```json", "", cleaned, flags=re.IGNORECASE).strip()
    cleaned = re.sub(r"^```", "", cleaned, flags=re.IGNORECASE).strip()
    cleaned = re.sub(r"```$", "", cleaned, flags=re.IGNORECASE).strip()

    # Extract first {...} block
    m = re.search(r"\{.*\}", cleaned, flags=re.DOTALL)
    if not m:
        return {}

    json_str = m.group(0)

    try:
        return json.loads(json_str)
    except Exception:
        return {}


def call_llm_api(api_key: str, user_message: str, history: list = None, api_url: Optional[str] = None) -> Optional[str]:
    """
    Minimal call adapted for the real IC UNICAMP API /api/chat/completions.
    """
    if not api_key:
        return None

    api_url = api_url or os.environ.get("API_URL")
    if not api_url:
        return None

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    messages = []

    if history:
        for m in history:
            if "role" in m and "content" in m:
                messages.append({"role": m["role"], "content": m["content"]})

    messages.insert(0, {
    "role": "system",
    "content": (
        "You are a STRICT JSON parameter extractor.\n\n"

        "TASK:\n"
        "Extract parameters explicitly mentioned by the user.\n\n"

        "OUTPUT RULES:\n"
        "- Output ONLY a valid JSON object.\n"
        "- No text outside JSON.\n"
        "- If no parameters are mentioned, output {}.\n"
        "- NEVER guess, infer, or assume values.\n\n"

        "VALID PARAMETERS (with types):\n"
        "- percent_arrivals: float (delta, decimal fraction)\n"
        "- percent_dwell_time: float (delta, decimal fraction)\n"
        "- num_simulations: integer (absolute)\n"
        "- spots: integer (absolute count, NOT a percentage, NOT a delta)\n"
        "- modify_from: string (HH:MM)\n"
        "- modify_to: string (HH:MM)\n"
        "- prediction_interval_value: float\n\n"

        "STRICT CONSTRAINTS:\n"
        "- Percentages → decimal fractions (20% → 0.2).\n"
        "- Times → HH:MM.\n"
        "- 'spots' MUST be an absolute integer.\n"
        "- NEVER output spots=0 unless the user explicitly says 0.\n"
        "- NEVER output a parameter that was not explicitly stated.\n\n"

        "EXAMPLES:\n\n"

        "User: \"Run the simulation with 14 spots\"\n"
        "Assistant: {\"spots\": 14}\n\n"

        "User: \"Increase arrivals by 20%\"\n"
        "Assistant: {\"percent_arrivals\": 0.2}\n\n"

        "User: \"Increase spots by 20%\"\n"
        "Assistant: {}\n\n"

        "User: \"Run 5000 simulations\"\n"
        "Assistant: {\"num_simulations\": 5000}\n\n"

        "User: \"From 12:00 to 16:00 arrivals decrease by 10%\"\n"
        "Assistant: {\"percent_arrivals\": -0.1, \"modify_from\": \"12:00\", \"modify_to\": \"16:00\"}\n"
    )
})


    # Add user message properly
    messages.append({
        "role": "user",
        "content": user_message
    })

    # Correct payload
    payload = {
        "model": LLM_MODEL,
        "messages": messages
    }

    try:
        resp = requests.post(api_url, headers=headers, json=payload, timeout=30)

        logger.info(f"LLM API response status: {resp.text}")

        if resp.status_code == 200:
            data = resp.json()

            # Correct extraction path
            # data -> choices -> message -> content
            if (
                isinstance(data, dict)
                and "choices" in data
                and isinstance(data["choices"], list)
                and len(data["choices"]) > 0
                and "message" in data["choices"][0]
                and isinstance(data["choices"][0]["message"], dict)
            ):
                return data["choices"][0]["message"].get("content")

            return resp.text

    except Exception:
        return None


def interpret_user_message(user_message: str, history: list = None) -> Dict:
    """
    Given a natural language user_message, return a dict with only the keys
    inferred from the message (partial JSON).
    Returned dict contains only fields found (e.g. percent_arrivals, modify_from, modify_to, num_simulations, spots, percent_dwell_time).
    """
    api_key = load_api_key()
    assistant_text = None

    # 1) try calling remote LLM if configured
    if api_key and os.environ.get("API_URL"):
        assistant_text = call_llm_api(api_key, user_message, history=history, api_url=os.environ.get("API_URL"))

    # 2) fallback to using the user's input as 'assistant text' (useful for quick testing)
    if not assistant_text:
        # Many users may directly paste a JSON in the chat, so prefer to parse user message first
        assistant_text = user_message

    # 3) attempt extracting JSON from assistant_text
    parsed = extract_json(assistant_text)
    if parsed == {}:
        return {}
    
    if not parsed:
        return {}
    # Normalize keys and simple value parsing
    normalized = {}
    for k, v in parsed.items():
        key = k.strip()
        val = v
        if isinstance(val, str):
            # percent strings like "20%" or "20" -> convert to float fraction for percent fields
            if val.endswith("%"):
                try:
                    num = float(val.strip("%"))
                    normalized[key] = num / 100.0
                    continue
                except Exception:
                    pass
            # numeric strings
            try:
                if re.match(r"^-?\d+(\.\d+)?$", val):
                    # decide int/float
                    if "." in val:
                        normalized[key] = float(val)
                    else:
                        normalized[key] = int(val)
                    continue
            except Exception:
                pass
            # times like "14:00"
            normalized[key] = val
        else:
            normalized[key] = val
    return normalized
