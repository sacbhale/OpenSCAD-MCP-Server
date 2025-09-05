#!/bin/bash

# OpenSCAD MCP Server - Docker Hub Publishing Script
# This script builds and publishes the Docker image to Docker Hub

set -e  # Exit on any error

# Configuration
DEFAULT_DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"
DEFAULT_IMAGE_NAME="openscad-mcp-server"
DEFAULT_TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --username USERNAME    Docker Hub username (required if not set via DOCKERHUB_USERNAME env var)"
    echo "  -i, --image IMAGE_NAME     Image name (default: $DEFAULT_IMAGE_NAME)"
    echo "  -t, --tag TAG             Image tag (default: $DEFAULT_TAG)"
    echo "  -a, --also-latest         Also tag and push as 'latest' (when using custom tag)"
    echo "  --build-only              Only build the image, don't push to Docker Hub"
    echo "  --push-only               Only push existing image, don't build"
    echo "  --no-cache                Build without using cache"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DOCKERHUB_USERNAME        Default Docker Hub username"
    echo ""
    echo "Examples:"
    echo "  $0 -u myuser                                    # Build and push myuser/openscad-mcp-server:latest"
    echo "  $0 -u myuser -t v1.0.0                        # Build and push myuser/openscad-mcp-server:v1.0.0"
    echo "  $0 -u myuser -t v1.0.0 -a                     # Build and push both v1.0.0 and latest tags"
    echo "  $0 -u myuser --build-only                      # Only build, don't push"
    echo "  $0 -u myuser -t v1.0.0 --push-only           # Only push existing v1.0.0 image"
}

# Parse command line arguments
DOCKERHUB_USERNAME="$DEFAULT_DOCKERHUB_USERNAME"
IMAGE_NAME="$DEFAULT_IMAGE_NAME"
TAG="$DEFAULT_TAG"
ALSO_LATEST=false
BUILD_ONLY=false
PUSH_ONLY=false
NO_CACHE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            DOCKERHUB_USERNAME="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -a|--also-latest)
            ALSO_LATEST=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --push-only)
            PUSH_ONLY=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$DOCKERHUB_USERNAME" ]]; then
    log_error "Docker Hub username is required. Use -u flag or set DOCKERHUB_USERNAME environment variable."
    show_usage
    exit 1
fi

# Construct full image names
FULL_IMAGE_NAME="${DOCKERHUB_USERNAME}/${IMAGE_NAME}"
FULL_IMAGE_TAG="${FULL_IMAGE_NAME}:${TAG}"
LATEST_IMAGE_TAG="${FULL_IMAGE_NAME}:latest"

# Validate conflicting options
if [[ "$BUILD_ONLY" == true && "$PUSH_ONLY" == true ]]; then
    log_error "Cannot use --build-only and --push-only together"
    exit 1
fi

log_info "Starting Docker Hub publishing process..."
log_info "Image: $FULL_IMAGE_TAG"
if [[ "$ALSO_LATEST" == true && "$TAG" != "latest" ]]; then
    log_info "Also tagging as: $LATEST_IMAGE_TAG"
fi

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running"
    exit 1
fi

# Build the image (unless --push-only is specified)
if [[ "$PUSH_ONLY" != true ]]; then
    log_info "Building Docker image..."
    
    BUILD_ARGS=""
    if [[ "$NO_CACHE" == true ]]; then
        BUILD_ARGS="--no-cache"
        log_info "Building without cache"
    fi
    
    # Build with the specified tag
    if ! docker build $BUILD_ARGS -t "$FULL_IMAGE_TAG" .; then
        log_error "Failed to build Docker image"
        exit 1
    fi
    
    log_success "Successfully built image: $FULL_IMAGE_TAG"
    
    # Also tag as latest if requested
    if [[ "$ALSO_LATEST" == true && "$TAG" != "latest" ]]; then
        if ! docker tag "$FULL_IMAGE_TAG" "$LATEST_IMAGE_TAG"; then
            log_error "Failed to tag image as latest"
            exit 1
        fi
        log_success "Successfully tagged as: $LATEST_IMAGE_TAG"
    fi
fi

# Exit if build-only mode
if [[ "$BUILD_ONLY" == true ]]; then
    log_success "Build completed successfully (build-only mode)"
    exit 0
fi

# Check if user is logged into Docker Hub
log_info "Checking Docker Hub authentication..."
if ! docker info | grep -q "Username"; then
    log_warning "Not logged into Docker Hub. Attempting to log in..."
    if ! docker login; then
        log_error "Failed to log into Docker Hub"
        exit 1
    fi
fi

# Push the image to Docker Hub
log_info "Pushing image to Docker Hub..."

if ! docker push "$FULL_IMAGE_TAG"; then
    log_error "Failed to push image: $FULL_IMAGE_TAG"
    exit 1
fi

log_success "Successfully pushed: $FULL_IMAGE_TAG"

# Push latest tag if requested
if [[ "$ALSO_LATEST" == true && "$TAG" != "latest" ]]; then
    log_info "Pushing latest tag..."
    if ! docker push "$LATEST_IMAGE_TAG"; then
        log_error "Failed to push latest tag: $LATEST_IMAGE_TAG"
        exit 1
    fi
    log_success "Successfully pushed: $LATEST_IMAGE_TAG"
fi

# Show final summary
echo ""
log_success "Docker Hub publishing completed successfully!"
echo ""
echo "Published images:"
echo "  - $FULL_IMAGE_TAG"
if [[ "$ALSO_LATEST" == true && "$TAG" != "latest" ]]; then
    echo "  - $LATEST_IMAGE_TAG"
fi
echo ""
echo "To use the published image:"
echo "  docker pull $FULL_IMAGE_TAG"
echo "  docker run -p 8080:8000 $FULL_IMAGE_TAG"
echo ""
echo "Or update your docker-compose.yml to use the published image:"
echo "  image: $FULL_IMAGE_TAG" 