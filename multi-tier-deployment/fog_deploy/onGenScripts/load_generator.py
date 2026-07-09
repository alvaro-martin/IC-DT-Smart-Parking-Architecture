#!/usr/bin/env python3
"""
load_generator.py
Run load generator with parameters passed via CLI and produce uniquely named output files.

Example:
  python3 load_generator.py --M 136 --N 30 --seeds 20 --alpha 5 --beta 5 --image ./test.jpg --url http://localhost:8000/predict
"""

import argparse
import numpy as np
import requests
import time
import csv
import os
import logging
import sys
import subprocess
from datetime import datetime
from scipy.stats import beta as beta_dist
from concurrent.futures import ThreadPoolExecutor

# -------------------
# Helpers
# -------------------
def allocate_points_beta(N, M, alpha, beta_param, seed=None):
    x = np.linspace(0, 1, N)
    pdf = beta_dist.pdf(x, alpha, beta_param)
    # if the pdf is zero everywhere (rare for extreme params), fallback to uniform
    if np.all(pdf == 0):
        weights = np.ones_like(pdf) / pdf.size
    else:
        weights = pdf / pdf.sum()
    allocations = (weights * M).astype(int)
    diff = M - allocations.sum()
    if diff != 0:
        rng = np.random.default_rng(seed)
        idxs = rng.choice(N, size=abs(diff), replace=True)
        for idx in idxs:
            allocations[idx] += 1 if diff > 0 else -1
    return allocations

def send_request(device_id, seed_val, results, url, timeout, image_path, logger=None):
    """
    Sends one POST request with image file AND the entity/device id included as a form field,
    then appends (seed, timestamp, device, entity, status, latency_ms) to results list.
    `logger` is optional; if None we get the 'load_generator' logger and add a NullHandler if needed.
    """
    # Safe logger fallback: avoids AttributeError if caller didn't pass a logger
    if logger is None:
        logger = logging.getLogger("load_generator")
        if not logger.handlers:
            # avoid propagating to root handlers and ensure logger.debug exists
            logger.addHandler(logging.NullHandler())

    timestamp = datetime.utcnow().isoformat() + "Z"
    entity_id = f"urn:ngsi-ld:OffStreetParking:{device_id}"
    start = time.perf_counter()
    try:
        with open(image_path, "rb") as img_file:
            files = {"file": (os.path.basename(image_path), img_file, "image/jpeg")}
            # <-- Minimal change: include the entity/device id as a form field so the FastAPI service
            #     knows which device/entity the image belongs to.
            data = {"entity_id": entity_id}
            resp = requests.post(url, files=files, data=data, timeout=timeout)

        latency = (time.perf_counter() - start) * 1000.0
        status = resp.status_code
        results.append((seed_val, timestamp, device_id, entity_id, status, f"{latency:.2f}"))

        # Log response JSON or text.
        try:
            resp_json = resp.json()
            logger.info(f"Response from {device_id}: {resp_json}")
        except ValueError:
            logger.info(f"Response from {device_id}: {resp.text.strip()}")
        logger.debug(f"REQ seed={seed_val} device={device_id} url={url} status={status} latency_ms={latency:.2f}")
    except requests.exceptions.RequestException as e:
        latency = (time.perf_counter() - start) * 1000.0
        results.append((seed_val, timestamp, device_id, entity_id, "FAILED", f"{latency:.2f}"))
        logger.debug(f"REQ FAILED seed={seed_val} device={device_id} url={url} err={e} latency_ms={latency:.2f}")

# -------------------
# CLI
# -------------------
def parse_args():
    p = argparse.ArgumentParser(description="Load generator for FIWARE IoT agent.")
    p.add_argument("--M", type=int, required=True, help="Number of devices (M).")
    p.add_argument("--N", type=int, required=True, help="Number of seconds / bins (N).")
    p.add_argument("--seeds", type=int, required=True, help="Number of cycles (seed count). Uses seeds 1..seeds inclusive.")
    p.add_argument("--alpha", type=float, default=5.0, help="Beta distribution alpha.")
    p.add_argument("--beta", type=float, default=5.0, help="Beta distribution beta.")
    p.add_argument("--max-workers", type=int, default=100, help="Max workers for ThreadPoolExecutor.")
    p.add_argument("--out-dir", type=str, default=".", help="Directory to write output files.")
    p.add_argument("--url", type=str, default="http://localhost:7896/iot/json", help="Base URL for POST requests.")
    p.add_argument("--timeout", type=float, default=300, help="Request timeout in seconds.")
    p.add_argument("--image", type=str, required=True, help="Path to image file to upload.")
    return p.parse_args()

# -------------------
# Logging setup (file only — no console output)
# -------------------
def setup_logger(log_file_path):
    logger = logging.getLogger("load_generator")
    logger.setLevel(logging.DEBUG)

    # If handlers already exist, clear them to ensure only file handler is present
    if logger.handlers:
        for h in list(logger.handlers):
            logger.removeHandler(h)

    # File handler (DEBUG -> full details)
    fh = logging.FileHandler(log_file_path, mode="a")
    fh.setLevel(logging.DEBUG)
    fh_formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s", "%Y-%m-%dT%H:%M:%S")
    fh.setFormatter(fh_formatter)
    logger.addHandler(fh)

    return logger


# -------------------
# Main
# -------------------
def main():
    args = parse_args()

    M = args.M
    N = args.N
    seed_count = args.seeds
    alpha = args.alpha
    beta_param = args.beta
    max_workers = args.max_workers
    out_dir = os.path.abspath(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)
    base_url = args.url
    timeout = args.timeout
    image_path = args.image


    # Build filenames (same suffix logic as before)
    def fmt_num(x):
        try:
            return int(x) if float(x).is_integer() else x
        except Exception:
            return x

    suffix = f"_M_{M}_N_{N}_seed_{seed_count}_alpha_{fmt_num(alpha)}_beta_{fmt_num(beta_param)}"
    csv_file = os.path.join(out_dir, f"response_times{suffix}.csv")
    log_file = os.path.join(out_dir, f"load_generator{suffix}.log")

    # Setup logger (file only)
    logger = setup_logger(log_file)
    logger.info(f"Starting load generator. CSV -> {csv_file}  LOG -> {log_file}")

    # Capture program start timestamp
    start_ts = datetime.utcnow().isoformat() + "Z"

    # Prepare CSV and header
    try:
        with open(csv_file, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["Seed", "Timestamp", "DeviceID", "EntityID", "Status", "ResponseTime(ms)"])
            # prepend dummy row
            writer.writerow([0, start_ts, "000", "urn:ngsi-ld:OffStreetParking:000", 200, 0])
        logger.info(f"Response times will be written to: {csv_file}")
    except Exception:
        logger.exception("Failed to create CSV file")
        raise
    
    finished_successfully = False

    try:
        with open(csv_file, "a", newline="") as f:
            writer = csv.writer(f)

            for seed_val in range(1, seed_count + 1):
                logger.info(f"\n--- Seed {seed_val}/{seed_count} ---")
                allocs = allocate_points_beta(N, M, alpha, beta_param, seed=seed_val)
                dev_counter = 1

                for sec, count in enumerate(allocs, start=1):
                    logger.info(f"Second {sec:02}: sending {count} requests")
                    batch = []

                    with ThreadPoolExecutor(max_workers=max_workers) as ex:
                        futures = []
                        for _ in range(int(count)):
                            did = f"{dev_counter:03}"
                            full_url = base_url
                            # pass the logger to send_request to record details in the log file
                            futures.append(ex.submit(send_request, did, seed_val, batch, full_url, timeout, image_path, logger))
                            dev_counter = dev_counter + 1 if dev_counter < M else 1
                        # wait for all
                        for fut in futures:
                            try:
                                fut.result()
                            except Exception:
                                logger.exception("Unexpected error in request future")

                    if batch:
                        writer.writerows(batch)
                        f.flush()
                        logger.debug(f"Wrote {len(batch)} rows to CSV for seed={seed_val} second={sec}")
                    time.sleep(1)

        finished_successfully = True
    except KeyboardInterrupt:
        logger.warning("\n⚠ Interrupted by user.")
    except Exception:
        logger.exception("Unhandled exception during run.")
        raise
    finally:
        # Capture end timestamp
        end_ts = datetime.utcnow().isoformat() + "Z"

        try:
            with open(csv_file, "a", newline="") as f:
                writer = csv.writer(f)
                writer.writerow([0, end_ts, "000", "urn:ngsi-ld:OffStreetParking:000", 200, 0])
            logger.info(f"Done! Response times -> {csv_file}")
            logger.info(f"Log file -> {log_file}")
        except Exception:
            logger.exception("Failed writing final row to CSV")

        # Send desktop notification (exact text you requested). Ignore any errors.
        try:
            subprocess.run(["notify-send", "-u", "critical", "The program  ended."], check=False)
        except Exception:
            # swallow: we don't want notify failures to affect the program exit
            logger.debug("notify-send failed or not available.")


if __name__ == "__main__":
    main()

