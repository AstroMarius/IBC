# Quick Troubleshooting Guide

Use this flowchart-style guide to quickly identify and fix issues.

## Start Here: Run the Test

```bash
./test_bridge_health.sh
```

## Decision Tree

```
┌─────────────────────────────────┐
│   Run test_bridge_health.sh     │
└──────────────┬──────────────────┘
               │
               ▼
        ┌──────────────┐
        │ All tests    │
        │   passed?    │
        └──────┬───────┘
               │
         ┌─────┴─────┐
         │           │
        YES          NO
         │           │
         ▼           ▼
    ┌────────┐  ┌────────────────┐
    │ Check  │  │ Which scenario │
    │ mobile │  │ matches?       │
    └───┬────┘  └────────┬───────┘
        │                │
        │         ┌──────┴──────────┬───────────────┬──────────────┐
        │         │                 │               │              │
        │         ▼                 ▼               ▼              ▼
        │   ┌─────────┐      ┌──────────┐   ┌──────────┐  ┌──────────┐
        │   │ Bridge  │      │  Port    │   │ Bridge   │  │ Launcher │
        │   │   Not   │      │ Mismatch │   │ Works,   │  │   Not    │
        │   │Responding│     │          │   │ No Push  │  │Detecting │
        │   └─────┬───┘      └─────┬────┘   └────┬─────┘  └────┬─────┘
        │         │                │             │              │
        │         ▼                ▼             ▼              ▼
        │   [Scenario 1]    [Scenario 2]  [Scenario 3]  [Scenario 4]
        │         │                │             │              │
        ▼         ▼                ▼             ▼              ▼
    ┌────────────────────────────────────────────────────────────┐
    │                  Apply Appropriate Fix                      │
    └──────────────────────────────┬─────────────────────────────┘
                                   │
                                   ▼
                              Re-run tests
```

---

## Scenario 1: Bridge Not Responding

### Symptoms
```
✗ Health endpoint (5000): FAILED
✗ Health endpoint (4001): FAILED
✗ Webhook POST (5000): FAILED
✗ Webhook POST (4001): FAILED
```

### Quick Checks
1. **Is container running?**
   ```bash
   docker ps | grep ibkr-gateway
   ```

2. **Check container logs:**
   ```bash
   docker logs ibkr-gateway --tail 50
   ```

3. **Is bridge process running?**
   ```bash
   docker exec ibkr-gateway ps aux | grep -i bridge
   ```

### Common Causes
- Bridge server not started
- Bridge crashed during startup
- Port binding conflict
- Missing dependencies

### Quick Fix
Check logs, fix startup issue, restart container:
```bash
docker restart ibkr-gateway
docker logs -f ibkr-gateway  # Watch for errors
```

### Next Step
Re-run test after fixing:
```bash
./test_bridge_health.sh
```

---

## Scenario 2: Port Mismatch

### Symptoms (Bridge on 4001, expected on 5000)
```
✗ Health endpoint (5000): FAILED
✓ Health endpoint (4001): OK
✗ Webhook POST (5000): FAILED
✓ Webhook POST (4001): OK
```

### Symptoms (Bridge on 5000, expected on 4001)
```
✓ Health endpoint (5000): OK
✗ Health endpoint (4001): FAILED
✓ Webhook POST (5000): OK
✗ Webhook POST (4001): FAILED
```

### Quick Fix Options

**Option A: Update Launcher (if bridge must stay on current port)**

Open `QUICK_FIX_GUIDE.md` → Apply Fix 1 (Update Launcher Port)

Key change:
```bash
# Change this line in send_notification()
curl ... http://localhost:5000/webhook/2fa  # Old
curl ... http://localhost:4001/webhook/2fa  # New (if bridge on 4001)
```

**Option B: Use Auto-Fallback (recommended)**

Apply Fix 6 from `QUICK_FIX_GUIDE.md` - tries both ports automatically.

**Option C: Reconfigure Bridge**

Change bridge configuration to listen on expected port.

### Validation
```bash
docker restart ibkr-gateway
./test_bridge_health.sh
# Should now show both endpoints working
```

---

## Scenario 3: Bridge OK, No Mobile Notification

### Symptoms
```
✓ Health endpoint (5000): OK
✓ Webhook POST (5000): OK
```
BUT: No push notification on mobile

### This is P1 Territory

Bridge is working, issue is in notification delivery.

### Quick Checks

1. **Check bridge logs for FCM/APNs:**
   ```bash
   docker logs ibkr-gateway | grep -i "fcm\|apns\|notification\|push"
   ```

2. **Look for errors:**
   ```bash
   docker logs ibkr-gateway | grep -i "error\|fail\|exception"
   ```

3. **Check if credentials exist:**
   ```bash
   docker exec ibkr-gateway ls -la /path/to/fcm/credentials.json
   ```

### Common Causes
- Missing FCM service account JSON
- Expired APNs certificate
- Mobile app not registered
- Wrong device token
- Notification permissions disabled

### Actions (P1)
1. Verify FCM/APNs credentials configured
2. Test manual push notification
3. Check mobile app registration
4. Verify device token is current
5. Review bridge notification sending code

### Meanwhile: Improve Launcher

Apply these fixes in parallel:
- Fix 2: Enhanced logging
- Fix 3: Monitor last_2fa.json
- Fix 4: Expand detection patterns

---

## Scenario 4: Launcher Not Detecting 2FA

### Symptoms
- Bridge tests pass
- But launcher never sends webhook
- No entries in notifications.log

### Quick Checks

1. **Check if 2FA actually triggered:**
   ```bash
   docker exec ibkr-gateway tail -50 /app/ibc/logs/ibc_output.log
   ```
   Look for: "Second Factor", "Auth", "2FA", "Challenge"

2. **Check for last_2fa.json:**
   ```bash
   docker exec ibkr-gateway cat /app/ibc/logs/last_2fa.json
   ```

3. **Check launcher is running:**
   ```bash
   docker exec ibkr-gateway ps aux | grep -i launcher
   ```

### Quick Fixes

**Fix A: Monitor last_2fa.json (recommended)**

Apply Fix 3 from `QUICK_FIX_GUIDE.md`:
- Adds file-based trigger
- More reliable than log parsing
- Works even if log patterns change

**Fix B: Expand Detection Patterns**

Apply Fix 4 from `QUICK_FIX_GUIDE.md`:
```bash
# Old pattern
grep -E "WINDOW_OPENED.*Auth.*|NS_FIX_START"

# New pattern (catches more variations)
grep -E "2FA|Second Factor|Auth|Login Dialog|Challenge|WINDOW_OPENED.*Auth.*|NS_FIX_START"
```

**Fix C: Add Logging**

Apply Fix 2 to see what launcher is doing:
- Logs every detection attempt
- Shows POST success/failure
- Helps debug pattern matching

### Validation
1. Apply fixes
2. Restart container
3. Trigger 2FA
4. Check logs:
   ```bash
   docker exec ibkr-gateway tail -f /app/ibc/logs/notifications.log
   ```
5. Should see: "[timestamp] 2FA detected..."

---

## Common Commands Reference

### Container Operations
```bash
# Check if running
docker ps | grep ibkr-gateway

# View logs
docker logs ibkr-gateway

# Follow logs
docker logs -f ibkr-gateway

# Restart
docker restart ibkr-gateway

# Execute command
docker exec ibkr-gateway <command>

# Interactive shell
docker exec -it ibkr-gateway /bin/bash
```

### Testing
```bash
# Full test
./test_bridge_health.sh

# Standalone test
./test_webhook_standalone.sh localhost 5000

# Manual webhook test
curl -X POST -H "Content-Type: application/json" \
  -d '{"message":"test"}' \
  http://localhost:5000/webhook/2fa
```

### Log Viewing
```bash
# Bridge startup
docker logs ibkr-gateway --tail 50

# IBC logs
docker exec ibkr-gateway tail -50 /app/ibc/logs/ibc_output.log

# Notification log
docker exec ibkr-gateway tail -f /app/ibc/logs/notifications.log

# Last 2FA marker
docker exec ibkr-gateway cat /app/ibc/logs/last_2fa.json
```

### Port Checking
```bash
# Check listening ports
docker exec ibkr-gateway netstat -tlnp | grep -E '5000|4001'

# Or with ss
docker exec ibkr-gateway ss -tlnp | grep -E '5000|4001'

# Or with lsof
docker exec ibkr-gateway lsof -i :5000,4001
```

---

## Error Messages & Solutions

### "Connection refused"
**Cause:** Service not listening on that port  
**Fix:** Check if bridge is running, verify port

### "HTTP 404 Not Found"
**Cause:** Endpoint doesn't exist  
**Fix:** Check URL path, verify bridge version

### "HTTP 500 Internal Server Error"
**Cause:** Bridge error processing request  
**Fix:** Check bridge logs for exceptions

### "curl: (7) Failed to connect"
**Cause:** Cannot reach host:port  
**Fix:** Verify host/port, check network

### "curl: (28) Operation timed out"
**Cause:** Request taking too long  
**Fix:** Check if service is hung, restart

---

## Success Indicators

✅ **All Working:**
```
✓ Health endpoint (5000): OK
✓ Status endpoint (5000): OK
✓ Webhook POST (5000): OK
✓ Mobile notification received
```

✅ **Bridge OK, P1 Needed:**
```
✓ Health endpoint (5000): OK
✓ Webhook POST (5000): OK
✗ Mobile notification NOT received
→ Proceed to P1 (FCM/APNs check)
```

---

## Getting Help

1. **Review full documentation:**
   - `INDEX.md` - Overview
   - `README.md` - Complete guide
   - `QUICK_FIX_GUIDE.md` - Code fixes
   - `EXAMPLE_OUTPUT.md` - Compare outputs

2. **Collect diagnostic info:**
   - Test log files
   - Container logs
   - Port mappings
   - Network info

3. **Document in template:**
   Use `TEST_RESULTS_TEMPLATE.md` to document findings

---

## Tips

💡 **Always check logs first** - They usually show the problem  
💡 **Test after each change** - Don't stack multiple fixes  
💡 **Keep test logs** - Useful for comparing before/after  
💡 **Use colored output** - Makes issues easy to spot  
💡 **Read recommendations** - Test output guides you to the fix  

---

For more detailed information, see:
- `README.md` - Complete scenarios
- `QUICK_FIX_GUIDE.md` - All code fixes
- `EXAMPLE_OUTPUT.md` - Example test results
