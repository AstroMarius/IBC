#!/bin/bash

#=============================================================================+
#                                                                             +
#   This script enforces the TrustedIPs setting in jts.ini to ensure         +
#   the Docker subnet can connect to the IB Gateway API.                     +
#                                                                             +
#=============================================================================+

JTS_INI="${TWS_SETTINGS_PATH:-/opt/ibgateway}/jts.ini"
TRUSTED_IPS="172.20.0.0/16"

if [[ ! -f "$JTS_INI" ]]; then
    echo "Error: jts.ini not found at $JTS_INI"
    exit 1
fi

echo "Enforcing TrustedIPs=$TRUSTED_IPS in $JTS_INI"

# Use sed to replace TrustedIPs line or add it if missing
if grep -q "^TrustedIPs=" "$JTS_INI"; then
    sed -i "s|^TrustedIPs=.*|TrustedIPs=$TRUSTED_IPS|" "$JTS_INI"
else
    # Add TrustedIPs to [IBGateway] section if not present
    if grep -q "^\[IBGateway\]" "$JTS_INI"; then
        sed -i "/^\[IBGateway\]/a TrustedIPs=$TRUSTED_IPS" "$JTS_INI"
    else
        # Add [IBGateway] section if missing
        echo "" >> "$JTS_INI"
        echo "[IBGateway]" >> "$JTS_INI"
        echo "TrustedIPs=$TRUSTED_IPS" >> "$JTS_INI"
    fi
fi

echo "TrustedIPs setting enforced successfully"
