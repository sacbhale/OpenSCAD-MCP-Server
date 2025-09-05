# Use Ubuntu 24.04 LTS as base image for latest packages and security updates
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Add deadsnakes PPA for Python 3.11
RUN apt-get update && apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update

# Install system dependencies including Python packages that are problematic to build
RUN apt-get install -y \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-opengl \
    python3-numpy \
    openscad \
    git \
    wget \
    curl \
    build-essential \
    cmake \
    pkg-config \
    libgl1-mesa-dri \
    libgl1-mesa-dev \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libglu1-mesa \
    libxi6 \
    libxrandr2 \
    libxss1 \
    libxcursor1 \
    libxcomposite1 \
    libasound2t64 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libgtk-3-0 \
    libnss3 \
    && rm -rf /var/lib/apt/lists/*

# Create symbolic links for python3 and pip3
RUN ln -sf /usr/bin/python3.11 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.11 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip

# Set working directory
WORKDIR /app

# Create necessary directories
RUN mkdir -p /app/scad /app/output /app/output/models /app/output/preview /app/output/images \
    /app/output/multi_view /app/output/approved_images /app/templates /app/static

# Copy requirements file
COPY requirements-minimal.txt .

# Install Python dependencies
# Using --break-system-packages is safe in Docker containers for Ubuntu 24.04
RUN pip install --break-system-packages --no-cache-dir -r requirements-minimal.txt

# Copy the application code
COPY src/ ./src/
COPY rtfmd/ ./rtfmd/
COPY scad/ ./scad/

# Copy test files if they exist
COPY test_*.py ./

# Set proper permissions
RUN chmod -R 755 /app

# Create a non-root user (use different UID to avoid conflicts)
RUN useradd -m -u 1001 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose the port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# Command to run the application
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"] 