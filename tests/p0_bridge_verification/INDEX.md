# P0 Bridge Health Verification - Implementation Complete

## Overview

This package implements **P0: Bridge Health Verification and POST Test** for diagnosing IBKR Gateway 2FA notification issues.

## What's Included

### 1. Test Scripts

#### `test_bridge_health.sh`
Comprehensive test for Docker containerized bridge servers.
- Tests health endpoints on ports 5000 and 4001
- Tests status endpoints
- Tests POST to /webhook/2fa
- Checks which ports are actually listening
- Generates detailed reports with recommendations

**Usage:**
```bash
./test_bridge_health.sh [container_name]
```

#### `test_webhook_standalone.sh`
Standalone test for direct bridge testing (no Docker required).
- Tests any bridge server accessible via HTTP
- Useful for local development and debugging
- Can test remote bridge servers

**Usage:**
```bash
./test_webhook_standalone.sh [host] [port]
```

### 2. Documentation

#### `README.md`
Complete guide covering:
- Problem context and system architecture
- How to use each test script
- How to interpret test results
- Step-by-step troubleshooting for each scenario
- Next steps based on findings (P1 actions)

#### `QUICK_FIX_GUIDE.md`
Ready-to-use code patches for common issues:
- Fix 1: Update launcher port
- Fix 2: Add logging to send_notification()
- Fix 3: Monitor last_2fa.json file
- Fix 4: Expand 2FA detection patterns
- Fix 5: Configure bridge port
- Fix 6: Combined enhanced solution with fallback

#### `TEST_RESULTS_TEMPLATE.md`
Structured template for documenting test results:
- Test execution checklist
- Detailed results sections
- Diagnosis guide
- Action items tracking
- Code changes documentation

### 3. Log Output

Each test run generates timestamped log files:
- `bridge_health_test_YYYY-MM-DD_HH-MM-SS.log`
- `webhook_test_YYYY-MM-DD_HH-MM-SS.log`

These contain complete curl output, test results, and recommendations.

## Quick Start

### Step 1: Run P0 Tests

Choose the appropriate test based on your environment:

**For Docker environments:**
```bash
cd tests/p0_bridge_verification
./test_bridge_health.sh
```

**For non-Docker or remote testing:**
```bash
cd tests/p0_bridge_verification
./test_webhook_standalone.sh localhost 5000
```

### Step 2: Review Results

The script will output:
- ✓ Pass/✗ Fail for each test
- Summary of findings
- Specific recommendations based on results

### Step 3: Take Action

Based on test results:

| Result | Action |
|--------|--------|
| Bridge not responding | Fix bridge startup/configuration |
| Port mismatch (4001 vs 5000) | Apply Fix 1 or Fix 5 from Quick Fix Guide |
| Bridge OK, no mobile notification | Proceed to P1 (check FCM/APNs) |
| Launcher not detecting 2FA | Apply Fix 3 and Fix 4 |

### Step 4: Apply Fixes

Use the `QUICK_FIX_GUIDE.md` to apply appropriate code patches:

```bash
# 1. Edit the relevant file (e.g., start_headless_gateway.sh)
# 2. Apply the patch from Quick Fix Guide
# 3. Restart services
docker restart ibkr-gateway
# 4. Re-run tests
./test_bridge_health.sh
```

## Common Scenarios

### Scenario A: Port 4001 vs 5000 Mismatch

**Problem:** Bridge on port 4001, launcher posting to 5000

**Solution:**
1. Open `QUICK_FIX_GUIDE.md`
2. Apply Fix 1 (Update Launcher Port) or Fix 6 (Auto-fallback)
3. Restart and re-test

**Validation:**
```bash
./test_bridge_health.sh
# Should show: ✓ Webhook POST (4001): OK
```

### Scenario B: No Logging, Can't Debug

**Problem:** Launcher sends webhook but we can't tell if it works

**Solution:**
1. Open `QUICK_FIX_GUIDE.md`
2. Apply Fix 2 (Add Logging)
3. Restart and check logs

**Validation:**
```bash
docker exec ibkr-gateway cat /app/ibc/logs/notifications.log
# Should show detailed POST attempts and responses
```

### Scenario C: Bridge OK, No Mobile Notification

**Problem:** Webhook succeeds but push doesn't arrive

**Solution:** Proceed to P1
1. Check bridge logs for FCM/APNs activity
2. Verify FCM credentials exist and are valid
3. Test mobile app registration
4. Check for errors in notification sending code

See `README.md` "Scenario 3" for detailed P1 actions.

### Scenario D: Launcher Not Detecting 2FA

**Problem:** 2FA happens but launcher never sends webhook

**Solution:**
1. Apply Fix 3 (Monitor last_2fa.json)
2. Apply Fix 4 (Expand patterns)
3. Apply Fix 2 (Add logging to see detection)

**Validation:**
```bash
# Trigger 2FA and check detection
docker exec ibkr-gateway tail -f /app/ibc/logs/notifications.log
# Should show: "[timestamp] 2FA detected via marker file" or log pattern
```

## Decision Tree

```
Start P0 Tests
     |
     ├─> Bridge not responding at all?
     |   └─> YES: Fix bridge startup → Re-test
     |
     ├─> Bridge responds but wrong port?
     |   └─> YES: Apply Fix 1 or Fix 6 → Re-test
     |
     ├─> Bridge responds, POST succeeds?
     |   └─> YES: Check if mobile notification arrived
     |       ├─> YES: ✓ System working!
     |       └─> NO: Proceed to P1
     |           ├─> Check bridge logs for FCM/APNs
     |           ├─> Verify credentials
     |           └─> Test mobile registration
     |
     └─> Launcher not sending webhooks?
         └─> YES: Apply Fix 3 + Fix 4 → Re-test
```

## Integration with UML Analysis

This P0 verification complements the UML analysis:

- **UML shows:** System design (what should happen)
- **P0 tests verify:** Runtime behavior (what actually happens)

Use P0 results to validate/update the UML:
1. Run P0 tests
2. Identify working vs broken components
3. Update `docs/analysis/Headless_2FA_Pipeline.puml` to reflect actual state
4. Compare with backup UML to see what changed

## Files and Structure

```
tests/p0_bridge_verification/
├── test_bridge_health.sh          # Docker container test
├── test_webhook_standalone.sh     # Standalone/remote test
├── README.md                      # Complete guide
├── QUICK_FIX_GUIDE.md            # Code patches
├── TEST_RESULTS_TEMPLATE.md      # Results documentation
├── INDEX.md                       # This file
└── [generated logs]               # Test output logs
```

## Exit Codes

Scripts return meaningful exit codes:

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |

Use in automation:
```bash
./test_bridge_health.sh && echo "Bridge OK" || echo "Bridge FAILED"
```

## Logging

All output is logged to timestamped files:
- Complete curl verbose output
- HTTP response codes and headers
- Test pass/fail results
- Recommendations

Review logs for detailed debugging:
```bash
cat bridge_health_test_*.log
```

## Next Steps After P0

1. **If bridge is not responding:**
   - Fix bridge startup
   - Check container logs
   - Verify network connectivity
   - Re-run P0

2. **If port mismatch found:**
   - Apply Quick Fix 1 or 6
   - Restart services
   - Re-run P0 to verify

3. **If bridge OK but no mobile notification:**
   - Proceed to P1:
     - Check FCM/APNs credentials
     - Review bridge logs
     - Test mobile app
   - Meanwhile, apply launcher improvements (Fix 2, 3, 4)

4. **If everything works:**
   - Document successful configuration
   - Consider applying Fix 2 anyway (better logging)
   - Consider applying Fix 3 (more robust detection)

## Support and Troubleshooting

If tests don't provide clear guidance:

1. Review `README.md` for detailed scenario guides
2. Check `QUICK_FIX_GUIDE.md` for code examples
3. Use `TEST_RESULTS_TEMPLATE.md` to document findings
4. Collect:
   - Test log files
   - Bridge startup logs
   - Container network info
   - Port mappings

## License

Same as parent IBC project (see LICENSE.txt in repository root).

## Version

Version 1.0 - October 2025
Created for P0 Bridge Health Verification as part of 2FA notification debugging.
