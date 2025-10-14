#!/bin/bash

#=============================================================================+
#                                                                             +
#   This command file starts the Interactive Brokers' Gateway in headless    +
#   mode for Docker containers.                                               +
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

# Enforce TrustedIPs to survive IBC rewrites
if [[ -x /app/ibkr/fix_trusted_ips.sh ]]; then
    /app/ibkr/fix_trusted_ips.sh
else
    # Inline fix if script not found
    sed -i 's|TrustedIPs=.*|TrustedIPs=172.20.0.0/16|' "${TWS_SETTINGS_PATH}/jts.ini"
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
