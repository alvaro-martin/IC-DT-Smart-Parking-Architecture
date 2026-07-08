from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse
from PIL import Image
from io import BytesIO
import time
import psutil
from ultralytics import YOLO
import os
import logging
import requests # added requess for forwarding to IoT Agent.

# Create logger once at top
logger = logging.getLogger("inference")
logging.basicConfig(level=logging.INFO)

# Silence python-multipart DEBUG logs
logging.getLogger("multipart").setLevel(logging.WARNING)

# Load environment variables from env
IOT_URL = os.getenv("IOT_URL", "http://fiware-iot-agent:7896/iot/json")  # IoT Agent base URL
IOT_KEY = os.getenv("IOT_KEY", "12345")  # API key for IoT Agent

# Load the YOLO model once at startup
model = YOLO("yolo11n.engine", task="detect")

# initial prediction to load the model.
results = model("test.jpg", stream=False)

# Initialize FastAPI app
app = FastAPI()

# Define prediction endpoint
@app.post("/predict")
async def predict(file: UploadFile = File(...), entity_id: str = Form(None)):
    try:
        # Read the image into memory
        contents = await file.read()
        img_object = Image.open(BytesIO(contents)).convert("RGB")

        # Start timing
        start_time = time.time()
        # Perform the inference
        results = model.predict(img_object, verbose=False, show=False)
        # Process results
        detections = []
        for result in results:
            boxes = result.boxes
            classes = boxes.cls.tolist()
            confidences = boxes.conf.tolist()
            xyxy = boxes.xyxy.tolist()

            for cls, conf, bbox in zip(classes, confidences, xyxy):
                detections.append({
                    "class": int(cls),
                    "confidence": float(conf),
                    "bbox": [float(x) for x in bbox]
                })

        # Calculate the inference time
        end_time = time.time()
        inference_time = end_time - start_time
        # Calculate cpu and memory metrics
        cpu_usage = psutil.cpu_percent()
        memory = psutil.virtual_memory().used / (1024 ** 2) # In MB
        # Count the number of cars detected
        car_objects = len(detections)
        # Log the response
        logger.info(f"Inference finished: {inference_time: .6f} sec, cars={car_objects}, CPU={cpu_usage}%, MEM={memory:.1f}MB")

        # Build device id and POST to IoT Agent JSON
        # If entity_id provided as URN (e.g. urn:ngsi-ld:OffStreetParking:001) extract last segment;
        # if user sent a plain numeric id, use it directly.
        device_id = None
        if entity_id:
            # Take last colon-separated part and stripe whitespace
            device_id = entity_id.split(":")[-1].strip()
        else:
            # Not provided: log and skip forwarding
            logger.warning("No entity_id form field provided, skiping IoT Agent update.")
            device_id = None

        if device_id:
            try:
                payload = {"occupied_spots": car_objects}
                # Build URL, add ?k=API_KEY&i=device_id
                forward_url = f"{IOT_URL}?k={IOT_KEY}&i={device_id}"
                resp = requests.post(forward_url, json=payload, timeout=60)
                logger.info(f"Forwarded to IoT Agent: url={forward_url} status={resp.status_code} payload={payload}")
            except requests.RequestException as e:
                logger.exception(f"Failed forwarding to IoT Agent for device {device_id} and url {forward_url}: {e}")

        return JSONResponse(content={
            "car_objects": car_objects,
            "inference_time_seconds": round(inference_time,6),
            "cpu_usage": cpu_usage,
            "memory": memory
        })
    except Exception as e:
        logger.exception("Error during /predict")
        return JSONResponse(content={"error": str(e)}, status_code=500)
