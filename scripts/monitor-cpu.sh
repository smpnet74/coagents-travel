#!/bin/bash

# Real-time CPU monitoring script for CoAgents Travel backend
# Monitors CPU usage during user interactions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 CoAgents Travel Backend CPU Monitor${NC}"
echo "========================================"
echo -e "${YELLOW}Monitoring backend CPU usage in real-time...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Get pod name
POD_NAME=$(kubectl get pod -n app-travelexample -l app=travel-backend -o jsonpath='{.items[0].metadata.name}')
echo -e "${BLUE}Monitoring pod: ${POD_NAME}${NC}"

# Show resource limits for context
echo -e "\n${BLUE}Resource Configuration:${NC}"
kubectl get pod -n app-travelexample -l app=travel-backend -o jsonpath='{.items[0].spec.containers[0].resources}' | jq '.'

echo -e "\n${BLUE}CPU Usage (millicores) | Memory Usage | Timestamp${NC}"
echo "================================================="

# Monitor in loop
while true; do
    # Get current timestamp
    TIMESTAMP=$(date '+%H:%M:%S')
    
    # Get CPU and memory usage
    METRICS=$(kubectl top pod -n app-travelexample -l app=travel-backend --no-headers 2>/dev/null || echo "N/A N/A N/A")
    
    if [ "$METRICS" != "N/A N/A N/A" ]; then
        POD_NAME_SHORT=$(echo $METRICS | awk '{print $1}' | cut -c1-20)
        CPU_USAGE=$(echo $METRICS | awk '{print $2}')
        MEMORY_USAGE=$(echo $METRICS | awk '{print $3}')
        
        # Extract numeric value for CPU to determine color
        CPU_NUM=$(echo $CPU_USAGE | sed 's/m//')
        
        # Color coding based on CPU usage
        if [ "$CPU_NUM" -gt 500 ]; then
            COLOR=$RED    # Over CPU request
        elif [ "$CPU_NUM" -gt 100 ]; then
            COLOR=$YELLOW # Moderate usage
        else
            COLOR=$GREEN  # Low usage
        fi
        
        echo -e "${COLOR}${CPU_USAGE}${NC} | ${MEMORY_USAGE} | ${TIMESTAMP}"
    else
        echo -e "${RED}Metrics unavailable${NC} | ${TIMESTAMP}"
    fi
    
    sleep 2
done