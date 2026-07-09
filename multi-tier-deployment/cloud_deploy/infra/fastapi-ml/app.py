from fastapi import FastAPI, File, UploadFile, Form  # ### added Form
from fastapi.responses import JSONResponse
from PIL import Image
from io import BytesIO
import time
import psutil
from ultralytics import YOLO
import os
import logging
import requests  # ### added requests for forwarding to IoT Agent

# Create logger once at top
logger = logging.getLogger("inference")
logging.basicConfig(level=logging.INFO)

# Silence python-multipart DEBUG logs
logging.getLogger("multipart").setLevel(logging.WARNING)

# Load model config & IoT Agent config from env (minimal changes)
model_dir = os.getenv("MODEL_DIR", "yolo11m_openvino_model/")
IOT_URL = os.getenv("IOT_URL", "http://fiware-iot-agent:7896/iot/json")  # ### IoT Agent base URL (no query params)
IOT_KEY = os.getenv("IOT_KEY", "12345")  # ### API key for IoT Agent

# Load the model once at startup
model = YOLO(model_dir, task="detect")

# Force a dummy prediction to ensure .names is initialized
_ = model.predict(Image.new("RGB", (640, 480)))  # dummy black image
class_names = model.names  # now safely populated

app = FastAPI()


@app.post("/predict")
async def predict(file: UploadFile = File(...), entity_id: str = Form(None)):  # ### accept entity_id form field
    try:
        # Read the image into memory
        contents = await file.read()
        img_object = Image.open(BytesIO(contents)).convert("RGB")

        # Start timing
        start_time = time.time()
        results = model.predict(img_object, verbose=False, show=False)
        end_time = time.time()

        inference_time = end_time - start_time
        # find class index for 'car' (keep your original logic)
        car_id = list(class_names)[list(class_names.values()).index('car')]
        detected_classes = results[0].boxes.cls.tolist()
        cars_objects = detected_classes.count(car_id)

        cpu_usage = psutil.cpu_percent()
        memory = psutil.virtual_memory().used / (1024 ** 2)  # In MB

        logger.info(f"Inference finished: {inference_time: .6f} sec, cars={cars_objects}, CPU={cpu_usage}%, MEM={memory:.1f}MB")

        # ### Minimal forwarding: build device id and POST to IoT Agent JSON
        # If entity_id provided as URN (e.g. urn:ngsi-ld:OffStreetParking:001) extract last segment;
        # if user sent a plain numeric id, use it directly.
        device_id = None
        if entity_id:
            # robust extraction: take last colon-separated part and strip whitespace
            device_id = entity_id.split(":")[-1].strip()
        else:
            # not provided: log and skip forwarding
            logger.warning("No entity_id form field provided; skipping IoT Agent update.")
            device_id = None

        if device_id:
            try:
                payload = {"occupied_spots": cars_objects}
                # Build URL exactly like your load generator did: add ?k=API_KEY&i=device_id
                forward_url = f"{IOT_URL}?k={IOT_KEY}&i={device_id}"
                resp = requests.post(forward_url, json=payload, timeout=10)
                logger.info(f"Forwarded to IoT Agent: url={forward_url} status={resp.status_code} payload={payload}")
            except requests.RequestException as e:
                logger.exception(f"Failed forwarding to IoT Agent for device {device_id}: {e}")

        return JSONResponse(content={
            "car_objects": cars_objects,
            "inference_time": inference_time,
            "cpu_usage": cpu_usage,
            "memory": memory
        })

    except Exception as e:
        logger.exception("Error during /predict")
        return JSONResponse(content={"error": str(e)}, status_code=500)

