#!/bin/bash

#==============================================================================
# Standalone Bridge Webhook Test Script
#
# This script can test bridge webhook endpoints even without Docker
# It expects the bridge server to be accessible at a given host:port
#
# Usage:
#   ./test_webhook_standalone.sh [host] [port]
#
# Default: localhost:5000
#==============================================================================

HOST="${1:-localhost}"
PORT="${2:-5000}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="webhook_test_${TIMESTAMP}.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_msg() {
    echo -e "${2}${1}${NC}" | tee -a "$LOG_FILE"
}

test_health() {
    log_msg "\n=== Testing Health Endpoint ===" "$YELLOW"
    log_msg "URL: http://${HOST}:${PORT}/health" ""
    
    response=$(curl -v -s -w "\n\nHTTP_STATUS:%{http_code}" "http://${HOST}:${PORT}/health" 2>&1)
    curl_exit=$?
    
    echo "$response" | tee -a "$LOG_FILE"
    
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    
    if [ $curl_exit -eq 0 ] && [ "$http_status" = "200" ]; then
        log_msg "✓ Health endpoint OK (HTTP 200)" "$GREEN"
        return 0
    elif [ $curl_exit -eq 0 ]; then
        log_msg "✗ Health endpoint returned HTTP ${http_status}" "$RED"
        return 1
    else
        log_msg "✗ Could not connect to health endpoint (curl exit code: ${curl_exit})" "$RED"
        return 1
    fi
}

test_status() {
    log_msg "\n=== Testing Status Endpoint ===" "$YELLOW"
    log_msg "URL: http://${HOST}:${PORT}/status" ""
    
    response=$(curl -v -s -w "\n\nHTTP_STATUS:%{http_code}" "http://${HOST}:${PORT}/status" 2>&1)
    curl_exit=$?
    
    echo "$response" | tee -a "$LOG_FILE"
    
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    
    if [ $curl_exit -eq 0 ] && [ "$http_status" = "200" ]; then
        log_msg "✓ Status endpoint OK (HTTP 200)" "$GREEN"
        return 0
    elif [ $curl_exit -eq 0 ]; then
        log_msg "⚠ Status endpoint returned HTTP ${http_status}" "$YELLOW"
        return 1
    else
        log_msg "✗ Could not connect to status endpoint (curl exit code: ${curl_exit})" "$RED"
        return 1
    fi
}

test_webhook_post() {
    log_msg "\n=== Testing POST to /webhook/2fa ===" "$YELLOW"
    log_msg "URL: http://${HOST}:${PORT}/webhook/2fa" ""
    
    test_payload="{\"message\":\"P0 test 2FA notification\",\"source\":\"p0_test_script\",\"timestamp\":\"$(date -Iseconds)\"}"
    
    log_msg "Payload: ${test_payload}" ""
    
    response=$(curl -v -s -w "\n\nHTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "${test_payload}" \
        "http://${HOST}:${PORT}/webhook/2fa" 2>&1)
    curl_exit=$?
    
    echo "$response" | tee -a "$LOG_FILE"
    
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    
    if [ $curl_exit -eq 0 ] && { [ "$http_status" = "200" ] || [ "$http_status" = "201" ] || [ "$http_status" = "202" ]; }; then
        log_msg "✓ Webhook POST succeeded (HTTP ${http_status})" "$GREEN"
        log_msg "  → Check bridge logs to verify notification was processed" "$YELLOW"
        log_msg "  → Check mobile device to see if push notification arrived" "$YELLOW"
        return 0
    elif [ $curl_exit -eq 0 ]; then
        log_msg "✗ Webhook POST returned HTTP ${http_status}" "$RED"
        log_msg "  → Bridge may be rejecting the request" "$YELLOW"
        log_msg "  → Check bridge logs for errors" "$YELLOW"
        return 1
    else
        log_msg "✗ Could not connect to webhook endpoint (curl exit code: ${curl_exit})" "$RED"
        log_msg "  → Bridge may not be running" "$YELLOW"
        log_msg "  → Check host/port configuration" "$YELLOW"
        return 1
    fi
}

main() {
    log_msg "=====================================================================" "$GREEN"
    log_msg "Standalone Bridge Webhook Test - Started at $(date)" "$GREEN"
    log_msg "Target: ${HOST}:${PORT}" "$GREEN"
    log_msg "Log file: ${LOG_FILE}" "$GREEN"
    log_msg "=====================================================================" "$GREEN"
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        log_msg "ERROR: curl command not found. Please install curl." "$RED"
        exit 1
    fi
    
    # Run tests
    test_health
    health_result=$?
    
    test_status
    status_result=$?
    
    test_webhook_post
    webhook_result=$?
    
    # Summary
    log_msg "\n=====================================================================" "$GREEN"
    log_msg "Test Summary for ${HOST}:${PORT}:" "$GREEN"
    log_msg "=====================================================================" "$GREEN"
    
    [ $health_result -eq 0 ] && log_msg "✓ Health: OK" "$GREEN" || log_msg "✗ Health: FAILED" "$RED"
    [ $status_result -eq 0 ] && log_msg "✓ Status: OK" "$GREEN" || log_msg "✗ Status: FAILED" "$RED"
    [ $webhook_result -eq 0 ] && log_msg "✓ Webhook: OK" "$GREEN" || log_msg "✗ Webhook: FAILED" "$RED"
    
    log_msg "\n=====================================================================" "$GREEN"
    log_msg "Next Steps:" "$YELLOW"
    log_msg "=====================================================================" "$GREEN"
    
    if [ $webhook_result -eq 0 ]; then
        log_msg "✓ Bridge webhook is responding correctly" "$GREEN"
        log_msg "" ""
        log_msg "P1 Actions (if push notification did NOT arrive on mobile):" "$YELLOW"
        log_msg "  1. Check bridge logs for FCM/APNs send status" ""
        log_msg "  2. Verify FCM/APNs credentials are configured in bridge" ""
        log_msg "  3. Check mobile app registration status" ""
        log_msg "  4. Verify notification permissions on mobile device" ""
        log_msg "" ""
        log_msg "Launcher Improvements (parallel with P1):" "$YELLOW"
        log_msg "  1. Add response code logging in send_notification() function" ""
        log_msg "  2. Monitor last_2fa.json file as additional trigger" ""
        log_msg "  3. Expand 2FA detection patterns in monitor_logs()" ""
    else
        log_msg "✗ Bridge webhook is NOT responding" "$RED"
        log_msg "" ""
        log_msg "Required Fixes:" "$YELLOW"
        log_msg "  1. Verify bridge server is running" ""
        log_msg "  2. Check if bridge is listening on port ${PORT}" ""
        log_msg "     Try alternative ports: 5000, 4001" ""
        log_msg "  3. Update launcher send_notification() to correct host:port" ""
        log_msg "  4. Add detailed logging in send_notification():" ""
        log_msg "     - Log HTTP response code" ""
        log_msg "     - Log curl stderr output" ""
        log_msg "     - Add timestamp to each log entry" ""
    fi
    
    log_msg "\nFull log saved to: ${LOG_FILE}" ""
    log_msg "=====================================================================" "$GREEN"
    
    # Return appropriate exit code
    if [ $webhook_result -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
