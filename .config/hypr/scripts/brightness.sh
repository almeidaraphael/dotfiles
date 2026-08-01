#!/bin/bash

# Brightness control script for external monitors using ddcutil
# Usage: brightness.sh <0-100>

set -e

# Configuration
BRIGHTNESS_VALUE="${1:-100}"
CACHE_FILE="/tmp/brightness_buses.cache"
LOG_FILE="/tmp/brightness.log"
ENABLE_LOGGING=false
TIMEOUT=5

# Logging function
log() {
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
    fi
}

# Check if ddcutil is installed
if ! command -v ddcutil &> /dev/null; then
    log "ERROR: ddcutil is not installed"
    exit 1
fi

# Validate brightness value
if ! [[ "$BRIGHTNESS_VALUE" =~ ^[0-9]+$ ]] || [ "$BRIGHTNESS_VALUE" -lt 0 ] || [ "$BRIGHTNESS_VALUE" -gt 100 ]; then
    log "ERROR: Invalid brightness value: $BRIGHTNESS_VALUE (must be 0-100)"
    exit 1
fi

# Function to get monitor buses
get_monitor_buses() {
    if [ -f "$CACHE_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$CACHE_FILE"))) -lt 3600 ]; then
        # Use cached buses if file is less than 1 hour old
        cat "$CACHE_FILE"
    else
        # Detect buses and cache them
        ddcutil detect --brief 2>/dev/null | grep -oP 'I2C bus:\s+/dev/i2c-\K\d+' | tee "$CACHE_FILE"
    fi
}

# Get monitor buses
BUSES=($(get_monitor_buses))

if [ ${#BUSES[@]} -eq 0 ]; then
    log "ERROR: No monitors detected via DDC/CI"
    exit 1
fi

log "Setting brightness to $BRIGHTNESS_VALUE% on ${#BUSES[@]} monitor(s)"

# Set brightness on one monitor, retrying since DDC/CI can be unresponsive
# right after a monitor wakes from DPMS off.
set_brightness_with_retry() {
    local bus="$1"
    local attempt
    for attempt in 1 2 3; do
        if timeout "$TIMEOUT" ddcutil setvcp 10 "$BRIGHTNESS_VALUE" --noverify --bus "$bus" &> /dev/null; then
            log "Bus $bus set on attempt $attempt"
            return 0
        fi
        log "WARNING: Bus $bus attempt $attempt failed, retrying"
        sleep 1
    done
    log "ERROR: Bus $bus failed after 3 attempts"
    return 1
}

# Set brightness on all monitors in parallel
pids=()
for bus in "${BUSES[@]}"; do
    set_brightness_with_retry "$bus" &
    pids+=($!)
done

# Wait for all commands to complete
for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || log "WARNING: bus retry loop for pid $pid still failed"
done

log "Brightness set successfully"
