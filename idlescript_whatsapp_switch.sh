#!/bin/bash

# Configuration (Updated to your preferences)
INTERVAL=3
CLICK_X=600
CLICK_Y=400
TARGET_WIDTH=1126
TARGET_HEIGHT=833

# Screen dimensions (detected automatically)
SCREEN_WIDTH=$(xdpyinfo | grep dimensions | awk '{print $2}' | cut -d'x' -f1)
SCREEN_HEIGHT=$(xdpyinfo | grep dimensions | awk '{print $2}' | cut -d'x' -f2)

# Start battery alert script in the background
bash /home/tejesh/bash_scripts/battery_alert.sh > /dev/null 2>&1 &
BATTERY_ALERT_PID=$!
echo "Battery alert script started (PID: $BATTERY_ALERT_PID)"

# Trap to kill battery alert when this script exits
cleanup() {
    echo ""
    echo "Stopping battery alert script (PID: $BATTERY_ALERT_PID)..."
    kill $BATTERY_ALERT_PID 2>/dev/null
    echo "Both scripts stopped. Goodbye!"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

echo "------------------------------------------------"
echo "WhatsApp Window Switcher & Idle Prevention"
echo "------------------------------------------------"

# 1. Find all visible windows with "WhatsApp" in the title
ALL_IDS=$(xdotool search --onlyvisible --name "WhatsApp" 2>/dev/null)
WINDOW_IDS=()

# 2. Filter these IDs to ensure they are Google Chrome windows
for ID in $ALL_IDS; do
    CLASS=$(xprop -id "$ID" WM_CLASS 2>/dev/null)
    if [[ "$CLASS" == *"Google-chrome"* ]]; then
        WINDOW_IDS+=("$ID")
    fi
done

if [ ${#WINDOW_IDS[@]} -lt 2 ]; then
    echo "Warning: Found ${#WINDOW_IDS[@]} WhatsApp Chrome window(s). You mentioned two; ensure both are open."
    if [ ${#WINDOW_IDS[@]} -eq 0 ]; then
        echo "Error: No WhatsApp windows found. Exiting."
        exit 1
    fi
fi

echo "Targeting these windows:"
for ID in "${WINDOW_IDS[@]}"; do
    echo " -> ID: $ID | Name: $(xdotool getwindowname "$ID")"
done
echo "------------------------------------------------"
echo "Running switching loop... Press Ctrl+C to stop."
echo "Safety: Click position set to ($CLICK_X, $CLICK_Y) to avoid UI buttons."

while true; do
    for WIN_ID in "${WINDOW_IDS[@]}"; do
        # 1. Check if window still exists
        if ! xdotool getwindowname "$WIN_ID" > /dev/null 2>&1; then
            echo "Refreshing window list..."
            ALL_IDS=$(xdotool search --onlyvisible --name "WhatsApp" 2>/dev/null)
            WINDOW_IDS=()
            for ID in $ALL_IDS; do
                CLASS=$(xprop -id "$ID" WM_CLASS 2>/dev/null)
                if [[ "$CLASS" == *"Google-chrome"* ]]; then
                    WINDOW_IDS+=("$ID")
                fi
            done
            break 
        fi

        # 2. Activate and Focus
        xdotool windowactivate --sync "$WIN_ID"
        xdotool windowfocus "$WIN_ID"
        
        # 3. Check Maximization and Force Dimensions
        STATE=$(xprop -id "$WIN_ID" _NET_WM_STATE 2>/dev/null)
        if [[ "$STATE" == *"_NET_WM_STATE_MAXIMIZED_HORZ"* ]] || [[ "$STATE" == *"_NET_WM_STATE_MAXIMIZED_VERT"* ]]; then
            echo "   -> Window is maximized. Unmaximizing and moving to a random position..."
            
            # Use alt+F5 to unmaximize (standard WM shortcut)
            xdotool key --window "$WIN_ID" alt+F5
            sleep 0.5 # Wait for WM response
            
            # Force target size after unmaximize
            xdotool windowsize "$WIN_ID" $TARGET_WIDTH $TARGET_HEIGHT
            
            # Generate random position
            MAX_X=$((SCREEN_WIDTH - TARGET_WIDTH))
            MAX_Y=$((SCREEN_HEIGHT - TARGET_HEIGHT))
            
            # Avoid negative values if screen is smaller than target
            [ $MAX_X -lt 0 ] && MAX_X=0
            [ $MAX_Y -lt 0 ] && MAX_Y=0
            
            RAND_X=$(( RANDOM % (MAX_X + 1) ))
            RAND_Y=$(( RANDOM % (MAX_Y + 1) ))
            
            echo "   -> Moving to random position: ($RAND_X, $RAND_Y)"
            xdotool windowmove "$WIN_ID" $RAND_X $RAND_Y
            
            sleep 0.5 # Wait for changes to take effect
        else
            # Ensure standard dimensions if not maximized
            CURRENT_GEOM=$(xdotool getwindowgeometry "$WIN_ID" | grep "Geometry" | awk '{print $2}')
            if [ "$CURRENT_GEOM" != "${TARGET_WIDTH}x${TARGET_HEIGHT}" ]; then
                echo "   -> Resizing window from $CURRENT_GEOM to ${TARGET_WIDTH}x${TARGET_HEIGHT}..."
                xdotool windowsize "$WIN_ID" $TARGET_WIDTH $TARGET_HEIGHT
                sleep 0.5 # Wait for resize to take effect
            fi
        fi
        
        CURRENT_GEOM=$(xdotool getwindowgeometry "$WIN_ID" | grep "Geometry" | awk '{print $2}')
        echo "Focused: [Size: $CURRENT_GEOM] $(xdotool getwindowname "$WIN_ID" | cut -c 1-30)..."
        
        # 4. Mouse Click
        xdotool mousemove --window "$WIN_ID" $CLICK_X $CLICK_Y click 1
        
        sleep $INTERVAL
    done
done
