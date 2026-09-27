FROM python:3.11-slim

# Install system dependencies, OpenCV runtime & Tesseract OCR engine
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-eng \
    libgl1 \
    libglib2.0-0 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Use tessdata_fast LSTM model for fastest OCR inference
ADD https://github.com/tesseract-ocr/tessdata_fast/raw/main/eng.traineddata /usr/share/tesseract-ocr/5/tessdata/eng.traineddata

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Run with single Uvicorn worker to strictly conserve 512MB RAM on Render, dynamic PORT
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000} --workers 1"]
