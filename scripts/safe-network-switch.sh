#!/usr/bin/env bash

# safe-network-switch.sh
# Safely apply network configuration changes with automatic rollback on failure
#
# This script applies a NixOS configuration, tests network connectivity,
# and automatically reverts to the previous generation if networking fails.
# This prevents being locked out of remote systems due to network misconfigurations.

set -euo pipefail

# Configuration
TIMEOUT=${SAFE_NETWORK_TIMEOUT:-60}  # Seconds to wait for user confirmation
TEST_RETRIES=${SAFE_NETWORK_RETRIES:-3}  # Number of test attempts
TEST_INTERVAL=${SAFE_NETWORK_INTERVAL:-2}  # Seconds between test attempts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if running on NixOS
if [[ ! -f /etc/NIXOS ]]; then
    log_error "This script must be run on NixOS"
    exit 1
fi

# Check if running as root (required for nixos-rebuild)
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get the current system generation before making changes
CURRENT_GENERATION=$(readlink /run/current-system)
CURRENT_GEN_NUM=$(basename "$(readlink /nix/var/nix/profiles/system)")

log_info "Current system generation: $CURRENT_GEN_NUM"
log_info "Current system path: $CURRENT_GENERATION"

# Function to get network configuration from current NixOS config
get_network_config() {
    local gateway=""
    local dns=""

    # Try to get gateway from systemd-networkd
    if systemctl is-active --quiet systemd-networkd; then
        gateway=$(ip route show default | grep -oP 'via \K[\d.]+' | head -1 || echo "")
    fi

    # Fallback to /etc/resolv.conf for gateway info
    if [[ -z "$gateway" ]]; then
        gateway=$(ip route show default | awk '/default/ {print $3; exit}')
    fi

    # Get DNS server
    dns=$(grep -m1 "^nameserver" /etc/resolv.conf | awk '{print $2}' || echo "")

    echo "$gateway|$dns"
}

# Function to test network connectivity
test_network() {
    local gateway=$1
    local dns=$2
    local attempt=$3

    log_info "Network test attempt $attempt/$TEST_RETRIES"

    # Test 1: Check if network interfaces are up
    log_info "  Checking network interfaces..."
    if ! ip link show | grep -q "state UP"; then
        log_error "  No network interfaces are UP"
        return 1
    fi
    log_success "  Network interfaces are UP"

    # Test 2: Ping gateway (if we have one)
    if [[ -n "$gateway" ]]; then
        log_info "  Testing gateway connectivity ($gateway)..."
        if ping -c 2 -W 2 "$gateway" &>/dev/null; then
            log_success "  Gateway is reachable"
        else
            log_error "  Cannot reach gateway $gateway"
            return 1
        fi
    else
        log_warning "  No gateway found to test"
    fi

    # Test 3: DNS resolution (if we have a DNS server)
    if [[ -n "$dns" ]]; then
        log_info "  Testing DNS resolution..."
        if ping -c 2 -W 2 "$dns" &>/dev/null; then
            log_success "  DNS server is reachable"
        else
            log_error "  Cannot reach DNS server $dns"
            return 1
        fi
    else
        log_warning "  No DNS server found to test"
    fi

    # Test 4: External connectivity (optional)
    log_info "  Testing external connectivity..."
    if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
        log_success "  External connectivity working"
    else
        log_warning "  External connectivity failed (may be expected)"
    fi

    # Test 5: systemd-networkd status (if using systemd-networkd)
    if systemctl is-active --quiet systemd-networkd; then
        log_info "  Checking systemd-networkd status..."
        if systemctl is-active --quiet systemd-networkd-wait-online.service; then
            log_success "  systemd-networkd-wait-online is active"
        else
            log_warning "  systemd-networkd-wait-online is not active (checking manually)"
            if networkctl status | grep -q "State: routable"; then
                log_success "  Network is routable"
            else
                log_error "  Network is not routable according to networkctl"
                return 1
            fi
        fi
    fi

    return 0
}

# Function to rollback to previous generation
rollback_system() {
    log_warning "Rolling back to generation $CURRENT_GEN_NUM..."

    if /nix/var/nix/profiles/system/bin/switch-to-configuration switch; then
        log_success "Successfully rolled back to generation $CURRENT_GEN_NUM"
        return 0
    else
        log_error "Failed to rollback! System may be in an inconsistent state!"
        log_error "Manual intervention required. Try running:"
        log_error "  nix-env --rollback -p /nix/var/nix/profiles/system"
        log_error "  /nix/var/nix/profiles/system/bin/switch-to-configuration switch"
        return 1
    fi
}

# Function to wait for user confirmation with timeout
wait_for_confirmation() {
    local timeout=$1
    log_warning ""
    log_warning "=============================================="
    log_warning "Network configuration has been applied!"
    log_warning "=============================================="
    log_warning ""
    log_warning "You have ${timeout} seconds to confirm the network is working."
    log_warning "If you don't respond, the system will automatically rollback."
    log_warning ""
    log_info "Press 'y' to keep the new configuration"
    log_info "Press 'n' to rollback immediately"
    log_warning ""

    local count=0
    while [[ $count -lt $timeout ]]; do
        local remaining=$((timeout - count))
        echo -ne "\r${YELLOW}Time remaining: ${remaining}s${NC}  "

        # Check if input is available
        if read -t 1 -n 1 response; then
            echo ""  # New line after input
            case "$response" in
                [Yy])
                    log_success "Configuration confirmed by user"
                    return 0
                    ;;
                [Nn])
                    log_warning "Rollback requested by user"
                    return 1
                    ;;
                *)
                    log_warning "Invalid input. Press 'y' to confirm or 'n' to rollback"
                    ;;
            esac
        fi

        ((count++))
    done

    echo ""  # New line after timeout
    log_warning "Timeout reached with no confirmation"
    return 1
}

# Main script execution
main() {
    log_info "================================================"
    log_info "Safe Network Configuration Switch"
    log_info "================================================"
    log_info ""

    # Get current network configuration
    log_info "Detecting network configuration..."
    IFS='|' read -r GATEWAY DNS <<< "$(get_network_config)"
    log_info "Gateway: ${GATEWAY:-<none detected>}"
    log_info "DNS: ${DNS:-<none detected>}"
    log_info ""

    # Step 1: Test current network (baseline)
    log_info "Testing current network configuration as baseline..."
    if ! test_network "$GATEWAY" "$DNS" 1; then
        log_error "Current network is not working properly!"
        log_error "Fix the current configuration before proceeding."
        exit 1
    fi
    log_success "Baseline network test passed"
    log_info ""

    # Step 2: Apply new configuration
    log_info "Applying new configuration with 'just switch'..."
    log_info ""

    if ! just switch; then
        log_error "Failed to apply configuration with 'just switch'"
        log_error "Configuration was not applied, no rollback needed"
        exit 1
    fi

    log_info ""
    log_success "Configuration applied successfully"

    # Get new generation
    NEW_GENERATION=$(readlink /run/current-system)
    NEW_GEN_NUM=$(basename "$(readlink /nix/var/nix/profiles/system)")
    log_info "New system generation: $NEW_GEN_NUM"

    # Check if generation actually changed
    if [[ "$CURRENT_GENERATION" == "$NEW_GENERATION" ]]; then
        log_warning "System generation did not change (no updates applied)"
        log_success "Nothing to test or rollback"
        exit 0
    fi

    # Wait a moment for network to stabilize
    log_info "Waiting 5 seconds for network to stabilize..."
    sleep 5

    # Step 3: Test new network configuration
    log_info ""
    log_info "Testing new network configuration..."

    local test_passed=false
    for i in $(seq 1 $TEST_RETRIES); do
        if test_network "$GATEWAY" "$DNS" "$i"; then
            test_passed=true
            break
        fi

        if [[ $i -lt $TEST_RETRIES ]]; then
            log_warning "Test failed, waiting ${TEST_INTERVAL}s before retry..."
            sleep "$TEST_INTERVAL"
        fi
    done

    if [[ "$test_passed" == "false" ]]; then
        log_error ""
        log_error "Network tests failed after $TEST_RETRIES attempts!"
        log_error "Automatically rolling back to previous configuration..."
        log_error ""

        if rollback_system; then
            log_success "System rolled back successfully"
            log_info "Please check your network configuration and try again"
            exit 1
        else
            exit 2
        fi
    fi

    log_success ""
    log_success "All network tests passed!"
    log_info ""

    # Step 4: Wait for user confirmation
    if wait_for_confirmation "$TIMEOUT"; then
        log_success ""
        log_success "================================================"
        log_success "Configuration change completed successfully!"
        log_success "================================================"
        log_success ""
        log_success "New generation: $NEW_GEN_NUM"
        log_info "Previous generation $CURRENT_GEN_NUM is still available for rollback"
        log_info "To manually rollback: sudo nixos-rebuild switch --rollback"
        exit 0
    else
        # Timeout or user rejected
        log_warning ""
        log_warning "Rolling back to previous configuration..."
        log_warning ""

        if rollback_system; then
            log_success ""
            log_success "System rolled back successfully to generation $CURRENT_GEN_NUM"
            log_info "Please check your network configuration and try again"
            exit 1
        else
            exit 2
        fi
    fi
}

# Trap Ctrl+C and treat it as a rollback request
trap 'log_warning "Interrupt received, rolling back..."; rollback_system; exit 1' INT TERM

# Run main function
main "$@"
