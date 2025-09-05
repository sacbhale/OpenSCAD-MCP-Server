# OpenSCAD MCP Server - Docker Setup Guide

This guide explains how to run the OpenSCAD MCP Server using Docker and Docker Compose.

## Prerequisites

- Docker (version 20.10 or higher)
- Docker Compose (version 2.0 or higher)

## Quick Start

1. **Clone the repository** (if not already done):
   ```bash
   git clone <repository-url>
   cd OpenSCAD-MCP-Server
   ```

2. **Set up environment variables**:
   ```bash
   cp env.example .env
   ```
   Edit `.env` file and add your API keys:
   ```bash
   # Required for image generation
   GEMINI_API_KEY=your_gemini_api_key_here
   
   # Optional for alternative image generation
   VENICE_API_KEY=your_venice_api_key_here
   ```

3. **Build and run with Docker Compose**:
   ```bash
   docker-compose up --build
   ```

4. **Access the server**:
   - API: http://localhost:8080
   - Health check: http://localhost:8080/
   - API documentation: http://localhost:8080/docs (if available)

## Configuration

### Environment Variables

The server supports numerous configuration options via environment variables. See `env.example` for a complete list.

#### Essential Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `GEMINI_API_KEY` | Google Gemini API key for image generation | Required |
| `VENICE_API_KEY` | Venice.ai API key (optional) | Optional |
| `CUDA_MVS_USE_GPU` | Enable GPU processing for CUDA MVS | `false` |
| `IMAGE_APPROVAL_AUTO_APPROVE` | Auto-approve generated images | `false` |

#### Remote Processing

The server supports remote CUDA MVS processing:

| Variable | Description | Default |
|----------|-------------|---------|
| `REMOTE_CUDA_MVS_ENABLED` | Enable remote processing | `true` |
| `REMOTE_CUDA_MVS_USE_LAN_DISCOVERY` | Use LAN discovery | `true` |
| `REMOTE_CUDA_MVS_SERVER_URL` | Direct server URL | Empty (use discovery) |
| `REMOTE_CUDA_MVS_API_KEY` | API key for remote server | Required if using remote |

### Volume Mounts

The Docker setup includes persistent storage for:

- `./output` → `/app/output` - Generated models and images
- `./scad` → `/app/scad` - OpenSCAD files
- `./templates` → `/app/templates` - HTML templates
- `./static` → `/app/static` - Static files

## Usage Examples

### Basic Model Generation

```bash
# Create a simple cube
curl -X POST http://localhost:8080/tool_call \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "create_3d_model",
    "tool_params": {
      "description": "Create a cube with dimensions 10x10x10"
    }
  }'
```

### Image Generation and Processing

```bash
# Generate an image from text
curl -X POST http://localhost:8080/tool_call \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "generate_image_gemini",
    "tool_params": {
      "prompt": "A red sports car from the side view"
    }
  }'
```

### Multi-view Processing

```bash
# Generate multiple views and create 3D model
curl -X POST http://localhost:8080/tool_call \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "create_3d_model_from_text",
    "tool_params": {
      "prompt": "A modern chair",
      "num_views": 4
    }
  }'
```

## Docker Commands

### Build and Run

```bash
# Build and run in foreground
docker-compose up --build

# Build and run in background
docker-compose up -d --build

# Rebuild after code changes
docker-compose down
docker-compose up --build
```

### Publishing to Docker Hub

Use the included `publish-docker.sh` script to build and publish the image to Docker Hub:

```bash
# Set your Docker Hub username (or use -u flag)
export DOCKERHUB_USERNAME=yourusername

# Basic publish (builds and pushes latest tag)
./publish-docker.sh -u yourusername

# Publish with specific version tag
./publish-docker.sh -u yourusername -t v1.0.0

# Publish version and also tag as latest
./publish-docker.sh -u yourusername -t v1.0.0 -a

# Build only (don't push to Docker Hub)
./publish-docker.sh -u yourusername --build-only

# Push existing image without rebuilding
./publish-docker.sh -u yourusername -t v1.0.0 --push-only
```

#### Publishing Script Options

| Option | Description |
|--------|-------------|
| `-u, --username` | Docker Hub username (required) |
| `-i, --image` | Custom image name (default: openscad-mcp-server) |
| `-t, --tag` | Image tag (default: latest) |
| `-a, --also-latest` | Also push with latest tag |
| `--build-only` | Only build, don't push |
| `--push-only` | Only push existing image |
| `--no-cache` | Build without cache |
| `-h, --help` | Show help |

#### Using Published Images

Once published, you can use the image directly in docker-compose.yml:

```yaml
services:
  openscad-mcp-server:
    image: yourusername/openscad-mcp-server:latest  # Use published image
    # Remove the 'build:' section when using published image
    container_name: openscad-mcp-server
    ports:
      - "8080:8000"
    # ... rest of configuration
```

Or run directly with Docker:

```bash
docker run -p 8080:8000 yourusername/openscad-mcp-server:latest
```

### Management

```bash
# View logs
docker-compose logs -f

# Stop the service
docker-compose down

# Remove all containers and volumes
docker-compose down -v

# Access the container shell
docker-compose exec openscad-mcp-server bash
```

### Development

```bash
# Run with live reload (mount source code)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

## Troubleshooting

### Common Issues

1. **Port already in use**:
   ```bash
   # Change port in docker-compose.yml
   ports:
     - "8001:8000"  # Use port 8001 instead
   ```

2. **Permission issues with volumes**:
   ```bash
   # Fix ownership
   sudo chown -R $USER:$USER ./output ./scad
   ```

3. **Missing API keys**:
   ```bash
   # Check environment variables
   docker-compose exec openscad-mcp-server env | grep API_KEY
   ```

4. **OpenSCAD not found**:
   ```bash
   # Verify OpenSCAD installation in container
   docker-compose exec openscad-mcp-server which openscad
   ```

### Performance Optimization

1. **Enable GPU support** (if available):
   ```bash
   # In .env file
   CUDA_MVS_USE_GPU=true
   ```

2. **Increase memory limits**:
   ```yaml
   # In docker-compose.yml
   services:
     openscad-mcp-server:
       mem_limit: 4g
       mem_reservation: 2g
   ```

3. **Use SSD storage** for volumes:
   ```yaml
   # Mount to SSD path
   volumes:
     - /path/to/ssd/output:/app/output
   ```

### Debugging

1. **Enable debug logging**:
   ```bash
   # Add to docker-compose.yml environment
   - PYTHONPATH=/app
   - LOG_LEVEL=DEBUG
   ```

2. **Check container health**:
   ```bash
   docker-compose ps
   docker-compose exec openscad-mcp-server curl -f http://localhost:8000/
   ```

3. **Monitor resource usage**:
   ```bash
   docker stats
   ```

## Production Deployment

### Security Considerations

1. **Use secrets for API keys**:
   ```yaml
   # docker-compose.prod.yml
   services:
     openscad-mcp-server:
       secrets:
         - gemini_api_key
         - venice_api_key
   
   secrets:
     gemini_api_key:
       file: ./secrets/gemini_api_key.txt
     venice_api_key:
       file: ./secrets/venice_api_key.txt
   ```

2. **Enable reverse proxy** (uncomment nginx section in docker-compose.yml):
   ```yaml
   nginx:
     image: nginx:alpine
     ports:
       - "80:80"
       - "443:443"
   ```

3. **Limit resource usage**:
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '2.0'
         memory: 4G
       reservations:
         memory: 2G
   ```

### Monitoring

1. **Health checks**:
   ```bash
       # Custom health check endpoint
    curl http://localhost:8080/health
   ```

2. **Log aggregation**:
   ```yaml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```

## API Documentation

Once the server is running, you can access the API documentation at:
- http://localhost:8080/docs (Swagger UI)
- http://localhost:8080/redoc (ReDoc)

## Support

For issues and questions:
1. Check the logs: `docker-compose logs -f`
2. Verify configuration: `docker-compose config`
3. Test connectivity: `curl http://localhost:8080/`
4. Check the main README.md for additional information

## File Structure

```
OpenSCAD-MCP-Server/
├── Dockerfile              # Docker image definition
├── docker-compose.yml      # Docker Compose configuration
├── .dockerignore           # Files to exclude from Docker build
├── env.example            # Environment variables template
├── DOCKER_README.md       # This file
├── src/                   # Application source code
├── output/               # Generated files (mounted as volume)
├── scad/                 # OpenSCAD files (mounted as volume)
├── templates/            # HTML templates (mounted as volume)
└── static/               # Static files (mounted as volume)
``` 