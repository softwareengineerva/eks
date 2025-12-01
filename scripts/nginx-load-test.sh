#!/bin/bash

# NGINX Load Test Script
# Generates HTTP traffic for Grafana metrics collection
# Author: Jian Ouyang (jian.ouyang@sapns2.com)

set -e

# Configuration
NAMESPACE="nginx-alb"
SERVICE_NAME="nginx"
SERVICE_PORT="80"
INTERVAL=0.5  # Seconds between requests
DURATION=60   # Total duration in seconds (0 for infinite)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Statistics
SUCCESS_COUNT=0
FAILURE_COUNT=0
TOTAL_COUNT=0

echo -e "${GREEN}=== NGINX Load Test Script ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Service: $SERVICE_NAME:$SERVICE_PORT"
echo "Interval: ${INTERVAL}s between requests"
if [ "$DURATION" -gt 0 ]; then
    echo "Duration: ${DURATION}s"
else
    echo "Duration: Infinite (press Ctrl+C to stop)"
fi
echo ""

# Check if service exists
echo -e "${YELLOW}Checking if NGINX service exists...${NC}"
if ! kubectl get svc -n "$NAMESPACE" "$SERVICE_NAME" &>/dev/null; then
    echo -e "${RED}Error: Service $SERVICE_NAME not found in namespace $NAMESPACE${NC}"
    exit 1
fi

SERVICE_IP=$(kubectl get svc -n "$NAMESPACE" "$SERVICE_NAME" -o jsonpath='{.spec.clusterIP}')
echo -e "${GREEN}✓ Service found at $SERVICE_IP:$SERVICE_PORT${NC}"

# Function to make HTTP request
make_request() {
    local path="$1"
    local expected_status="$2"
    local description="$3"

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    # Make request and capture response
    RESPONSE=$(kubectl run curl-test-$RANDOM --image=curlimages/curl:latest --rm -i --restart=Never -q -- \
        -s -o /dev/null -w "%{http_code}" \
        "http://${SERVICE_IP}:${SERVICE_PORT}${path}" 2>/dev/null || echo "000")

    if [ "$RESPONSE" = "$expected_status" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo -e "${GREEN}✓${NC} [$TOTAL_COUNT] $description - HTTP $RESPONSE (Success)"
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        echo -e "${RED}✗${NC} [$TOTAL_COUNT] $description - HTTP $RESPONSE (Expected: $expected_status)"
    fi
}

# Function to display statistics
display_stats() {
    echo ""
    echo -e "${BLUE}=== Statistics ===${NC}"
    echo "Total Requests:   $TOTAL_COUNT"
    echo -e "Successful:       ${GREEN}$SUCCESS_COUNT${NC}"
    echo -e "Failed:           ${RED}$FAILURE_COUNT${NC}"
    if [ "$TOTAL_COUNT" -gt 0 ]; then
        SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", ($SUCCESS_COUNT/$TOTAL_COUNT)*100}")
        FAILURE_RATE=$(awk "BEGIN {printf \"%.2f\", ($FAILURE_COUNT/$TOTAL_COUNT)*100}")
        echo "Success Rate:     ${SUCCESS_RATE}%"
        echo "Failure Rate:     ${FAILURE_RATE}%"
    fi
}

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping load test...${NC}"
    display_stats
    echo ""
    echo -e "${GREEN}Load test completed${NC}"
    echo "View metrics in Grafana for:"
    echo "  - nginx_http_requests_total (total HTTP requests)"
    echo "  - nginx_connections_active (active connections)"
    echo "  - nginx_connections_accepted (accepted connections)"
    echo "  - HTTP status code distribution (2xx, 4xx, 5xx)"
    exit 0
}

# Set trap to handle Ctrl+C
trap cleanup SIGINT SIGTERM

# Start time
START_TIME=$(date +%s)

echo -e "${YELLOW}Starting load test...${NC}"
echo ""

# Main loop
REQUEST_NUM=0
while true; do
    REQUEST_NUM=$((REQUEST_NUM + 1))

    # Mix of successful and failed requests
    # 70% success (index.html), 30% failures (various 404s)
    RANDOM_NUM=$((RANDOM % 10))

    if [ $RANDOM_NUM -lt 7 ]; then
        # Successful request to index.html
        make_request "/" "200" "GET / (index.html)"
    else
        # Failed requests to non-existing resources
        case $((RANDOM % 5)) in
            0)
                make_request "/notfound.html" "404" "GET /notfound.html"
                ;;
            1)
                make_request "/missing/page.html" "404" "GET /missing/page.html"
                ;;
            2)
                make_request "/api/v1/data" "404" "GET /api/v1/data"
                ;;
            3)
                make_request "/images/logo.png" "404" "GET /images/logo.png"
                ;;
            4)
                make_request "/robots.txt" "404" "GET /robots.txt"
                ;;
        esac
    fi

    # Check if duration limit reached
    if [ "$DURATION" -gt 0 ]; then
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - START_TIME))
        if [ $ELAPSED -ge $DURATION ]; then
            cleanup
        fi
    fi

    # Display interim stats every 10 requests
    if [ $((REQUEST_NUM % 10)) -eq 0 ]; then
        display_stats
        echo ""
    fi

    # Wait before next request
    sleep "$INTERVAL"
done
