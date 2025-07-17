#!/bin/bash

# CoAgents Travel - Container Build Script
# This script builds the Docker containers for local testing

set -e  # Exit on any error

echo "🚀 CoAgents Travel - Container Build Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found. Please run this script from the project root."
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_warning ".env file not found. Copying from .env.example"
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_warning "Please edit .env file with your API keys before running the containers"
    else
        print_error ".env.example not found. Cannot create .env file."
        exit 1
    fi
fi

print_status "Building Docker containers..."

# Get git commit hash for tagging
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
print_status "Using commit SHA: $COMMIT_SHA"

# Check if we should build for multiple platforms (for cluster deployment)
MULTI_PLATFORM=${1:-"false"}
if [ "$MULTI_PLATFORM" = "--multi-platform" ] || [ "$MULTI_PLATFORM" = "-m" ]; then
    print_status "🌍 Building for multiple platforms (AMD64 + ARM64)..."
    
    # Login to GHCR first (required for --push)
    print_status "Logging into GitHub Container Registry..."
    if [ -z "$GITHUB_TOKEN" ]; then
        print_warning "GITHUB_TOKEN environment variable not set. You'll need to enter your GitHub Personal Access Token."
        echo "Get your token from: https://github.com/settings/tokens"
        echo "Required scopes: write:packages, read:packages"
        docker login ghcr.io -u smpnet74
    else
        echo "$GITHUB_TOKEN" | docker login ghcr.io -u smpnet74 --password-stdin
    fi
    
    # Create buildx builder if it doesn't exist
    if ! docker buildx ls | grep -q coagents-builder; then
        print_status "🔧 Creating multi-platform builder..."
        docker buildx create --name coagents-builder --use --bootstrap
    else
        print_status "✅ Using existing multi-platform builder"
        docker buildx use coagents-builder
    fi
    
    # Build backend container for multiple platforms
    print_status "Building backend container (multi-platform)..."
    if docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -t ghcr.io/smpnet74/coagents-travel-backend:latest \
        -t ghcr.io/smpnet74/coagents-travel-backend:$COMMIT_SHA \
        --push \
        ./agent; then
        print_status "✅ Backend container built and pushed successfully (multi-platform)"
    else
        print_error "❌ Backend container build failed"
        exit 1
    fi
    
    # Build frontend container for multiple platforms
    print_status "Building frontend container (multi-platform)..."
    if docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -t ghcr.io/smpnet74/coagents-travel-frontend:latest \
        -t ghcr.io/smpnet74/coagents-travel-frontend:$COMMIT_SHA \
        --push \
        ./ui; then
        print_status "✅ Frontend container built and pushed successfully (multi-platform)"
    else
        print_error "❌ Frontend container build failed"
        exit 1
    fi
    
    # Also build local images for docker-compose (ARM64 only for local dev)
    print_status "Building local images for docker-compose..."
    docker build -t coagents-travel-backend:latest ./agent
    docker build -t coagents-travel-frontend:latest ./ui
else
    print_status "🖥️  Building for local platform only..."
    
    # Build backend container
    print_status "Building backend container..."
    if docker build -t coagents-travel-backend:latest -t coagents-travel-backend:$COMMIT_SHA ./agent; then
        print_status "✅ Backend container built successfully"
    else
        print_error "❌ Backend container build failed"
        exit 1
    fi

    # Build frontend container
    print_status "Building frontend container..."
    if docker build -t coagents-travel-frontend:latest -t coagents-travel-frontend:$COMMIT_SHA ./ui; then
        print_status "✅ Frontend container built successfully"
    else
        print_error "❌ Frontend container build failed"
        exit 1
    fi
fi

# Build with docker-compose (this will use the images we just built)
print_status "Building with docker-compose..."
if docker-compose build; then
    print_status "✅ Docker Compose build completed successfully"
else
    print_error "❌ Docker Compose build failed"
    exit 1
fi

print_status "🎉 All containers built successfully!"
print_status "Next steps:"
if [ "$MULTI_PLATFORM" = "--multi-platform" ] || [ "$MULTI_PLATFORM" = "-m" ]; then
    echo "  1. Images have been pushed to GHCR automatically"
    echo "  2. Run 'kubectl rollout restart deployment/travel-backend deployment/travel-frontend -n app-travelexample' to force pull new images"
    echo "  3. Check deployment status with 'kubectl get pods -n app-travelexample'"
else
    echo "  1. Ensure your .env file has valid API keys"
    echo "  2. Run './scripts/test-local.sh' to start and test the application"
    echo "  3. Or run 'docker-compose up' to start the services manually"
    echo "  4. For cluster deployment, run './scripts/build.sh --multi-platform'"
fi