FROM ultralytics/ultralytics:latest-jetson-jetpack4

WORKDIR /ultralytics

# Install dependencies
RUN pip3 uninstall numpy -y && pip3 install numpy==1.23.5
RUN pip3 install fastapi uvicorn gunicorn python-multipart pillow

# Copy files
COPY yolo11n.engine test.jpg start.sh /ultralytics/
COPY app.py /ultralytics/

RUN chmod +x /ultralytics/start.sh

EXPOSE 8000

# Set the command to  run the script
CMD ["./start.sh"]

