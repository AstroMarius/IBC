#!/bin/bash

#=============================================================================+
#                                                                             +
#   This script enforces the TrustedIPs setting in jts.ini to ensure         +
#   the Docker subnet can connect to the IB Gateway API.                     +
#                                                                             +
#   Usage:                                                                    +
#     ./fix_trusted_ips.sh           # Single execution mode                 +
#     ./fix_trusted_ips.sh --watch   # Continuous watchdog mode              +
#                                                                             +
#   Environment variables:                                                   +
#     TWS_SETTINGS_PATH   - Path to IBGateway settings (default: /opt/ibgateway) +
#     TRUSTED_CIDRS       - Comma-separated list of trusted IPs/CIDRs        +
#                           (default: 172.20.0.0/16)                          +
#     LOG_FILE            - Path to log file (watchdog mode only)            +
#                           (default: /app/logs/trusted_ips_fix.log)         +
#                                                                             +
#=============================================================================+

JTS_INI="${TWS_SETTINGS_PATH:-/opt/ibgateway}/jts.ini"
SECTION="${SECTION:-IBGateway}"
TRUSTED_IPS="${TRUSTED_CIDRS:-172.20.0.0/16}"
LOG_FILE="${LOG_FILE:-/app/logs/trusted_ips_fix.log}"
WATCH_MODE=false
WATCH_INTERVAL="${WATCH_INTERVAL:-2}"

# Parse command line arguments
if [[ "$1" == "--watch" ]]; then
    WATCH_MODE=true
fi

# Function to log messages
log_message() {
    local message="$1"
    if [[ "$WATCH_MODE" == true ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        echo "$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S) [fix] $message" >> "$LOG_FILE"
    fi
    echo "$message"
}

# Function to set TrustedIPs
set_trusted_ips() {
    if [[ ! -f "$JTS_INI" ]]; then
        log_message "Error: jts.ini not found at $JTS_INI"
        return 1
    fi

    # Check if TrustedIPs exists in the file
    if grep -q "^TrustedIPs=" "$JTS_INI"; then
        # Get current value in [IBGateway] section
        local current_value=""
        current_value=$(awk -v sec="$SECTION" '
            BEGIN{in_section=0}
            /^\[/{in_section=0}
            $0=="["sec"]"{in_section=1;next}
            in_section && /^TrustedIPs=/{print substr($0,13); exit}
        ' "$JTS_INI" 2>/dev/null | tr -d '\r')
        
        # If not found in section, try global search
        if [[ -z "$current_value" ]]; then
            current_value=$(grep '^TrustedIPs=' "$JTS_INI" | head -1 | cut -d= -f2- | tr -d '\r')
        fi
        
        if [[ "$current_value" != "$TRUSTED_IPS" ]]; then
            log_message "Rewrite detected: $current_value -> $TRUSTED_IPS"
            # Replace TrustedIPs within [IBGateway] section
            sed -i "/^\[$SECTION\]/,/^\[/ s|^TrustedIPs=.*|TrustedIPs=${TRUSTED_IPS}|" "$JTS_INI"
        fi
    else
        log_message "Key missing, adding TrustedIPs"
        # Add TrustedIPs to [IBGateway] section if not present
        if grep -q "^\[$SECTION\]" "$JTS_INI"; then
            sed -i "/^\[$SECTION\]/a TrustedIPs=$TRUSTED_IPS" "$JTS_INI"
        else
            # Add [IBGateway] section if missing
            echo "" >> "$JTS_INI"
            echo "[$SECTION]" >> "$JTS_INI"
            echo "TrustedIPs=$TRUSTED_IPS" >> "$JTS_INI"
        fi
    fi
}

# Main execution
if [[ "$WATCH_MODE" == true ]]; then
    log_message "Starting watchdog mode, target=${TRUSTED_IPS}, interval=${WATCH_INTERVAL}s"
    
    # Initial fix
    set_trusted_ips || log_message "Initial fix failed"
    
    # Continuous monitoring loop
    while :; do
        set_trusted_ips || log_message "Fix attempt failed"
        sleep "$WATCH_INTERVAL"
    done
else
    # Single execution mode
    log_message "Enforcing TrustedIPs=$TRUSTED_IPS in $JTS_INI"
    set_trusted_ips
    if [[ $? -eq 0 ]]; then
        log_message "TrustedIPs setting enforced successfully"
    else
        log_message "Failed to enforce TrustedIPs setting"
        exit 1
    fi
fi
