#!/bin/bash

#==============================================================================
# P0 Bridge Health Verification Script
#
# This script tests:
# 1. Bridge health endpoint availability on ports 5000 and 4001
# 2. Bridge status endpoint
# 3. POST to /webhook/2fa endpoint
#
# Usage:
#   ./test_bridge_health.sh [container_name]
#
# Default container name: ibkr-gateway
#==============================================================================

CONTAINER_NAME="${1:-ibkr-gateway}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="bridge_health_test_${TIMESTAMP}.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log_msg() {
    echo -e "${2}${1}${NC}" | tee -a "$LOG_FILE"
}

# Function to test endpoint
test_endpoint() {
    local port=$1
    local endpoint=$2
    local description=$3
    
    log_msg "\n=== Testing ${description} (port ${port}) ===" "$YELLOW"
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_msg "ERROR: Container ${CONTAINER_NAME} is not running" "$RED"
        return 1
    fi
    
    # Test endpoint
    log_msg "Executing: curl -v http://localhost:${port}${endpoint}" ""
    docker exec "${CONTAINER_NAME}" curl -v "http://localhost:${port}${endpoint}" 2>&1 | tee -a "$LOG_FILE"
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        log_msg "✓ Success: ${description} responded" "$GREEN"
        return 0
    else
        log_msg "✗ Failed: ${description} did not respond (exit code: ${exit_code})" "$RED"
        return 1
    fi
}

# Function to test POST webhook
test_webhook_post() {
    local port=$1
    
    log_msg "\n=== Testing POST to /webhook/2fa (port ${port}) ===" "$YELLOW"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_msg "ERROR: Container ${CONTAINER_NAME} is not running" "$RED"
        return 1
    fi
    
    local test_payload='{"message":"test 2fa from P0 verification","source":"test_script","timestamp":"'$(date -Iseconds)'"}'
    
    log_msg "Payload: ${test_payload}" ""
    log_msg "Executing: curl -X POST -H 'Content-Type: application/json' -d '${test_payload}' http://localhost:${port}/webhook/2fa" ""
    
    docker exec "${CONTAINER_NAME}" curl -v -X POST \
        -H "Content-Type: application/json" \
        -d "${test_payload}" \
        "http://localhost:${port}/webhook/2fa" 2>&1 | tee -a "$LOG_FILE"
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        log_msg "✓ Success: POST to webhook succeeded" "$GREEN"
        return 0
    else
        log_msg "✗ Failed: POST to webhook failed (exit code: ${exit_code})" "$RED"
        return 1
    fi
}

# Function to check which port is listening
check_listening_ports() {
    log_msg "\n=== Checking listening ports in container ===" "$YELLOW"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_msg "ERROR: Container ${CONTAINER_NAME} is not running" "$RED"
        return 1
    fi
    
    log_msg "Checking for processes listening on ports 4001 and 5000:" ""
    docker exec "${CONTAINER_NAME}" sh -c "netstat -tlnp 2>/dev/null | grep -E ':4001|:5000' || ss -tlnp 2>/dev/null | grep -E ':4001|:5000' || lsof -i :4001,5000 2>/dev/null || echo 'Could not determine listening ports (netstat/ss/lsof not available)'" 2>&1 | tee -a "$LOG_FILE"
}

# Main execution
main() {
    log_msg "\n=====================================================================" "$GREEN"
    log_msg "P0 Bridge Health Verification - Started at $(date)" "$GREEN"
    log_msg "Container: ${CONTAINER_NAME}" "$GREEN"
    log_msg "Log file: ${LOG_FILE}" "$GREEN"
    log_msg "=====================================================================" "$GREEN"
    
    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        log_msg "ERROR: docker command not found. Please ensure Docker is installed." "$RED"
        exit 1
    fi
    
    # Check listening ports first
    check_listening_ports
    
    # Test health endpoint on port 5000
    test_endpoint 5000 "/health" "Bridge Health Endpoint (5000)"
    health_5000=$?
    
    # Test health endpoint on port 4001
    test_endpoint 4001 "/health" "Bridge Health Endpoint (4001)"
    health_4001=$?
    
    # Test status endpoint on port 5000
    test_endpoint 5000 "/status" "Bridge Status Endpoint (5000)"
    status_5000=$?
    
    # Test status endpoint on port 4001
    test_endpoint 4001 "/status" "Bridge Status Endpoint (4001)"
    status_4001=$?
    
    # Test gateway status on port 5000
    test_endpoint 5000 "/gateway/status" "Gateway Status Endpoint (5000)"
    gw_status_5000=$?
    
    # Test POST webhook on port 5000
    test_webhook_post 5000
    webhook_5000=$?
    
    # Test POST webhook on port 4001
    test_webhook_post 4001
    webhook_4001=$?
    
    # Summary
    log_msg "\n=====================================================================" "$GREEN"
    log_msg "Test Summary:" "$GREEN"
    log_msg "=====================================================================" "$GREEN"
    
    [ $health_5000 -eq 0 ] && log_msg "✓ Health endpoint (5000): OK" "$GREEN" || log_msg "✗ Health endpoint (5000): FAILED" "$RED"
    [ $health_4001 -eq 0 ] && log_msg "✓ Health endpoint (4001): OK" "$GREEN" || log_msg "✗ Health endpoint (4001): FAILED" "$RED"
    [ $status_5000 -eq 0 ] && log_msg "✓ Status endpoint (5000): OK" "$GREEN" || log_msg "✗ Status endpoint (5000): FAILED" "$RED"
    [ $status_4001 -eq 0 ] && log_msg "✓ Status endpoint (4001): OK" "$GREEN" || log_msg "✗ Status endpoint (4001): FAILED" "$RED"
    [ $gw_status_5000 -eq 0 ] && log_msg "✓ Gateway status endpoint (5000): OK" "$GREEN" || log_msg "✗ Gateway status endpoint (5000): FAILED" "$RED"
    [ $webhook_5000 -eq 0 ] && log_msg "✓ Webhook POST (5000): OK" "$GREEN" || log_msg "✗ Webhook POST (5000): FAILED" "$RED"
    [ $webhook_4001 -eq 0 ] && log_msg "✓ Webhook POST (4001): OK" "$GREEN" || log_msg "✗ Webhook POST (4001): FAILED" "$RED"
    
    log_msg "\n=====================================================================" "$GREEN"
    log_msg "Recommendations based on test results:" "$YELLOW"
    log_msg "=====================================================================" "$GREEN"
    
    if [ $webhook_5000 -ne 0 ] && [ $webhook_4001 -ne 0 ]; then
        log_msg "⚠ ISSUE: Bridge not responding on either port" "$RED"
        log_msg "  → Check if bridge server is running in container" "$YELLOW"
        log_msg "  → Verify bridge server startup in container logs: docker logs ${CONTAINER_NAME}" "$YELLOW"
        log_msg "  → Check for port binding issues" "$YELLOW"
    elif [ $webhook_5000 -eq 0 ]; then
        log_msg "✓ Bridge is responding on port 5000" "$GREEN"
        log_msg "  → Ensure launcher scripts POST to localhost:5000/webhook/2fa" "$YELLOW"
        log_msg "  → Next: Check if notifications reach mobile (P1)" "$YELLOW"
    elif [ $webhook_4001 -eq 0 ]; then
        log_msg "⚠ Bridge is responding on port 4001, NOT 5000" "$YELLOW"
        log_msg "  → Update launcher scripts to POST to localhost:4001/webhook/2fa" "$YELLOW"
        log_msg "  → OR reconfigure bridge to listen on port 5000" "$YELLOW"
    fi
    
    log_msg "\nFull log saved to: ${LOG_FILE}" ""
    log_msg "=====================================================================" "$GREEN"
}

# Run main function
main "$@"
