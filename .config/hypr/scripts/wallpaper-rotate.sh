#!/usr/bin/env bash

# Wallpaper rotation daemon for Hyprland using swww

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

ROTATION_MODE="random"
WALLPAPER_SUBDIR="ghibli"
INTERVAL=1800
ENABLE_LOGGING="false"

# ============================================================================
# Help
# ============================================================================

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Wallpaper rotation daemon for Hyprland using swww.

OPTIONS:
    -m, --mode MODE         Rotation mode: random|sequential (default: random)
    -d, --dir SUBDIR        Wallpaper subdirectory name (default: ghibli)
    -i, --interval SECONDS  Rotation interval in seconds (default: 3600)
    -l, --log               Enable logging (default: disabled)
    -h, --help              Show this help message

EXAMPLES:
    $(basename "$0") -m sequential -i 1800
    $(basename "$0") --dir cyberpunk-pixel --interval 600 --log

WALLPAPERS:
    Wallpapers are loaded from: ~/Pictures/wallpapers/SUBDIR/
EOF
    exit 0
}

# ============================================================================
# Argument Parsing
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--mode)
                ROTATION_MODE="$2"
                shift 2
                ;;
            -d|--dir)
                WALLPAPER_SUBDIR="$2"
                shift 2
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -l|--log)
                ENABLE_LOGGING="true"
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                error "Unknown option: $1"
                echo "Use -h or --help for usage information" >&2
                exit 1
                ;;
        esac
    done
    
    # Set derived configuration
    readonly ROTATION_MODE
    readonly WALLPAPER_SUBDIR
    readonly INTERVAL
    readonly ENABLE_LOGGING
    readonly WALLPAPER_DIR="${HOME}/Pictures/wallpapers/${WALLPAPER_SUBDIR}"
    readonly STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-wallpaper.state"
    readonly LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-wallpaper.log"
}

# ============================================================================
# Logging
# ============================================================================

log() {
    [[ "$ENABLE_LOGGING" == "true" ]] || return 0
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

error() {
    printf 'ERROR: %s\n' "$*" >&2
    log "ERROR: $*"
}

# ============================================================================
# Validation
# ============================================================================

check_dependencies() {
    local -a missing_deps=()
    local -r required_cmds=(hyprctl awww jq)
    
    for cmd in "${required_cmds[@]}"; do
        command -v "$cmd" &>/dev/null || missing_deps+=("$cmd")
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing_deps[*]}"
        exit 1
    fi
}

validate_config() {
    if [[ ! "$ROTATION_MODE" =~ ^(random|sequential)$ ]]; then
        error "Invalid ROTATION_MODE '$ROTATION_MODE' (expected: random|sequential)"
        exit 1
    fi
    
    if [[ ! -d "$WALLPAPER_DIR" ]]; then
        error "Wallpaper directory not found: $WALLPAPER_DIR"
        exit 1
    fi
}

# ============================================================================
# Monitor Operations
# ============================================================================

get_monitors() {
    hyprctl monitors -j 2>/dev/null | jq -r '.[].name' | sort
}

# ============================================================================
# Wallpaper Operations
# ============================================================================

get_wallpaper_files() {
    local -r mode="$1"
    local -a files=()
    
    shopt -s nullglob
    files=("$WALLPAPER_DIR"/*.{gif,png,jpg,jpeg,webp})
    shopt -u nullglob
    
    [[ ${#files[@]} -eq 0 ]] && return 1
    
    if [[ "$mode" == "sequential" ]]; then
        printf '%s\n' "${files[@]}" | sort
    else
        printf '%s\n' "${files[@]}" | shuf
    fi
}

set_wallpaper() {
    local -r monitor="$1"
    local -r wallpaper="$2"
    
    log "Setting wallpaper on $monitor: $(basename "$wallpaper")"
    if ! awww img "$wallpaper" --outputs "$monitor" --resize crop --transition-type none 2>&1 | tee -a "${LOG_FILE:-/dev/null}"; then
        error "Failed to set wallpaper on $monitor"
        return 1
    fi
}

# ============================================================================
# State Management
# ============================================================================

load_state() {
    [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "{}"
}

save_state() {
    echo "$1" > "$STATE_FILE"
}

get_current_index() {
    local -r state="$1"
    jq -r '.index // 0' <<< "$state" 2>/dev/null || echo "0"
}

# ============================================================================
# Rotation Logic
# ============================================================================

rotate_wallpapers() {
    local -a monitors wallpapers
    local current_index next_index state
    
    mapfile -t monitors < <(get_monitors)
    
    if [[ ${#monitors[@]} -eq 0 ]]; then
        log "No monitors detected, retrying in ${INTERVAL}s"
        return
    fi
    
    state=$(load_state)
    current_index=$(get_current_index "$state")
    
    # Reshuffle if needed
    if [[ "$ROTATION_MODE" == "random" && "$current_index" -ge ${#WALLPAPERS[@]} ]]; then
        mapfile -t WALLPAPERS < <(get_wallpaper_files "$ROTATION_MODE")
        current_index=0
        log "Reshuffled wallpaper list"
    fi
    
    # Apply wallpapers to monitors
    for i in "${!monitors[@]}"; do
        local monitor="${monitors[$i]}"
        local wallpaper_index=$(( (current_index + i) % ${#WALLPAPERS[@]} ))
        local wallpaper="${WALLPAPERS[$wallpaper_index]}"
        
        set_wallpaper "$monitor" "$wallpaper"
    done
    
    # Update state
    next_index=$(( (current_index + ${#monitors[@]}) % ${#WALLPAPERS[@]} ))
    state=$(jq -n --arg mode "$ROTATION_MODE" --argjson idx "$next_index" '{index: $idx, mode: $mode}')
    save_state "$state"
    
    log "Wallpapers set successfully"
}

# ============================================================================
# Main
# ============================================================================

main() {
    parse_args "$@"
    check_dependencies
    validate_config
    
    declare -a WALLPAPERS
    mapfile -t WALLPAPERS < <(get_wallpaper_files "$ROTATION_MODE")
    
    if [[ ${#WALLPAPERS[@]} -eq 0 ]]; then
        error "No wallpaper files found in $WALLPAPER_DIR"
        exit 1
    fi
    
    log "Starting wallpaper rotation daemon (mode: $ROTATION_MODE, interval: ${INTERVAL}s, wallpapers: ${#WALLPAPERS[@]})"
    
    while true; do
        rotate_wallpapers
        sleep "$INTERVAL"
    done
}

main "$@"
