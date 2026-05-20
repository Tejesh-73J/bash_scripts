#!/bin/bash

# Configuration (Updated to your preferences)
INTERVAL=3
CLICK_X=600
CLICK_Y=400
TARGET_WIDTH=1126
TARGET_HEIGHT=833

# Log file for diagnosing unexpected exits
LOG_FILE="/home/tejesh/bash_scripts/whatsapp_switch.log"
MAX_LOG_LINES=5000  # Rotate log after ~5000 lines to avoid huge files

# Helper: log to both console and file
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"

    # Rotate log if too large
    local line_count
    line_count=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$line_count" -gt "$MAX_LOG_LINES" ]; then
        tail -n $((MAX_LOG_LINES / 2)) "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
        log "Log rotated (kept last $((MAX_LOG_LINES / 2)) lines)"
    fi
}

log "=============================================="
log "WhatsApp Window Switcher & Idle Prevention"
log "Script PID: $$"
log "=============================================="

# Screen dimensions (detected automatically)
SCREEN_WIDTH=$(xdpyinfo | grep dimensions | awk '{print $2}' | cut -d'x' -f1)
SCREEN_HEIGHT=$(xdpyinfo | grep dimensions | awk '{print $2}' | cut -d'x' -f2)

# Start battery alert script in the background
bash /home/tejesh/bash_scripts/battery_alert.sh > /dev/null 2>&1 &
BATTERY_ALERT_PID=$!
log "Battery alert script started (PID: $BATTERY_ALERT_PID)"

# Start kill process scheduler in the background
# NOTE: This will intentionally kill this script at 22:35 every day.
#       If you want the script to run 24/7 (e.g., for 12-15 hours past midnight),
#       either change "22:35" to a later time or remove the "$$" argument below
#       so it only kills teamlogger but NOT this script.
bash /home/tejesh/bash_scripts/kill_process_at_time.sh "22:35" "teamlogger" "$$" > /dev/null 2>&1 &
KILL_PROCESS_PID=$!
log "Process termination scheduler started (PID: $KILL_PROCESS_PID, targeting 'teamlogger' at 22:35)"
log "NOTE: This script itself will also be terminated at 22:35 (by design)."

# Trap to kill background scripts when this script exits
# EXIT signal is intentionally NOT trapped to avoid cleanup firing on subshell exits
cleanup() {
    log ""
    log "Stopping background scripts (signal received)..."
    kill "$BATTERY_ALERT_PID" 2>/dev/null
    kill "$KILL_PROCESS_PID" 2>/dev/null
    log "All scripts stopped. Goodbye!"
    exit 0
}
trap cleanup SIGINT SIGTERM
# NOTE: EXIT trap intentionally removed — it was causing spurious cleanup on
#       subshell failures or intermediate exits within the loop.

# Helper: safely run xdotool with a timeout to prevent hangs
safe_xdotool() {
    timeout 5s xdotool "$@" 2>/dev/null
    return $?
}

# Helper: discover WhatsApp Chrome windows
discover_windows() {
    local ids
    ids=$(timeout 5s xdotool search --onlyvisible --name "WhatsApp" 2>/dev/null)
    local found=()
    for id in $ids; do
        local class
        class=$(timeout 3s xprop -id "$id" WM_CLASS 2>/dev/null)
        if [[ "$class" == *"Google-chrome"* ]]; then
            found+=("$id")
        fi
    done
    echo "${found[@]}"
}

# Initial window discovery
read -ra WINDOW_IDS <<< "$(discover_windows)"

if [ ${#WINDOW_IDS[@]} -lt 2 ]; then
    log "Warning: Found ${#WINDOW_IDS[@]} WhatsApp Chrome window(s). Ensure both are open."
    if [ ${#WINDOW_IDS[@]} -eq 0 ]; then
        log "Error: No WhatsApp windows found. Exiting."
        exit 1
    fi
fi

log "Targeting these windows:"
for ID in "${WINDOW_IDS[@]}"; do
    log " -> ID: $ID | Name: $(safe_xdotool getwindowname "$ID")"
done
log "----------------------------------------------"
log "Running switching loop... Press Ctrl+C to stop."
log "Safety: Click position set to ($CLICK_X, $CLICK_Y) to avoid UI buttons."

CONSECUTIVE_EMPTY=0  # Track how many cycles had 0 valid windows

while true; do
    # If no windows tracked, try to rediscover before giving up
    if [ ${#WINDOW_IDS[@]} -eq 0 ]; then
        CONSECUTIVE_EMPTY=$((CONSECUTIVE_EMPTY + 1))
        log "No windows in list. Rediscovering... (attempt $CONSECUTIVE_EMPTY)"
        read -ra WINDOW_IDS <<< "$(discover_windows)"

        if [ ${#WINDOW_IDS[@]} -eq 0 ]; then
            if [ "$CONSECUTIVE_EMPTY" -ge 5 ]; then
                log "No WhatsApp windows found after 5 rediscovery attempts. Waiting 30s before retrying..."
                sleep 30
                CONSECUTIVE_EMPTY=0
            else
                sleep 10
            fi
            continue
        else
            CONSECUTIVE_EMPTY=0
            log "Rediscovered ${#WINDOW_IDS[@]} window(s)."
        fi
    fi

    REFRESHED=false
    for WIN_ID in "${WINDOW_IDS[@]}"; do
        # 1. Check if window still exists (with timeout guard)
        if ! safe_xdotool getwindowname "$WIN_ID" > /dev/null; then
            log "Window $WIN_ID no longer exists. Refreshing window list..."
            read -ra WINDOW_IDS <<< "$(discover_windows)"
            log "Found ${#WINDOW_IDS[@]} window(s) after refresh."
            REFRESHED=true
            break
        fi

        # 2. Activate and Focus (with timeout guard)
        safe_xdotool windowactivate --sync "$WIN_ID"
        safe_xdotool windowfocus "$WIN_ID"

        # 3. Check Maximization and Force Dimensions
        STATE=$(timeout 3s xprop -id "$WIN_ID" _NET_WM_STATE 2>/dev/null)
        if [[ "$STATE" == *"_NET_WM_STATE_MAXIMIZED_HORZ"* ]] || [[ "$STATE" == *"_NET_WM_STATE_MAXIMIZED_VERT"* ]]; then
            log "   -> Window is maximized. Unmaximizing and moving to a random position..."

            safe_xdotool key --window "$WIN_ID" alt+F5
            sleep 0.5

            safe_xdotool windowsize "$WIN_ID" $TARGET_WIDTH $TARGET_HEIGHT

            MAX_X=$((SCREEN_WIDTH - TARGET_WIDTH))
            MAX_Y=$((SCREEN_HEIGHT - TARGET_HEIGHT))
            [ $MAX_X -lt 0 ] && MAX_X=0
            [ $MAX_Y -lt 0 ] && MAX_Y=0

            RAND_X=$(( RANDOM % (MAX_X + 1) ))
            RAND_Y=$(( RANDOM % (MAX_Y + 1) ))

            log "   -> Moving to random position: ($RAND_X, $RAND_Y)"
            safe_xdotool windowmove "$WIN_ID" $RAND_X $RAND_Y
            sleep 0.5
        else
            CURRENT_GEOM=$(safe_xdotool getwindowgeometry "$WIN_ID" | grep "Geometry" | awk '{print $2}')
            if [ "$CURRENT_GEOM" != "${TARGET_WIDTH}x${TARGET_HEIGHT}" ]; then
                log "   -> Resizing window from $CURRENT_GEOM to ${TARGET_WIDTH}x${TARGET_HEIGHT}..."
                safe_xdotool windowsize "$WIN_ID" $TARGET_WIDTH $TARGET_HEIGHT
                sleep 0.5
            fi
        fi

        CURRENT_GEOM=$(safe_xdotool getwindowgeometry "$WIN_ID" | grep "Geometry" | awk '{print $2}')
        log "Focused: [Size: $CURRENT_GEOM] $(safe_xdotool getwindowname "$WIN_ID" | cut -c 1-30)..."

        # 4. Mouse Click
        safe_xdotool mousemove --window "$WIN_ID" $CLICK_X $CLICK_Y click 1

        sleep $INTERVAL
    done

    # If we refreshed mid-loop, don't sleep extra — restart immediately
    if [ "$REFRESHED" = true ]; then
        continue
    fi
done
