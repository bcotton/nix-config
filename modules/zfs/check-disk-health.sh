#!/usr/bin/env bash

# ZFS Disk Health Check Script
# Maps drives to ZFS pools and checks for SMART issues
# Usage: ./check-disk-health.sh [--verbose] [--json]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Command line options
VERBOSE=false
JSON_OUTPUT=false
DEBUG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --json|-j)
            JSON_OUTPUT=true
            shift
            ;;
        --debug|-d)
            DEBUG=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--verbose] [--json] [--debug]"
            echo "  --verbose, -v    Show detailed SMART attributes"
            echo "  --json, -j       Output in JSON format"
            echo "  --debug, -d      Show debug information and raw SMART output"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to get pool for a device
get_zfs_pool() {
    local device="$1"
    # Try to find the device in zpool status output
    zpool status | awk -v dev="$(basename "$device")" '
    /pool:/ { pool = $2 }
    /state:/ { state = $2 }
    $1 ~ dev || $1 ~ substr(dev, 1, 20) { 
        print pool ":" state
        found = 1
        exit
    }
    END { if (!found) print "none:unknown" }
    '
}

# Function to get device serial number for better matching
get_device_serial() {
    local device="$1"
    smartctl -i "$device" 2>/dev/null | grep "Serial Number:" | awk '{print $3}' || echo "unknown"
}

# Function to get SMART attributes
get_smart_attributes() {
    local device="$1"
    local temp_file=$(mktemp)
    
    if ! smartctl -A "$device" > "$temp_file" 2>/dev/null; then
        echo "error:error:error:error:error"
        rm -f "$temp_file"
        return
    fi
    
    if [[ "$DEBUG" == "true" ]]; then
        echo "=== DEBUG: SMART data for $device ===" >&2
        grep -E "(Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable|Temperature_Celsius)" "$temp_file" >&2
        echo "=== END DEBUG ===" >&2
    fi
    
    # Use the raw value (column 10) which matches what Prometheus smartctl exporter uses
    local reallocated=$(grep "Reallocated_Sector_Ct" "$temp_file" | awk '{print $10}' || echo "0")
    local pending=$(grep "Current_Pending_Sector" "$temp_file" | awk '{print $10}' || echo "0")
    local uncorrectable=$(grep "Offline_Uncorrectable" "$temp_file" | awk '{print $10}' || echo "0")
    local temperature=$(grep "Temperature_Celsius" "$temp_file" | awk '{print $10}' || echo "0")
    local health=$(smartctl -H "$device" 2>/dev/null | grep "SMART overall-health" | awk '{print $6}' || echo "UNKNOWN")
    
    if [[ "$DEBUG" == "true" ]]; then
        echo "=== DEBUG: Parsed values for $device ===" >&2
        echo "Reallocated: $reallocated, Pending: $pending, Uncorrectable: $uncorrectable, Temp: $temperature, Health: $health" >&2
    fi
    
    echo "${reallocated:-0}:${pending:-0}:${uncorrectable:-0}:${temperature:-0}:${health:-UNKNOWN}"
    rm -f "$temp_file"
}

# Function to determine severity
get_severity() {
    local pending="$1"
    local reallocated="$2"
    local uncorrectable="$3"
    local health="$4"
    
    if [[ "$health" != "PASSED" ]] || [[ "$uncorrectable" -gt 0 ]]; then
        echo "CRITICAL"
    elif [[ "$pending" -gt 5 ]] || [[ "$reallocated" -gt 5 ]]; then
        echo "CRITICAL"
    elif [[ "$pending" -gt 0 ]] || [[ "$reallocated" -gt 0 ]]; then
        echo "WARNING"
    else
        echo "OK"
    fi
}

# Function to get recommended action
get_action() {
    local severity="$1"
    local pending="$2"
    local pool="$3"
    
    case "$severity" in
        "CRITICAL")
            if [[ "$pending" -gt 0 ]]; then
                echo "IMMEDIATE: Run 'zfs scrub $pool' then replace drive"
            else
                echo "IMMEDIATE: Replace drive"
            fi
            ;;
        "WARNING")
            if [[ "$pending" -gt 0 ]]; then
                echo "URGENT: Run 'zfs scrub $pool' within 4 hours"
            else
                echo "MONITOR: Plan replacement within 3-6 months"
            fi
            ;;
        *)
            echo "OK: Continue monitoring"
            ;;
    esac
}

# Main execution
main() {
    local issues_found=false
    local json_data="[]"
    
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        echo -e "${BLUE}=== ZFS Disk Health Check ===${NC}"
        echo "Checking all drives for SMART issues and mapping to ZFS pools..."
        echo
    fi
    
    # Get all block devices that might be ZFS drives
    local devices=()
    
    # Add all drives from /dev/disk/by-id/ that are likely storage drives
    while IFS= read -r -d '' device; do
        # Skip partitions and focus on whole drives
        if [[ ! "$device" =~ -part[0-9]+$ ]] && [[ -b "$device" ]]; then
            devices+=("$device")
        fi
    done < <(find /dev/disk/by-id/ -name "ata-*" -o -name "nvme-*" -o -name "wwn-*" -print0 2>/dev/null)
    
    # Process each device
    for device in "${devices[@]}"; do
        # Skip if device doesn't exist or isn't readable
        if [[ ! -e "$device" ]] || ! smartctl -i "$device" &>/dev/null; then
            continue
        fi
        
        # Get device info
        local device_name=$(basename "$device")
        local serial=$(get_device_serial "$device")
        local pool_info=$(get_zfs_pool "$device")
        local pool_name=$(echo "$pool_info" | cut -d: -f1)
        local pool_state=$(echo "$pool_info" | cut -d: -f2)
        
        # Get SMART attributes
        local smart_data=$(get_smart_attributes "$device")
        IFS=':' read -r reallocated pending uncorrectable temperature health <<< "$smart_data"
        
        # Determine severity and action
        local severity=$(get_severity "$pending" "$reallocated" "$uncorrectable" "$health")
        local action=$(get_action "$severity" "$pending" "$pool_name")
        
        # Track if we found any issues
        if [[ "$severity" != "OK" ]]; then
            issues_found=true
        fi
        
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            # Build JSON output
            local json_entry=$(cat <<EOF
{
    "device": "$device",
    "device_name": "$device_name",
    "serial": "$serial",
    "pool": "$pool_name",
    "pool_state": "$pool_state",
    "smart": {
        "health": "$health",
        "reallocated_sectors": $reallocated,
        "pending_sectors": $pending,
        "uncorrectable_sectors": $uncorrectable,
        "temperature": $temperature
    },
    "severity": "$severity",
    "action": "$action"
}
EOF
            )
            if [[ "$json_data" == "[]" ]]; then
                json_data="[$json_entry]"
            else
                json_data="${json_data%]}, $json_entry]"
            fi
        else
            # Human-readable output
            local color=""
            case "$severity" in
                "CRITICAL") color="$RED" ;;
                "WARNING") color="$YELLOW" ;;
                "OK") color="$GREEN" ;;
            esac
            
            echo -e "${color}[$severity]${NC} $device_name"
            echo "  Pool: $pool_name ($pool_state)"
            echo "  Serial: $serial"
            echo "  SMART Health: $health"
            
            if [[ "$severity" != "OK" ]] || [[ "$VERBOSE" == "true" ]]; then
                echo "  Reallocated Sectors: $reallocated"
                echo "  Pending Sectors: $pending"
                echo "  Uncorrectable Sectors: $uncorrectable"
                echo "  Temperature: ${temperature}°C"
                echo -e "  ${color}Action: $action${NC}"
            fi
            echo
        fi
    done
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "$json_data" | jq '.' 2>/dev/null || echo "$json_data"
    else
        # Summary
        if [[ "$issues_found" == "true" ]]; then
            echo -e "${RED}⚠️  Issues found! Check devices marked WARNING or CRITICAL above.${NC}"
            echo -e "${YELLOW}💡 Quick commands:${NC}"
            echo "   - Check specific pool: zpool status <poolname>"
            echo "   - Start scrub: zfs scrub <poolname>"
            echo "   - Monitor scrub: watch 'zpool status'"
            echo "   - Check SMART details: smartctl -A /dev/disk/by-id/<device>"
        else
            echo -e "${GREEN}✅ All drives healthy!${NC}"
        fi
        
        echo
        echo -e "${BLUE}Pool Status Summary:${NC}"
        zpool list -H | while read -r pool size alloc free ckpoint expandsz frag cap dedup health altroot; do
            local pool_color="$GREEN"
            if [[ "$health" != "ONLINE" ]]; then
                pool_color="$RED"
            elif [[ "${cap%\%}" -gt 80 ]]; then
                pool_color="$YELLOW"
            fi
            echo -e "  ${pool_color}$pool${NC}: $health ($cap full)"
        done
    fi
}

# Check if required commands are available
if ! command -v smartctl &> /dev/null; then
    echo "Error: smartctl not found. Please ensure smartmontools is installed."
    exit 1
fi

if ! command -v zpool &> /dev/null; then
    echo "Error: zpool not found. This script requires ZFS to be installed."
    exit 1
fi

# Check if running as root (required for SMART access)
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script requires root privileges to access SMART data"
    echo "Run with: sudo $0"
    exit 1
fi

# Run main function
main
