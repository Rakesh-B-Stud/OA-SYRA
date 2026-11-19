FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for OpenCV/PIL image processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy python dependencies file
COPY requirements.txt .

# Install CPU-optimized PyTorch and requirements
RUN pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cpu \
    torch==2.6.0+cpu \
    torchvision==0.21.0+cpu && \
    pip install --no-cache-dir -r requirements.txt

# Copy application source code & model weights
COPY . .

# Expose port (default 8000)
EXPOSE 8000

# Bind to 0.0.0.0 and dynamic cloud assigned PORT environment variable
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]
