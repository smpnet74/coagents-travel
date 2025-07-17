#!/bin/bash

# CoAgents Travel Kubernetes Deployment Script
# Safely deploys application to Kubernetes with secrets from .env file
# 
# This script:
# 1. Reads API keys from .env file
# 2. Creates Kubernetes secrets directly (no files written to disk)
# 3. Deploys application manifests
# 4. Validates deployment status

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_ROOT/k8s"
ENV_FILE="$PROJECT_ROOT/.env"

echo -e "${BLUE}🚀 CoAgents Travel Kubernetes Deployment${NC}"
echo "=================================================="

# Verify prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    echo "Please ensure your kubeconfig is set up correctly"
    exit 1
fi

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}❌ .env file not found at $ENV_FILE${NC}"
    echo "Please create a .env file with your API keys"
    exit 1
fi

# Check if k8s directory exists
if [[ ! -d "$K8S_DIR" ]]; then
    echo -e "${RED}❌ Kubernetes manifests directory not found at $K8S_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Source environment variables
echo -e "${YELLOW}🔐 Loading environment variables...${NC}"
set -a  # Automatically export all variables
source "$ENV_FILE"
set +a  # Stop auto-export

# Validate required environment variables
if [[ -z "$OPENAI_API_KEY" ]]; then
    echo -e "${RED}❌ OPENAI_API_KEY not found in .env file${NC}"
    exit 1
fi

if [[ -z "$GOOGLE_MAPS_API_KEY" ]]; then
    echo -e "${RED}❌ GOOGLE_MAPS_API_KEY not found in .env file${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment variables loaded${NC}"

# Get current cluster context
CURRENT_CONTEXT=$(kubectl config current-context)
echo -e "${BLUE}📍 Deploying to cluster: ${CURRENT_CONTEXT}${NC}"

# Confirm deployment
read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⏹️  Deployment cancelled${NC}"
    exit 0
fi

# Apply namespace first
echo -e "${YELLOW}🏗️  Creating namespace...${NC}"
kubectl apply -f "$K8S_DIR/namespace.yaml"

# Create secrets directly via kubectl (no temporary files)
echo -e "${YELLOW}🔐 Creating secrets...${NC}"
kubectl create secret generic travel-secrets \
    --namespace=app-travelexample \
    --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY" \
    --from-literal=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -

# Apply other manifests (excluding secrets.yaml since we created secrets directly)
echo -e "${YELLOW}🚀 Deploying application...${NC}"

# Apply reference grant for cross-namespace access
kubectl apply -f "$K8S_DIR/referencegrant.yaml"

# Deploy backend
kubectl apply -f "$K8S_DIR/backend/"

# Deploy frontend
kubectl apply -f "$K8S_DIR/frontend/"

# Wait for deployments to be ready
echo -e "${YELLOW}⏳ Waiting for deployments to be ready...${NC}"

echo -n "  Backend: "
kubectl wait --for=condition=available --timeout=300s deployment/travel-backend -n app-travelexample
echo -e "${GREEN}✅ Ready${NC}"

echo -n "  Frontend: "
kubectl wait --for=condition=available --timeout=300s deployment/travel-frontend -n app-travelexample
echo -e "${GREEN}✅ Ready${NC}"

# Show deployment status
echo -e "${BLUE}📊 Deployment Status${NC}"
echo "===================="

echo "Pods:"
kubectl get pods -n app-travelexample

echo -e "\nServices:"
kubectl get services -n app-travelexample

echo -e "\nHTTPRoute:"
kubectl get httproute -n app-travelexample

# Check if HTTPRoute has an assigned address
echo -e "\n${YELLOW}🌐 Checking external access...${NC}"
GATEWAY_ADDRESS=$(kubectl get gateway default-gateway -n default -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")

if [[ -n "$GATEWAY_ADDRESS" ]]; then
    echo -e "${GREEN}✅ Gateway Address: $GATEWAY_ADDRESS${NC}"
    echo -e "${BLUE}🔗 Application should be accessible at: https://travelexample.timbersedgearb.com${NC}"
else
    echo -e "${YELLOW}⚠️  Gateway address not yet assigned. Check gateway status.${NC}"
fi

# Show logs for any failed pods
FAILED_PODS=$(kubectl get pods -n app-travelexample --field-selector=status.phase!=Running --no-headers 2>/dev/null | awk '{print $1}' || true)
if [[ -n "$FAILED_PODS" ]]; then
    echo -e "\n${RED}⚠️  Some pods are not running:${NC}"
    echo "$FAILED_PODS"
    echo -e "\n${YELLOW}Recent logs for failed pods:${NC}"
    for pod in $FAILED_PODS; do
        echo -e "\n--- Logs for $pod ---"
        kubectl logs "$pod" -n app-travelexample --tail=10 || true
    done
fi

echo -e "\n${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${BLUE}📝 Next steps:${NC}"
echo "  1. Test the application at: https://travelexample.timbersedgearb.com"
echo "  2. Monitor pods: kubectl get pods -n app-travelexample -w"
echo "  3. View logs: kubectl logs -f deployment/travel-frontend -n app-travelexample"
echo "  4. View logs: kubectl logs -f deployment/travel-backend -n app-travelexample"