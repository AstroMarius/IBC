# P0 Bridge Health Test Results

**Date:** [Insert Date]  
**Tester:** [Insert Name]  
**Environment:** [Insert Environment - e.g., Production, Staging, Local]  
**Container Name:** [Insert Container Name - e.g., ibkr-gateway]

---

## Test Execution Summary

| Test | Port | Result | HTTP Status | Notes |
|------|------|--------|-------------|-------|
| Health Endpoint | 5000 | ☐ Pass ☐ Fail | | |
| Health Endpoint | 4001 | ☐ Pass ☐ Fail | | |
| Status Endpoint | 5000 | ☐ Pass ☐ Fail | | |
| Status Endpoint | 4001 | ☐ Pass ☐ Fail | | |
| Gateway Status | 5000 | ☐ Pass ☐ Fail | | |
| Gateway Status | 4001 | ☐ Pass ☐ Fail | | |
| Webhook POST | 5000 | ☐ Pass ☐ Fail | | |
| Webhook POST | 4001 | ☐ Pass ☐ Fail | | |

---

## Listening Ports in Container

Output from `netstat`/`ss`/`lsof`:
```
[Insert command output showing which ports are listening]
```

**Analysis:**
- Bridge Server Port: [Insert port - e.g., 5000 or 4001]
- Gateway API Port: [Insert port - typically 4001]
- Other Services: [List any other services and ports]

---

## Detailed Test Results

### 1. Health Endpoint Test (Port 5000)

**Command:**
```bash
curl -v http://localhost:5000/health
```

**Output:**
```
[Insert full curl output]
```

**Result:** ☐ Pass ☐ Fail

**Observations:**
- [Insert any observations]

---

### 2. Health Endpoint Test (Port 4001)

**Command:**
```bash
curl -v http://localhost:4001/health
```

**Output:**
```
[Insert full curl output]
```

**Result:** ☐ Pass ☐ Fail

**Observations:**
- [Insert any observations]

---

### 3. Webhook POST Test (Port 5000)

**Command:**
```bash
curl -v -X POST -H "Content-Type: application/json" \
  -d '{"message":"test 2fa","source":"test_script","timestamp":"2025-10-11T09:00:00Z"}' \
  http://localhost:5000/webhook/2fa
```

**Output:**
```
[Insert full curl output]
```

**Result:** ☐ Pass ☐ Fail

**Observations:**
- [Insert any observations]
- Did mobile device receive notification? ☐ Yes ☐ No

---

### 4. Webhook POST Test (Port 4001)

**Command:**
```bash
curl -v -X POST -H "Content-Type: application/json" \
  -d '{"message":"test 2fa","source":"test_script","timestamp":"2025-10-11T09:00:00Z"}' \
  http://localhost:4001/webhook/2fa
```

**Output:**
```
[Insert full curl output]
```

**Result:** ☐ Pass ☐ Fail

**Observations:**
- [Insert any observations]
- Did mobile device receive notification? ☐ Yes ☐ No

---

## Container and Bridge Logs

### Container Startup Logs
```bash
docker logs ibkr-gateway --tail 50
```

**Output:**
```
[Insert relevant startup logs showing bridge initialization]
```

### Bridge Server Logs (if separate)
```
[Insert bridge server logs showing webhook processing]
```

### Notification Processing Logs
```
[Insert any logs related to notification/webhook processing]
```

---

## Diagnosis

Based on the test results, select the applicable scenario:

☐ **Scenario 1: Bridge Not Responding**
- Bridge server is not running or not accessible
- Action Required: Fix bridge startup/configuration

☐ **Scenario 2: Port Mismatch (Bridge on 4001, Launcher expects 5000)**
- Bridge responding on port 4001 but launcher posting to 5000
- Action Required: Align ports between launcher and bridge

☐ **Scenario 3: Port Mismatch (Bridge on 5000, Launcher expects 4001)**
- Bridge responding on port 5000 but launcher posting to 4001
- Action Required: Align ports between launcher and bridge

☐ **Scenario 4: Bridge OK, But No Mobile Notification**
- Webhook POST succeeds (HTTP 200/201/202)
- But no push notification received on mobile
- Action Required: Proceed to P1 (check FCM/APNs credentials and logs)

☐ **Scenario 5: Launcher Not Detecting 2FA**
- Bridge tests pass but launcher never sends webhook
- Action Required: Enhance launcher monitoring (patterns + last_2fa.json)

---

## Required Actions

### Immediate Actions (P0 Fixes)
1. [ ] [Insert action item 1]
2. [ ] [Insert action item 2]
3. [ ] [Insert action item 3]

### Follow-up Actions (P1)
1. [ ] Check FCM/APNs credentials in bridge
2. [ ] Verify mobile app registration
3. [ ] Review bridge logs for notification send errors
4. [ ] Test manual push notification (outside 2FA flow)

### Launcher Improvements (Parallel with P1)
1. [ ] Add response code logging in `send_notification()`
2. [ ] Monitor `last_2fa.json` file as additional trigger
3. [ ] Expand 2FA detection patterns
4. [ ] Add detailed logging with timestamps

---

## Code Changes Required

### File: `start_headless_gateway.sh` (or launcher script)

**Current send_notification() function:**
```bash
[Insert current implementation if known]
```

**Proposed changes:**
```bash
send_notification() {
    local message="$1"
    local timestamp=$(date -Iseconds)
    local log_file="/app/ibc/logs/notifications.log"
    
    # Log the attempt
    echo "[$(date)] Sending notification: ${message}" >> "${log_file}"
    
    # Send POST with full logging
    response=$(curl -v -X POST \
        -H "Content-Type: application/json" \
        -d "{\"message\":\"${message}\",\"source\":\"launcher\",\"timestamp\":\"${timestamp}\"}" \
        http://localhost:5000/webhook/2fa 2>&1)  # TODO: Verify correct port (5000 or 4001)
    curl_exit=$?
    
    # Log the result
    echo "[$(date)] curl exit code: ${curl_exit}" >> "${log_file}"
    echo "[$(date)] HTTP response: ${response}" >> "${log_file}"
    
    if [ $curl_exit -ne 0 ]; then
        echo "[$(date)] ERROR: Failed to send notification (curl exit ${curl_exit})" >> "${log_file}"
    fi
}
```

**Port to use based on test results:**
- [ ] Port 5000 (if bridge responds on 5000)
- [ ] Port 4001 (if bridge responds on 4001)

---

## Mobile Notification Verification

If webhook POST succeeded:

**Did push notification arrive on mobile device?**
- ☐ Yes - System working correctly
- ☐ No - Proceed to P1 to check FCM/APNs

**If No, check:**
1. Bridge logs for FCM/APNs send attempts
2. FCM service account credentials
3. APNs certificate validity
4. Mobile app registration status
5. Device notification permissions

---

## Recommendations

### Short-term (Immediate)
[List immediate recommendations based on test results]

### Medium-term (P1 Investigation)
[List P1 follow-up items if bridge is working but notifications not arriving]

### Long-term (System Improvements)
[List improvements to prevent future issues]

---

## Attachments

- Log File: `bridge_health_test_[timestamp].log`
- Screenshots: [List any relevant screenshots]
- Additional Notes: [Any other relevant information]

---

## Sign-off

**Test Completed By:** [Name]  
**Date:** [Date]  
**Next Step:** [Action to take based on results]
