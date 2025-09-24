#!/bin/bash

# IBC System Diagnostics Script
# Performs comprehensive system health checks for IBC environment

# Colors for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Global flag to track failures
HAS_FAILURES=false

# Helper functions for consistent output
ok() {
    echo -e "[${GREEN}OK${NC}] $1"
}

fail() {
    echo -e "[${RED}FAIL${NC}] $1"
    HAS_FAILURES=true
}

warn() {
    echo -e "[${YELLOW}WARN${NC}] $1"
}

# Network stability diagnostics function
check_network_stability() {
    echo "=== Network Stability ==="
    
    local has_issues=false
    
    # Check Docker backbone network exists
    if docker network inspect backbone >/dev/null 2>&1; then
        ok "Docker network 'backbone' exists"
    else
        fail "Rete Docker backbone NON trovata"
        has_issues=true
    fi
    
    # Check active ethernet/vlan connections using nmcli
    if command -v nmcli >/dev/null 2>&1; then
        local active_connections=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | awk -F: '$2 ~ /ethernet|vlan/ { count++; names[count] = $1 } END { 
            if (count > 1) {
                printf "MULTIPLE:"
                for (i=1; i<=count; i++) printf " %s", names[i]
            } else if (count == 1) {
                print "SINGLE"
            } else {
                print "NONE"
            }
        }')
        
        case "$active_connections" in
            "SINGLE")
                ok "Network stability: una connessione ethernet/vlan attiva"
                ;;
            "MULTIPLE:"*)
                local connection_list=$(echo "$active_connections" | cut -d: -f2-)
                fail "Network stability: più di una connessione ethernet/vlan attiva:$connection_list"
                has_issues=true
                ;;
            "NONE")
                fail "Network stability: nessuna connessione ethernet/vlan attiva"
                has_issues=true
                ;;
            *)
                warn "Network stability: impossibile determinare stato connessioni"
                has_issues=true
                ;;
        esac
    else
        warn "nmcli non disponibile - impossibile verificare connessioni di rete"
    fi
    
    # Test external connectivity
    for url in "https://api.github.com" "https://copilot-proxy.githubusercontent.com"; do
        if command -v curl >/dev/null 2>&1; then
            local result=$(curl -I -s -w "%{http_code};%{time_total}" "$url" --max-time 10 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$result" ]; then
                local status_code=$(echo "$result" | tail -1 | cut -d';' -f1)
                local time_total=$(echo "$result" | tail -1 | cut -d';' -f2)
                
                local service_name
                case "$url" in
                    *"api.github.com"*) service_name="GitHub" ;;
                    *"copilot-proxy"*) service_name="Copilot" ;;
                    *) service_name=$(echo "$url" | sed 's|https://||' | cut -d'/' -f1) ;;
                esac
                
                if [ "$status_code" = "200" ]; then
                    ok "Connettività esterna: $service_name ${time_total}s ($status_code)"
                else
                    fail "Connettività esterna: $service_name $status_code"
                    has_issues=true
                fi
            else
                fail "Connettività esterna: $(echo "$url" | sed 's|https://||' | cut -d'/' -f1) - connessione fallita"
                has_issues=true
            fi
        else
            warn "curl non disponibile - impossibile testare connettività esterna"
        fi
    done
    
    # Suggest repair scripts if issues detected
    if [ "$has_issues" = true ]; then
        echo
        echo "Suggerimento: se persistono anomalie eseguire:"
        echo "  - ~/fix_net_stable.sh    # script di riparazione rete locale"
        echo "  - ~/docker_backbone_setup.sh    # ricrea/configura la rete Docker 'backbone'"
    fi
    
    echo
}

# Container health check function
check_container_health() {
    echo "=== Container Health ==="
    
    # Common containers to check
    local containers=("ibkr-gateway" "multiagent_trading_engine" "ai-dashboard-backend" "ai-dashboard-frontend")
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.State}}" | grep -q "$container"; then
            local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
            local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health-check{{end}}' "$container" 2>/dev/null)
            
            if [ "$status" = "running" ] && ([ "$health" = "healthy" ] || [ "$health" = "no-health-check" ]); then
                ok "Container $container running/healthy"
            else
                fail "Container $container NOT healthy/running (status: $status, health: $health)"
            fi
        else
            fail "Container $container not found"
        fi
    done
    
    echo
}

# API connectivity check function
check_api_connectivity() {
    echo "=== API Connectivity ==="
    
    # Check backend to gateway connectivity
    if docker exec ai-dashboard-backend sh -c "timeout 5 nc -z ibkr-gateway 5557" 2>/dev/null; then
        ok "ai-dashboard-backend: connesso a tcp://ibkr-gateway:5557 ma nessun payload ricevuto ancora"
    else
        fail "ai-dashboard-backend: impossibile connettersi a ibkr-gateway:5557"
    fi
    
    # Check if market data publisher is active
    if docker exec ibkr-gateway sh -c "ps aux | grep -q 'market_data_publisher.py' && ls /tmp/*market_data* 2>/dev/null | head -1" >/dev/null 2>&1; then
        ok "ibkr-gateway: market_data_publisher.py attivo e log di pubblicazione trovati"
    else
        fail "ibkr-gateway: market_data_publisher.py non attivo o log mancanti"
    fi
    
    # Test market data API
    if command -v curl >/dev/null 2>&1; then
        local api_response=$(curl -s "http://localhost:8000/api/market-data/status" --max-time 5 2>/dev/null)
        if echo "$api_response" | grep -q '"stream_status": "live"'; then
            ok "API market data: stream_status live"
        else
            fail "API market data: stream_status NON trovato o API non raggiungibile"
        fi
    fi
    
    # Test ZMQ feed
    if command -v timeout >/dev/null 2>&1; then
        if timeout 5 docker exec ai-dashboard-backend python3 -c "
import zmq
import json
context = zmq.Context()
socket = context.socket(zmq.SUB)
socket.connect('tcp://ibkr-gateway:5557')
socket.setsockopt(zmq.SUBSCRIBE, b'')
socket.setsockopt(zmq.RCVTIMEO, 5000)
try:
    message = socket.recv_string()
    print('Message received')
except:
    print('No message')
" 2>/dev/null | grep -q "Message received"; then
            ok "Feed ZMQ market data: messaggi ricevuti"
        else
            fail "Feed ZMQ market data: nessun messaggio ricevuto in 5s"
        fi
    fi
    
    echo
}

# Main diagnostic function
run_diagnostics() {
    echo "IBC System Diagnostics"
    echo "======================"
    echo
    
    # Reset failure flag
    HAS_FAILURES=false
    
    # Run all diagnostic checks
    check_container_health
    check_api_connectivity  
    check_network_stability
    
    # Final summary based on global flag
    if [ "$HAS_FAILURES" = true ]; then
        echo "ATTENZIONE: Alcuni controlli NON sono passati"
    else
        echo "Tutti i controlli sono passati con successo"
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_diagnostics
fi