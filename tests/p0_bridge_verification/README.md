# P0 Bridge Health Verification

This directory contains scripts to verify the health of the IBKR Gateway Bridge server and test the 2FA webhook notification system.

## Problem Context

The 2FA notification system consists of several components:
1. **IBC/IBKR Gateway** - Java application that detects 2FA challenges
2. **Launcher Script** - Monitors logs and sends notifications
3. **Bridge Server** - Receives webhooks and forwards to mobile via FCM/APNs
4. **Mobile App** - Receives push notifications for 2FA approval

When 2FA is not working, the issue could be at any of these integration points.

## Test Scripts

### 1. test_bridge_health.sh (Docker Container Test)

Tests the bridge server running inside a Docker container.

**Usage:**
```bash
./test_bridge_health.sh [container_name]
```

**Default container name:** `ibkr-gateway`

**What it tests:**
- Bridge health endpoint on ports 5000 and 4001
- Bridge status endpoint
- Gateway status endpoint
- POST to /webhook/2fa endpoint
- Which ports are actually listening in the container

**Example:**
```bash
# Test with default container name
./test_bridge_health.sh

# Test with custom container name
./test_bridge_health.sh my-ibkr-container
```

### 2. test_webhook_standalone.sh (Direct Host Test)

Tests the bridge server directly without Docker (for local development or when bridge runs on host).

**Usage:**
```bash
./test_webhook_standalone.sh [host] [port]
```

**Default:** `localhost:5000`

**What it tests:**
- Health endpoint accessibility
- Status endpoint accessibility
- POST to /webhook/2fa with test payload

**Example:**
```bash
# Test default localhost:5000
./test_webhook_standalone.sh

# Test custom host/port
./test_webhook_standalone.sh localhost 4001

# Test remote bridge
./test_webhook_standalone.sh 192.168.1.100 5000
```

## Interpreting Results

### Scenario 1: Bridge Not Responding on Any Port

**Symptoms:**
```
✗ Health endpoint (5000): FAILED
✗ Health endpoint (4001): FAILED
✗ Webhook POST (5000): FAILED
✗ Webhook POST (4001): FAILED
```

**Diagnosis:** Bridge server is not running or not accessible

**Actions:**
1. Check if bridge server process is running in container:
   ```bash
   docker exec ibkr-gateway ps aux | grep -i bridge
   ```

2. Check container logs:
   ```bash
   docker logs ibkr-gateway --tail 100
   ```

3. Verify bridge server is started in container CMD/ENTRYPOINT

4. Check for startup errors in bridge logs

### Scenario 2: Bridge Responds on Port 4001 (Not 5000)

**Symptoms:**
```
✗ Health endpoint (5000): FAILED
✓ Health endpoint (4001): OK
✗ Webhook POST (5000): FAILED
✓ Webhook POST (4001): OK
```

**Diagnosis:** Bridge is listening on port 4001, but launcher is posting to port 5000

**Actions:**
1. **Option A - Update Launcher (Recommended if bridge must stay on 4001):**
   - Edit `start_headless_gateway.sh` or launcher script
   - Change `send_notification()` function to POST to `localhost:4001/webhook/2fa`
   - Example fix:
     ```bash
     # Old: curl -X POST http://localhost:5000/webhook/2fa
     # New: curl -X POST http://localhost:4001/webhook/2fa
     ```

2. **Option B - Reconfigure Bridge:**
   - Update bridge server configuration to listen on port 5000
   - Restart bridge server
   - Re-run tests to verify

### Scenario 3: Bridge Responds, But No Mobile Notification

**Symptoms:**
```
✓ Health endpoint (5000): OK
✓ Webhook POST (5000): OK
```
BUT: No push notification arrives on mobile device

**Diagnosis:** Bridge receives webhook but fails to send push notification

**P1 Actions:**

1. **Check Bridge Logs for FCM/APNs Activity:**
   ```bash
   docker logs ibkr-gateway | grep -i "fcm\|apns\|notification\|push"
   ```

2. **Verify FCM/APNs Credentials:**
   - Check if bridge has FCM service account JSON file
   - Check if APNs certificate is valid and not expired
   - Verify credentials are correctly loaded in bridge configuration

3. **Check Mobile App Registration:**
   - Verify mobile app has registered with FCM/APNs
   - Check if device token is valid and current
   - Test push notification manually (outside of 2FA flow)

4. **Check Bridge Code:**
   - Verify `gateway_manager.notify_2fa_required()` is called
   - Check if notification payload is correctly formatted
   - Look for exceptions in FCM/APNs sending code

### Scenario 4: Launcher Not Detecting 2FA

**Symptoms:**
- Bridge tests pass
- But launcher never sends webhook (no POST in logs)

**Diagnosis:** Launcher monitoring is not detecting 2FA events

**Actions:**

1. **Expand Monitoring Patterns:**
   Edit launcher script to detect more 2FA patterns:
   ```bash
   # Current pattern
   grep -E "WINDOW_OPENED.*Auth.*|NS_FIX_START|onNsFixStart"
   
   # Enhanced pattern
   grep -E "2FA|Second Factor|Auth|Login Dialog|Challenge|WINDOW_OPENED.*Auth.*|NS_FIX_START|onNsFixStart"
   ```

2. **Monitor last_2fa.json File:**
   Instead of only monitoring logs, also watch for `last_2fa.json` file creation:
   ```bash
   # Add to launcher monitoring
   if [ -f /app/ibc/logs/last_2fa.json ]; then
       send_notification "2FA detected via last_2fa.json"
   fi
   ```

3. **Add Detailed Logging:**
   Add logging to `send_notification()` function:
   ```bash
   send_notification() {
       local message="$1"
       local timestamp=$(date -Iseconds)
       echo "[$(date)] Sending 2FA notification: ${message}" >> /app/ibc/logs/notifications.log
       
       response=$(curl -v -X POST \
           -H "Content-Type: application/json" \
           -d "{\"message\":\"${message}\",\"source\":\"launcher\",\"timestamp\":\"${timestamp}\"}" \
           http://localhost:5000/webhook/2fa 2>&1)
       curl_exit=$?
       
       echo "[$(date)] curl exit code: ${curl_exit}" >> /app/ibc/logs/notifications.log
       echo "[$(date)] curl response: ${response}" >> /app/ibc/logs/notifications.log
   }
   ```

## Output Files

Each test run creates a timestamped log file:
- `bridge_health_test_YYYY-MM-DD_HH-MM-SS.log`
- `webhook_test_YYYY-MM-DD_HH-MM-SS.log`

These files contain:
- Complete curl verbose output
- HTTP response codes and headers
- Test results summary
- Recommended actions

## Quick Diagnostic Flow

1. **Run bridge health test:**
   ```bash
   ./test_bridge_health.sh
   ```

2. **Based on results:**
   - If bridge not responding → Fix bridge startup
   - If wrong port → Align launcher and bridge ports
   - If bridge OK but no mobile notification → Proceed to P1 (FCM/APNs check)

3. **If P1 needed, check:**
   - Bridge logs: `docker logs ibkr-gateway | grep -i notification`
   - FCM credentials: Verify service account JSON exists and is valid
   - Mobile app: Verify it's registered and can receive test notifications

4. **If launcher not sending:**
   - Check IBC logs for 2FA detection patterns
   - Enhance monitoring patterns
   - Add `last_2fa.json` monitoring
   - Add detailed logging to `send_notification()`

## Related Files

Based on the UML analysis, the key files in the full system are:
- `docker/ibkr_gateway/ibkr/start_headless_gateway.sh` - Launcher script
- `docker/ibkr_gateway/ibkr/gateway_bridge_server.py` - Bridge server
- `docker/ibkr_gateway/ibkr/ibkr_session_manager.py` - Session manager
- `/app/ibc/logs/last_2fa.json` - 2FA detection marker file
- `/app/ibc/logs/notifications.log` - Notification log file

## Next Steps After P0

If P0 tests identify issues:
1. Apply minimal fixes to align ports or add logging
2. Re-run P0 tests to verify fixes
3. If bridge is working, proceed to P1 (FCM/APNs verification)
4. If launcher needs improvement, implement enhanced monitoring

## Support

For detailed analysis of the 2FA pipeline, see:
- `docs/analysis/Headless_2FA_Pipeline.puml` - Current system UML
- `docs/analysis/Headless_2FA_Pipeline_backup.puml` - Working backup UML
- Compare these to identify what changed and broke the notification flow
