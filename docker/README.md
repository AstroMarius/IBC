# Docker Support for IBC

This directory contains resources for running IBKR Gateway in headless mode within Docker containers.

## Contents

- **`IBKR_GATEWAY_HEADLESS_OPERATIONS.md`** - Comprehensive operational guide for running IBKR Gateway in headless mode
- **`docker-compose.example.yml`** - Example Docker Compose configuration
- **`.env.example`** - Example environment variables template
- **`common/ibkr_gateway/ibkr/`** - Scripts for gateway operation:
  - `gateway_headless.sh` - Main entrypoint script for headless gateway
  - `fix_trusted_ips.sh` - Script to enforce TrustedIPs settings

## Quick Start

1. **Copy example files:**
   ```bash
   cp docker-compose.example.yml docker-compose.yml
   cp .env.example .env
   ```

2. **Edit `.env` file** with your IBKR credentials and preferences:
   ```bash
   vim .env
   ```

3. **Start the gateway:**
   ```bash
   docker-compose up -d
   ```

4. **Monitor logs:**
   ```bash
   docker-compose logs -f gateway-headless
   ```

5. **Approve 2FA** when prompted (watch logs for notification)

6. **Check health status:**
   ```bash
   docker-compose ps
   ```

## Key Features

### TrustedIPs Management

The included scripts provide two modes for managing TrustedIPs:

1. **Single Execution Mode** (default): Sets TrustedIPs once during startup
2. **Watchdog Mode** (`WATCHDOG_ENABLED=true`): Continuously monitors and corrects TrustedIPs if IBC overwrites them

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `IB_USER` | IBKR username | *(required)* |
| `IB_PASSWORD` | IBKR password | *(required)* |
| `TRADING_MODE` | Trading mode: `paper` or `live` | `live` |
| `TRUSTED_CIDRS` | Comma-separated list of trusted IPs/CIDRs | `172.20.0.0/16` |
| `WATCHDOG_ENABLED` | Enable continuous TrustedIPs watchdog | `false` |
| `TWOFA_TIMEOUT_ACTION` | Action on 2FA timeout: `exit` or `restart` | `exit` |
| `DISPLAY` | X11 display for headless mode | `:1` |
| `TWS_MAJOR_VRSN` | Gateway version | `1030` |

### Healthcheck

The example docker-compose includes a healthcheck that monitors port 4001:
- Checks every 10 seconds
- Allows 120 seconds startup time
- Retries 18 times before marking unhealthy

## Documentation

For complete operational procedures, troubleshooting, and best practices, see:
- **[IBKR_GATEWAY_HEADLESS_OPERATIONS.md](IBKR_GATEWAY_HEADLESS_OPERATIONS.md)**

## Security Best Practices

1. **Never commit credentials** - Use `.env` file (already in `.gitignore`)
2. **Limit TrustedIPs** - Only allow necessary IP ranges
3. **Use secrets management** - Consider Docker secrets or external secret managers
4. **Avoid exposing ports** - Only expose 4001 to host if absolutely necessary
5. **Use restart policies carefully** - `unless-stopped` prevents restart loops

## Troubleshooting

See the comprehensive troubleshooting section in `IBKR_GATEWAY_HEADLESS_OPERATIONS.md`.

Quick diagnostics:
```bash
# Check if gateway process is running
docker exec gateway-headless ps aux | grep -i gateway

# Check if port 4001 is listening
docker exec gateway-headless ss -lnt | grep 4001

# View IBC logs
docker exec gateway-headless tail -f /app/ibc/logs/ibc_output.log

# Check TrustedIPs setting
docker exec gateway-headless cat /opt/ibgateway/jts.ini | grep TrustedIPs

# Check watchdog status (if enabled)
docker exec gateway-headless pgrep -af fix_trusted_ips.sh
```

## Support

For issues related to IBC itself, please refer to the main [IBC documentation](../README.md) and [User Guide](../userguide.md).

For Docker-specific issues, check:
1. Container logs: `docker-compose logs gateway-headless`
2. Container status: `docker-compose ps`
3. Network configuration: `docker network inspect docker_ibnet`

## License

Same as the main IBC project - see [LICENSE.txt](../LICENSE.txt)
