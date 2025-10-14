#!/bin/bash

#=============================================================================+
#                                                                             +
#   This command file starts the Interactive Brokers' Gateway in headless    +
#   mode for Docker containers.                                               +
#                                                                             +
#   Environment variables:                                                   +
#     WATCHDOG_ENABLED    - Enable continuous TrustedIPs watchdog (default: false) +
#     TRUSTED_CIDRS       - Comma-separated list of trusted IPs/CIDRs        +
#                           (default: 172.20.0.0/16)                          +
#                                                                             +
#=============================================================================+

TWS_MAJOR_VRSN=${TWS_MAJOR_VRSN:-1030}
IBC_INI=${IBC_INI:-/app/ibc/config.ini}
TRADING_MODE=${TRADING_MODE:-live}
TWOFA_TIMEOUT_ACTION=${TWOFA_TIMEOUT_ACTION:-exit}
IBC_PATH=${IBC_PATH:-/app/ibc}
TWS_PATH=/opt/ibgateway
TWS_SETTINGS_PATH=${TWS_SETTINGS_PATH:-/opt/ibgateway}
LOG_PATH=${LOG_PATH:-/app/ibc/logs}
TWSUSERID=${TWSUSERID:-}
TWSPASSWORD=${TWSPASSWORD:-}
FIXUSERID=${FIXUSERID:-}
FIXPASSWORD=${FIXPASSWORD:-}
JAVA_PATH=${JAVA_PATH:-}
HIDE=
WATCHDOG_ENABLED=${WATCHDOG_ENABLED:-false}
TRUSTED_CIDRS=${TRUSTED_CIDRS:-172.20.0.0/16}

# Ensure jts.ini exists
mkdir -p "${TWS_SETTINGS_PATH}"
if [[ ! -f "${TWS_SETTINGS_PATH}/jts.ini" ]]; then
    echo "[Logon]" > "${TWS_SETTINGS_PATH}/jts.ini"
    echo "Locale=en" >> "${TWS_SETTINGS_PATH}/jts.ini"
    echo "displayedproxymsg=1" >> "${TWS_SETTINGS_PATH}/jts.ini"
    echo "UseSSL=true" >> "${TWS_SETTINGS_PATH}/jts.ini"
    echo "[IBGateway]" >> "${TWS_SETTINGS_PATH}/jts.ini"
    echo "ApiOnly=true" >> "${TWS_SETTINGS_PATH}/jts.ini"
fi

# Enforce TrustedIPs
if [[ -x /app/ibkr/fix_trusted_ips.sh ]]; then
    if [[ "$WATCHDOG_ENABLED" == "true" ]]; then
        # Start watchdog in background
        echo "Starting TrustedIPs watchdog with target: ${TRUSTED_CIDRS}"
        TRUSTED_CIDRS="${TRUSTED_CIDRS}" nohup /app/ibkr/fix_trusted_ips.sh --watch >/dev/null 2>&1 &
        WATCHDOG_PID=$!
        echo "Watchdog started with PID: ${WATCHDOG_PID}"
    else
        # Single execution
        TRUSTED_CIDRS="${TRUSTED_CIDRS}" /app/ibkr/fix_trusted_ips.sh
    fi
else
    # Inline fix if script not found
    if [[ -n "$TRUSTED_CIDRS" ]]; then
        sed -i "s|TrustedIPs=.*|TrustedIPs=${TRUSTED_CIDRS}|" "${TWS_SETTINGS_PATH}/jts.ini"
    else
        sed -i 's|TrustedIPs=.*|TrustedIPs=172.20.0.0/16|' "${TWS_SETTINGS_PATH}/jts.ini"
    fi
fi

# Export environment variables
export TWS_MAJOR_VRSN
export IBC_INI
export TRADING_MODE
export TWOFA_TIMEOUT_ACTION
export IBC_PATH
export TWS_PATH
export TWS_SETTINGS_PATH
export LOG_PATH
export TWSUSERID
export TWSPASSWORD
export FIXUSERID
export FIXPASSWORD
export JAVA_PATH
export APP=GATEWAY

# Start IBC
exec "${IBC_PATH}/scripts/ibcstart.sh"
