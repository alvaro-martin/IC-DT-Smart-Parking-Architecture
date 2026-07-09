# Use an official lightweight Python image
FROM python:3.11-slim

# Set the working directory inside the container
WORKDIR /app

# Install OpenCV dependencies (fix ImportError for libGL.so.1)
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file and install dependencies
COPY requirements.txt .
RUN pip install openvino-dev[onnx]==2023.3.0
RUN pip install --no-cache-dir -r requirements.txt

# Copy model folder
COPY yolo11m_int8_openvino_model /app/yolo11m_int8_openvino_model

COPY app.py start.sh /app/
RUN chmod +x /app/start.sh

EXPOSE 8000

# Set the command to run the script
CMD ["./start.sh"]
