# Quick Fix Reference Guide

This guide provides ready-to-use code patches for common P0 issues discovered during bridge health testing.

---

## Fix 1: Update Launcher to POST to Correct Port

### Problem
Bridge is listening on port 4001, but launcher is posting to port 5000 (or vice versa).

### Solution
Update the `send_notification()` function in the launcher script to use the correct port.

### File to Edit
`docker/ibkr_gateway/ibkr/start_headless_gateway.sh` (or wherever launcher script is located)

### Find This Code:
```bash
send_notification() {
    local message="$1"
    curl -X POST \
        -H "Content-Type: application/json" \
        -d "{\"message\":\"${message}\",\"source\":\"launcher\"}" \
        http://localhost:5000/webhook/2fa
}
```

### Replace With (if bridge is on port 4001):
```bash
send_notification() {
    local message="$1"
    curl -X POST \
        -H "Content-Type: application/json" \
        -d "{\"message\":\"${message}\",\"source\":\"launcher\"}" \
        http://localhost:4001/webhook/2fa
}
```

---

## Fix 2: Add Logging to send_notification()

### Problem
Launcher sends webhook but we can't tell if it succeeded or failed.

### Solution
Add comprehensive logging to track POST attempts and responses.

### File to Edit
`docker/ibkr_gateway/ibkr/start_headless_gateway.sh`

### Find This Code:
```bash
send_notification() {
    local message="$1"
    curl -X POST \
        -H "Content-Type: application/json" \
        -d "{\"message\":\"${message}\",\"source\":\"launcher\"}" \
        http://localhost:5000/webhook/2fa
}
```

### Replace With:
```bash
send_notification() {
    local message="$1"
    local timestamp=$(date -Iseconds)
    local log_file="/app/ibc/logs/notifications.log"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "${log_file}")"
    
    # Log the attempt
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempting to send notification: ${message}" >> "${log_file}"
    
    # Send POST and capture full output
    response=$(curl -v -s -w "\nHTTP_CODE:%{http_code}\nCURL_EXIT:0" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"message\":\"${message}\",\"source\":\"launcher\",\"timestamp\":\"${timestamp}\"}" \
        http://localhost:5000/webhook/2fa 2>&1) || {
        curl_exit=$?
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: curl failed with exit code ${curl_exit}" >> "${log_file}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Full response: ${response}" >> "${log_file}"
        return 1
    }
    
    # Extract HTTP status code
    http_code=$(echo "${response}" | grep "HTTP_CODE:" | cut -d: -f2)
    
    # Log the result
    if [[ "${http_code}" =~ ^(200|201|202)$ ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: Notification sent (HTTP ${http_code})" >> "${log_file}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Unexpected HTTP code ${http_code}" >> "${log_file}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Full response: ${response}" >> "${log_file}"
    fi
}
```

---

## Fix 3: Monitor last_2fa.json as Additional Trigger

### Problem
Log pattern matching misses some 2FA events.

### Solution
Add file-based monitoring in addition to log pattern matching.

### File to Edit
`docker/ibkr_gateway/ibkr/start_headless_gateway.sh`

### Add This Function:
```bash
check_2fa_marker_file() {
    local marker_file="/app/ibc/logs/last_2fa.json"
    local processed_file="/app/ibc/logs/last_2fa_processed.txt"
    
    if [ -f "${marker_file}" ]; then
        # Get last modification time of marker file
        marker_mtime=$(stat -c %Y "${marker_file}" 2>/dev/null || stat -f %m "${marker_file}" 2>/dev/null)
        
        # Check if we've already processed this instance
        if [ -f "${processed_file}" ]; then
            last_processed=$(cat "${processed_file}")
        else
            last_processed=0
        fi
        
        # If marker file is newer than last processed time, it's a new 2FA event
        if [ "${marker_mtime}" -gt "${last_processed}" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 2FA detected via marker file" >> /app/ibc/logs/notifications.log
            
            # Extract 2FA code from marker file if available
            if command -v jq &> /dev/null; then
                twofa_code=$(jq -r '.code // "2FA required"' "${marker_file}" 2>/dev/null)
            else
                twofa_code="2FA required (see ${marker_file})"
            fi
            
            # Send notification
            send_notification "${twofa_code}"
            
            # Mark as processed
            echo "${marker_mtime}" > "${processed_file}"
            
            return 0
        fi
    fi
    
    return 1
}
```

### Add This to Monitor Loop:
```bash
monitor_logs() {
    # ... existing log monitoring code ...
    
    # Add file-based check (run periodically or in parallel)
    while true; do
        check_2fa_marker_file && {
            echo "2FA notification sent via marker file"
        }
        sleep 5  # Check every 5 seconds
    done
}
```

---

## Fix 4: Expand 2FA Detection Patterns

### Problem
Current patterns don't catch all 2FA dialog variations.

### Solution
Add more comprehensive pattern matching.

### File to Edit
`docker/ibkr_gateway/ibkr/start_headless_gateway.sh`

### Find This Code:
```bash
tail -f /app/ibc/logs/ibc_output.log | grep -E "WINDOW_OPENED.*Auth.*|NS_FIX_START|onNsFixStart"
```

### Replace With:
```bash
tail -f /app/ibc/logs/ibc_output.log | grep -E "WINDOW_OPENED.*Auth.*|NS_FIX_START|onNsFixStart|Second Factor|2FA|Two-Factor|Login.*Dialog|Challenge|Authentication.*Required"
```

---

## Fix 5: Configure Bridge to Listen on Correct Port

### Problem
Bridge is on wrong port and needs to be reconfigured.

### Solution A: Environment Variable (if bridge supports it)
```bash
# In docker-compose.yml or container environment
environment:
  - BRIDGE_PORT=5000  # or 4001, depending on requirement
```

### Solution B: Bridge Configuration File
Edit bridge configuration (e.g., `config.ini` or Python script):
```python
# In gateway_bridge_server.py or similar
BRIDGE_PORT = 5000  # Change from 4001 to 5000 or vice versa

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=BRIDGE_PORT)
```

### Solution C: Docker Port Mapping
```yaml
# In docker-compose.yml
ports:
  - "5000:5000"  # Map container port 5000 to host port 5000
```

---

## Fix 6: Combined Enhanced send_notification() with Port Fix

### Complete Enhanced Function
```bash
send_notification() {
    local message="$1"
    local timestamp=$(date -Iseconds)
    local log_file="/app/ibc/logs/notifications.log"
    local bridge_port="${BRIDGE_PORT:-5000}"  # Default to 5000, override with env var
    
    # Ensure log directory exists
    mkdir -p "$(dirname "${log_file}")"
    
    # Log the attempt
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempting to send notification to localhost:${bridge_port}" >> "${log_file}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Message: ${message}" >> "${log_file}"
    
    # Try primary port
    response=$(curl -v -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 -X POST \
        -H "Content-Type: application/json" \
        -d "{\"message\":\"${message}\",\"source\":\"launcher\",\"timestamp\":\"${timestamp}\"}" \
        "http://localhost:${bridge_port}/webhook/2fa" 2>&1)
    curl_exit=$?
    
    # Extract HTTP status code
    http_code=$(echo "${response}" | grep "HTTP_CODE:" | cut -d: -f2)
    
    if [ $curl_exit -eq 0 ] && [[ "${http_code}" =~ ^(200|201|202)$ ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: Notification sent (HTTP ${http_code})" >> "${log_file}"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAILED on port ${bridge_port}: curl_exit=${curl_exit}, http_code=${http_code}" >> "${log_file}"
        
        # Try fallback port
        local fallback_port
        if [ "${bridge_port}" = "5000" ]; then
            fallback_port=4001
        else
            fallback_port=5000
        fi
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Trying fallback port ${fallback_port}..." >> "${log_file}"
        
        response=$(curl -v -s -w "\nHTTP_CODE:%{http_code}" --max-time 10 -X POST \
            -H "Content-Type: application/json" \
            -d "{\"message\":\"${message}\",\"source\":\"launcher\",\"timestamp\":\"${timestamp}\"}" \
            "http://localhost:${fallback_port}/webhook/2fa" 2>&1)
        curl_exit=$?
        http_code=$(echo "${response}" | grep "HTTP_CODE:" | cut -d: -f2)
        
        if [ $curl_exit -eq 0 ] && [[ "${http_code}" =~ ^(200|201|202)$ ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS on fallback port ${fallback_port} (HTTP ${http_code})" >> "${log_file}"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOTE: Update BRIDGE_PORT=${fallback_port} in environment" >> "${log_file}"
            return 0
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAILED on fallback port: curl_exit=${curl_exit}, http_code=${http_code}" >> "${log_file}"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Full response: ${response}" >> "${log_file}"
            return 1
        fi
    fi
}
```

---

## Testing Changes

After applying any fix:

1. **Restart the affected service:**
   ```bash
   docker restart ibkr-gateway
   ```

2. **Monitor logs:**
   ```bash
   docker logs -f ibkr-gateway
   ```

3. **Check notification log:**
   ```bash
   docker exec ibkr-gateway tail -f /app/ibc/logs/notifications.log
   ```

4. **Re-run P0 tests:**
   ```bash
   ./test_bridge_health.sh
   ```

5. **Test actual 2FA flow:**
   - Trigger a login that requires 2FA
   - Check if notification arrives on mobile
   - Verify in logs that webhook was sent and received

---

## Validation Checklist

After applying fixes:
- [ ] P0 test scripts pass
- [ ] Bridge responds on expected port
- [ ] Webhook POST returns HTTP 200/201/202
- [ ] Notification log shows successful sends
- [ ] Mobile device receives push notification (if FCM/APNs configured)
- [ ] 2FA flow completes successfully

---

## Rollback Instructions

If a fix causes issues:

1. **Revert file changes:**
   ```bash
   git checkout -- path/to/modified/file.sh
   ```

2. **Restart services:**
   ```bash
   docker restart ibkr-gateway
   ```

3. **Verify system returns to previous state:**
   ```bash
   ./test_bridge_health.sh
   ```

---

## Support

If fixes don't resolve the issue, collect this information:
1. P0 test results (full log files)
2. Bridge startup logs
3. Notification logs
4. Container port mappings: `docker port ibkr-gateway`
5. Container network info: `docker inspect ibkr-gateway | grep -A 20 NetworkSettings`
