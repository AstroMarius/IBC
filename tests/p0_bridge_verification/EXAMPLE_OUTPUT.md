# Example Test Output

This file shows example output from the P0 test scripts to help you understand what to expect.

---

## Example 1: Successful Test (Bridge on Port 5000)

```
=====================================================================
P0 Bridge Health Verification - Started at Wed Oct 11 09:55:00 UTC 2025
Container: ibkr-gateway
Log file: bridge_health_test_2025-10-11_09-55-00.log
=====================================================================

=== Checking listening ports in container ===
Checking for processes listening on ports 4001 and 5000:
tcp    0    0 0.0.0.0:5000    0.0.0.0:*    LISTEN    1234/python3
tcp    0    0 0.0.0.0:4001    0.0.0.0:*    LISTEN    5678/java

=== Testing Bridge Health Endpoint (5000) ===
Executing: curl -v http://localhost:5000/health
* Connected to localhost (127.0.0.1) port 5000
> GET /health HTTP/1.1
> Host: localhost:5000
> 
< HTTP/1.1 200 OK
< Content-Type: application/json
< Content-Length: 27
< 
{"status":"healthy"}
✓ Success: Bridge Health Endpoint (5000) responded

=== Testing POST to /webhook/2fa (port 5000) ===
Payload: {"message":"test 2fa from P0 verification","source":"test_script","timestamp":"2025-10-11T09:55:05+00:00"}
Executing: curl -X POST -H 'Content-Type: application/json' -d '...' http://localhost:5000/webhook/2fa
* Connected to localhost (127.0.0.1) port 5000
> POST /webhook/2fa HTTP/1.1
> Host: localhost:5000
> Content-Type: application/json
> 
< HTTP/1.1 202 Accepted
< Content-Type: application/json
< 
{"status":"accepted","message":"2fa notification queued"}
✓ Success: POST to webhook succeeded

=====================================================================
Test Summary:
=====================================================================
✓ Health endpoint (5000): OK
✗ Health endpoint (4001): FAILED
✓ Status endpoint (5000): OK
✗ Status endpoint (4001): FAILED
✓ Gateway status endpoint (5000): OK
✓ Webhook POST (5000): OK
✗ Webhook POST (4001): FAILED

=====================================================================
Recommendations based on test results:
=====================================================================
✓ Bridge is responding on port 5000
  → Ensure launcher scripts POST to localhost:5000/webhook/2fa
  → Next: Check if notifications reach mobile (P1)

Full log saved to: bridge_health_test_2025-10-11_09-55-00.log
=====================================================================
```

**Interpretation:** Bridge is working correctly on port 5000. If notifications reach mobile, system is working. If not, proceed to P1 to check FCM/APNs.

---

## Example 2: Port Mismatch (Bridge on 4001, Expected on 5000)

```
=====================================================================
P0 Bridge Health Verification - Started at Wed Oct 11 10:00:00 UTC 2025
Container: ibkr-gateway
Log file: bridge_health_test_2025-10-11_10-00-00.log
=====================================================================

=== Checking listening ports in container ===
tcp    0    0 0.0.0.0:4001    0.0.0.0:*    LISTEN    1234/python3

=== Testing Bridge Health Endpoint (5000) ===
* Failed to connect to localhost port 5000: Connection refused
✗ Failed: Bridge Health Endpoint (5000) did not respond (exit code: 7)

=== Testing Bridge Health Endpoint (4001) ===
* Connected to localhost (127.0.0.1) port 4001
< HTTP/1.1 200 OK
{"status":"healthy"}
✓ Success: Bridge Health Endpoint (4001) responded

=== Testing POST to /webhook/2fa (port 5000) ===
* Failed to connect to localhost port 5000: Connection refused
✗ Failed: POST to webhook failed (exit code: 7)

=== Testing POST to /webhook/2fa (port 4001) ===
* Connected to localhost (127.0.0.1) port 4001
< HTTP/1.1 202 Accepted
{"status":"accepted"}
✓ Success: POST to webhook succeeded

=====================================================================
Test Summary:
=====================================================================
✗ Health endpoint (5000): FAILED
✓ Health endpoint (4001): OK
✗ Status endpoint (5000): FAILED
✓ Status endpoint (4001): OK
✗ Gateway status endpoint (5000): FAILED
✗ Webhook POST (5000): FAILED
✓ Webhook POST (4001): OK

=====================================================================
Recommendations based on test results:
=====================================================================
⚠ Bridge is responding on port 4001, NOT 5000
  → Update launcher scripts to POST to localhost:4001/webhook/2fa
  → OR reconfigure bridge to listen on port 5000

Full log saved to: bridge_health_test_2025-10-11_10-00-00.log
=====================================================================
```

**Interpretation:** Bridge is listening on port 4001, but launcher is likely configured for 5000. Apply Fix 1 from Quick Fix Guide.

---

## Example 3: Bridge Not Running

```
=====================================================================
P0 Bridge Health Verification - Started at Wed Oct 11 10:05:00 UTC 2025
Container: ibkr-gateway
Log file: bridge_health_test_2025-10-11_10-05-00.log
=====================================================================

=== Checking listening ports in container ===
tcp    0    0 0.0.0.0:4001    0.0.0.0:*    LISTEN    5678/java

=== Testing Bridge Health Endpoint (5000) ===
* Failed to connect to localhost port 5000: Connection refused
✗ Failed: Bridge Health Endpoint (5000) did not respond (exit code: 7)

=== Testing Bridge Health Endpoint (4001) ===
* Failed to connect to localhost port 4001: Connection refused
✗ Failed: Bridge Health Endpoint (4001) did not respond (exit code: 7)

=== Testing POST to /webhook/2fa (port 5000) ===
* Failed to connect to localhost port 5000: Connection refused
✗ Failed: POST to webhook failed (exit code: 7)

=== Testing POST to /webhook/2fa (port 4001) ===
* Failed to connect to localhost port 4001: Connection refused
✗ Failed: POST to webhook failed (exit code: 7)

=====================================================================
Test Summary:
=====================================================================
✗ Health endpoint (5000): FAILED
✗ Health endpoint (4001): FAILED
✗ Status endpoint (5000): FAILED
✗ Status endpoint (4001): FAILED
✗ Gateway status endpoint (5000): FAILED
✗ Webhook POST (5000): FAILED
✗ Webhook POST (4001): FAILED

=====================================================================
Recommendations based on test results:
=====================================================================
⚠ ISSUE: Bridge not responding on either port
  → Check if bridge server is running in container
  → Verify bridge server startup in container logs: docker logs ibkr-gateway
  → Check for port binding issues

Full log saved to: bridge_health_test_2025-10-11_10-05-00.log
=====================================================================
```

**Interpretation:** Bridge server is not running. Check container startup logs and verify bridge server process.

---

## Example 4: Standalone Test (Successful)

```
=====================================================================
Standalone Bridge Webhook Test - Started at Wed Oct 11 10:10:00 UTC 2025
Target: localhost:5000
Log file: webhook_test_2025-10-11_10-10-00.log
=====================================================================

=== Testing Health Endpoint ===
URL: http://localhost:5000/health
* Connected to localhost (127.0.0.1) port 5000
< HTTP/1.1 200 OK
{"status":"healthy"}

HTTP_STATUS:200
✓ Health endpoint OK (HTTP 200)

=== Testing Status Endpoint ===
URL: http://localhost:5000/status
* Connected to localhost (127.0.0.1) port 5000
< HTTP/1.1 200 OK
{"gateway":"running","session":"active"}

HTTP_STATUS:200
✓ Status endpoint OK (HTTP 200)

=== Testing POST to /webhook/2fa ===
URL: http://localhost:5000/webhook/2fa
Payload: {"message":"P0 test 2FA notification","source":"p0_test_script","timestamp":"2025-10-11T10:10:05+00:00"}
* Connected to localhost (127.0.0.1) port 5000
< HTTP/1.1 202 Accepted
{"status":"accepted","forwarded_to":"mobile"}

HTTP_STATUS:202
✓ Webhook POST succeeded (HTTP 202)
  → Check bridge logs to verify notification was processed
  → Check mobile device to see if push notification arrived

=====================================================================
Test Summary for localhost:5000:
=====================================================================
✓ Health: OK
✓ Status: OK
✓ Webhook: OK

=====================================================================
Next Steps:
=====================================================================
✓ Bridge webhook is responding correctly

P1 Actions (if push notification did NOT arrive on mobile):
  1. Check bridge logs for FCM/APNs send status
  2. Verify FCM/APNs credentials are configured in bridge
  3. Check mobile app registration status
  4. Verify notification permissions on mobile device

Launcher Improvements (parallel with P1):
  1. Add response code logging in send_notification() function
  2. Monitor last_2fa.json file as additional trigger
  3. Expand 2FA detection patterns in monitor_logs()

Full log saved to: webhook_test_2025-10-11_10-10-00.log
=====================================================================
```

**Interpretation:** Bridge is fully functional. If mobile notification doesn't arrive, the issue is in FCM/APNs configuration (P1).

---

## Log File Contents

Full log files include:
- Complete curl verbose output with connection details
- HTTP headers (request and response)
- Response bodies
- Timestamps
- Exit codes
- All test results

Example snippet from log file:
```
[2025-10-11 10:10:00] Starting test: Health Endpoint (5000)
* Trying 127.0.0.1:5000...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 5000 (#0)
> GET /health HTTP/1.1
> Host: localhost:5000
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: Werkzeug/2.0.1 Python/3.9.7
< Date: Wed, 11 Oct 2025 10:10:00 GMT
< Content-Type: application/json
< Content-Length: 27
< Connection: close
< 
{"status":"healthy"}
* Closing connection 0
[2025-10-11 10:10:00] Test result: PASS
```

---

## Using the Examples

1. **Compare your output** to these examples to identify which scenario matches
2. **Follow the recommendations** in your test output
3. **Refer to the Quick Fix Guide** for specific code patches
4. **Re-run tests** after applying fixes to verify

---

## Key Indicators

| Indicator | Meaning |
|-----------|---------|
| `Connection refused` | Service not listening on that port |
| `HTTP/1.1 200 OK` | Endpoint working correctly |
| `HTTP/1.1 202 Accepted` | Webhook accepted for processing |
| `HTTP/1.1 404 Not Found` | Endpoint doesn't exist (wrong path) |
| `HTTP/1.1 500 Internal Server Error` | Bridge error (check logs) |
| `curl exit code: 7` | Connection failed |
| `curl exit code: 0` | Request succeeded |

---

## Next Steps Based on Output

Match your output to the closest example above, then:

1. **Example 1** → Check if mobile receives notification. If yes: done! If no: P1
2. **Example 2** → Apply Fix 1 or Fix 6 from Quick Fix Guide
3. **Example 3** → Fix bridge startup, check container logs
4. **Example 4** → If mobile notification fails, proceed to P1

See `README.md` for detailed next steps for each scenario.
