# Use TensorRT 8.6 with CUDA 11.8
FROM nvcr.io/nvidia/tensorrt:23.09-py3

WORKDIR /app

# System packages
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    wget \
    unzip \
    python3-pip \
 && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Python packages
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy source files
COPY yolo11m.engine app.py start.sh /app/
RUN chmod +x start.sh

EXPOSE 8000

# Run FastAPI with Gunicorn on startup
CMD ["./start.sh"]