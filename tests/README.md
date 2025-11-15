# IBC Tests

This directory contains test scripts and utilities for the IBC (Interactive Brokers Controller) project.

## P0 Bridge Health Verification

The `p0_bridge_verification/` directory contains comprehensive testing tools for diagnosing IBKR Gateway 2FA notification issues.

### What It Does

Tests the health and functionality of:
- Bridge server endpoints (health, status, gateway status)
- Webhook POST to `/webhook/2fa` 
- Port availability (5000 vs 4001)
- 2FA notification delivery

### Quick Start

```bash
cd p0_bridge_verification
./START_HERE.sh
```

Or jump right in:

```bash
# For Docker environments
cd p0_bridge_verification
./test_bridge_health.sh

# For standalone/remote testing
cd p0_bridge_verification
./test_webhook_standalone.sh localhost 5000
```

### Documentation

Full documentation is available in the `p0_bridge_verification/` directory:

- **START_HERE.sh** - Quick start helper script
- **INDEX.md** - Master overview and quick reference
- **README.md** - Complete usage guide with troubleshooting
- **QUICK_FIX_GUIDE.md** - Ready-to-use code patches for common issues
- **EXAMPLE_OUTPUT.md** - Example test outputs to compare against
- **TEST_RESULTS_TEMPLATE.md** - Template for documenting results

### What's Included

#### Test Scripts
- `test_bridge_health.sh` - Comprehensive Docker container testing
- `test_webhook_standalone.sh` - Direct HTTP testing (no Docker required)

#### Common Fixes
The Quick Fix Guide includes patches for:
1. Port alignment (5000 vs 4001)
2. Enhanced logging in send_notification()
3. last_2fa.json file monitoring
4. Expanded 2FA detection patterns
5. Bridge port configuration
6. Auto-fallback with dual-port support

### Use Cases

**Scenario 1: 2FA notifications not arriving**
1. Run bridge health test
2. Identify if bridge is reachable
3. Apply appropriate fix from Quick Fix Guide
4. Re-test to verify

**Scenario 2: Port confusion (4001 vs 5000)**
1. Tests show which port bridge is on
2. Apply port alignment fix
3. Re-test to verify

**Scenario 3: Need better debugging**
1. Apply logging enhancement
2. Monitor notification logs
3. Identify failure points

### Test Output

Each test generates:
- Colored console output with pass/fail indicators
- Detailed recommendations based on results
- Timestamped log files with complete curl output
- Action items for next steps

### Integration

These tests complement the UML analysis:
- UML shows system design (what should happen)
- P0 tests verify runtime behavior (what actually happens)
- Together they help identify where the system diverges from design

### Requirements

- Bash shell
- curl (for HTTP testing)
- Docker (only for test_bridge_health.sh)
- jq (optional, for JSON parsing in fixes)

### Exit Codes

Scripts return meaningful exit codes:
- `0` - All tests passed
- `1` - One or more tests failed

Use in automation:
```bash
./test_bridge_health.sh && echo "Bridge OK" || echo "Bridge needs attention"
```

### Support

If tests don't provide clear guidance:
1. Review the documentation in `p0_bridge_verification/`
2. Check EXAMPLE_OUTPUT.md to compare your results
3. Use TEST_RESULTS_TEMPLATE.md to document findings
4. Consult QUICK_FIX_GUIDE.md for specific code patches

### Contributing

To add new tests:
1. Create new script in appropriate subdirectory
2. Follow existing patterns (colored output, logging, recommendations)
3. Add documentation
4. Add examples to EXAMPLE_OUTPUT.md

## Future Tests

This directory will expand to include:
- Unit tests for IBC Java components
- Integration tests for launcher scripts
- End-to-end 2FA flow tests
- Performance tests for high-frequency scenarios

## License

Same as parent IBC project (see LICENSE.txt in repository root).
