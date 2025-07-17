#!/bin/bash

# CoAgents Travel - Container Push Script  
# This script pushes the Docker containers to GitHub Container Registry (GHCR)

set -e  # Exit on any error

echo "🚀 CoAgents Travel - Container Push Script"
echo "========================================"

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

# Get git commit hash for tagging
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
print_status "Using commit SHA: $COMMIT_SHA"

# Check if GHCR images exist locally
if ! docker images | grep -q "ghcr.io/smpnet74/coagents-travel-backend"; then
    print_error "GHCR-tagged backend image not found. Please run './scripts/build.sh --multi-platform' first."
    exit 1
fi

if ! docker images | grep -q "ghcr.io/smpnet74/coagents-travel-frontend"; then
    print_error "GHCR-tagged frontend image not found. Please run './scripts/build.sh --multi-platform' first."
    exit 1
fi

# Login to GHCR
print_status "Logging into GitHub Container Registry..."
if [ -z "$GITHUB_TOKEN" ]; then
    print_warning "GITHUB_TOKEN environment variable not set. You'll need to enter your GitHub Personal Access Token."
    echo "Get your token from: https://github.com/settings/tokens"
    echo "Required scopes: write:packages, read:packages"
    docker login ghcr.io -u smpnet74
else
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u smpnet74 --password-stdin
fi

print_status "Pushing containers to GHCR..."

# Push backend container
print_status "Pushing backend container..."
if docker push ghcr.io/smpnet74/coagents-travel-backend:latest && \
   docker push ghcr.io/smpnet74/coagents-travel-backend:$COMMIT_SHA; then
    print_status "✅ Backend container pushed successfully"
else
    print_error "❌ Backend container push failed"
    exit 1
fi

# Push frontend container
print_status "Pushing frontend container..."
if docker push ghcr.io/smpnet74/coagents-travel-frontend:latest && \
   docker push ghcr.io/smpnet74/coagents-travel-frontend:$COMMIT_SHA; then
    print_status "✅ Frontend container pushed successfully"
else
    print_error "❌ Frontend container push failed"
    exit 1
fi

print_status "🎉 All containers pushed successfully to GHCR!"
print_status "Images available at:"
echo "  - ghcr.io/smpnet74/coagents-travel-backend:latest"
echo "  - ghcr.io/smpnet74/coagents-travel-backend:$COMMIT_SHA"
echo "  - ghcr.io/smpnet74/coagents-travel-frontend:latest"
echo "  - ghcr.io/smpnet74/coagents-travel-frontend:$COMMIT_SHA"
echo ""
print_status "Next steps:"
echo "  1. Update Kubernetes deployments if using specific commit SHA"
echo "  2. Run 'kubectl rollout restart deployment/travel-backend deployment/travel-frontend -n app-travelexample' to force pull new images"
echo "  3. Check deployment status with 'kubectl get pods -n app-travelexample'"