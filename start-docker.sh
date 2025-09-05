#!/bin/bash

# OpenSCAD MCP Server - Docker Startup Script
# This script helps you get started with the OpenSCAD MCP Server using Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        print_info "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        print_info "Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    print_status "Docker and Docker Compose are installed"
}

# Check if Docker daemon is running
check_docker_daemon() {
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    print_status "Docker daemon is running"
}

# Setup environment file
setup_environment() {
    if [ ! -f .env ]; then
        print_info "Creating .env file from template..."
        cp env.example .env
        print_warning "Please edit .env file and add your API keys before running the server"
        print_info "Required: GEMINI_API_KEY"
        print_info "Optional: VENICE_API_KEY"
        
        if command -v nano &> /dev/null; then
            read -p "Do you want to edit the .env file now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                nano .env
            fi
        fi
    else
        print_status "Environment file (.env) already exists"
    fi
}

# Create necessary directories
create_directories() {
    print_info "Creating necessary directories..."
    mkdir -p output output/models output/preview output/images output/multi_view output/approved_images
    mkdir -p scad templates static
    print_status "Directories created"
}

# Build and run the Docker containers
build_and_run() {
    print_info "Building and starting OpenSCAD MCP Server..."
    
    # Check if we should run in background
    if [[ "$1" == "-d" || "$1" == "--detach" ]]; then
        docker-compose up -d --build
        print_status "OpenSCAD MCP Server started in background"
        print_info "View logs with: docker-compose logs -f"
    else
        docker-compose up --build
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --detach     Run in detached mode (background)"
    echo "  -h, --help       Show this help message"
    echo "  --stop           Stop the running containers"
    echo "  --restart        Restart the containers"
    echo "  --logs           Show container logs"
    echo "  --shell          Open shell in the container"
    echo "  --clean          Stop and remove containers, networks, and volumes"
    echo ""
    echo "Examples:"
    echo "  $0               # Start in foreground"
    echo "  $0 -d            # Start in background"
    echo "  $0 --stop        # Stop containers"
    echo "  $0 --logs        # View logs"
}

# Stop containers
stop_containers() {
    print_info "Stopping OpenSCAD MCP Server..."
    docker-compose down
    print_status "Containers stopped"
}

# Restart containers
restart_containers() {
    print_info "Restarting OpenSCAD MCP Server..."
    docker-compose restart
    print_status "Containers restarted"
}

# Show logs
show_logs() {
    print_info "Showing container logs (press Ctrl+C to exit)..."
    docker-compose logs -f
}

# Open shell in container
open_shell() {
    print_info "Opening shell in OpenSCAD MCP Server container..."
    docker-compose exec openscad-mcp-server bash
}

# Clean up everything
clean_up() {
    print_warning "This will stop and remove all containers, networks, and volumes!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleaning up..."
        docker-compose down -v --remove-orphans
        docker system prune -f
        print_status "Cleanup completed"
    else
        print_info "Cleanup cancelled"
    fi
}

# Main script logic
main() {
    echo "OpenSCAD MCP Server - Docker Startup Script"
    echo "==========================================="
    echo ""
    
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        --stop)
            stop_containers
            exit 0
            ;;
        --restart)
            restart_containers
            exit 0
            ;;
        --logs)
            show_logs
            exit 0
            ;;
        --shell)
            open_shell
            exit 0
            ;;
        --clean)
            clean_up
            exit 0
            ;;
        -d|--detach)
            DETACH_MODE=true
            ;;
        "")
            DETACH_MODE=false
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
    
    # Run setup steps
    check_docker
    check_docker_daemon
    setup_environment
    create_directories
    
    # Build and run
    if [ "$DETACH_MODE" = true ]; then
        build_and_run -d
        echo ""
        print_status "OpenSCAD MCP Server is running!"
        print_info "Access the server at: http://localhost:8080"
        print_info "View logs with: docker-compose logs -f"
        print_info "Stop with: docker-compose down"
    else
        build_and_run
    fi
}

# Run the main function with all arguments
main "$@" 