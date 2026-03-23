#!/bin/bash

# ============================================================
# kill_window_at_time.sh
# Kills a specific browser window (e.g., YouTube, Netflix) at a set time.
# Usage: ./kill_window_at_time.sh HH:MM browser_name title_substring
# Example: ./kill_window_at_time.sh 22:30 chrome youtube
# ============================================================

TARGET_TIME="$1"
BROWSER_NAME=$(echo "$2" | tr '[:upper:]' '[:lower:]')
TITLE_SUBSTRING="$3"

# --- Help message ---
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Kill Specific Window at Time"
    echo "==========================="
    echo "This script waits until a target time and then kills a specific browser window."
    echo ""
    echo "Usage: $0 HH:MM browser_name title_substring"
    echo ""
    echo "Arguments:"
    echo "  HH:MM            The time to trigger the kill (24-hour format, e.g., 22:30)"
    echo "  browser_name     The name of the browser (e.g., chrome, firefox, brave)"
    echo "  title_substring  A string found in the window title (e.g., youtube, netflix, whatsapp)"
    echo ""
    echo "Example:"
    echo "  $0 18:00 chrome youtube   # Kills YouTube in Chrome at 6:00 PM"
    exit 0
fi

# --- Validate arguments ---
if [[ -z "$TARGET_TIME" || -z "$BROWSER_NAME" || -z "$TITLE_SUBSTRING" ]]; then
    echo "Usage: $0 HH:MM browser_name title_substring"
    echo "Try '$0 --help' for more information."
    exit 1
fi

# Validate time format HH:MM
if ! [[ "$TARGET_TIME" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "Error: Invalid time format. Please use HH:MM (24-hour format)."
    exit 1
fi

# Map browser aliases to window classes
case "$BROWSER_NAME" in
    chrome|google-chrome|googlechrome|google-chrome-stable)
        BROWSER_CLASS="Google-chrome"
        ;;
    firefox|mozilla|mozilla-firefox)
        BROWSER_CLASS="firefox"
        ;;
    brave|brave-browser)
        BROWSER_CLASS="Brave-browser"
        ;;
    *)
        BROWSER_CLASS="$2"
        ;;
esac

echo "Scheduler armed."
echo "Will target '$BROWSER_CLASS' windows with title '$TITLE_SUBSTRING' at $TARGET_TIME (IST)."
echo "Current time (IST): $(TZ="Asia/Kolkata" date '+%H:%M:%S')"
echo "Waiting..."

# --- Wait until target time ---
while true; do
    CURRENT_TIME=$(TZ="Asia/Kolkata" date '+%H:%M')
    
    if [[ "$CURRENT_TIME" == "$TARGET_TIME" ]]; then
        echo ""
        echo "[$(TZ="Asia/Kolkata" date '+%H:%M:%S')] Target time reached! Searching for windows..."

        WINDOW_IDS=$(xdotool search --class "$BROWSER_CLASS" 2>/dev/null)

        if [[ -z "$WINDOW_IDS" ]]; then
            echo "No windows found for browser class '$BROWSER_CLASS'."
        else
            MATCH_FOUND=false
            for WIN_ID in $WINDOW_IDS; do
                WIN_TITLE=$(xdotool getwindowname "$WIN_ID" 2>/dev/null)
                
                if echo "$WIN_TITLE" | grep -iq "$TITLE_SUBSTRING"; then
                    echo "Found match: '$WIN_TITLE'. Killing..."
                    MATCH_FOUND=true
                    
                    # Activate and Close
                    xdotool windowactivate --sync "$WIN_ID" 2>/dev/null
                    xdotool key --clearmodifiers alt+F4
                    
                    # Accept alerts
                    for i in {1..2}; do
                        sleep 1
                        xdotool key --clearmodifiers Return
                        sleep 0.5
                        xdotool key --clearmodifiers Space
                    done
                    
                    # Force kill if still exists
                    sleep 2
                    if xdotool getwindowname "$WIN_ID" &>/dev/null; then
                        echo "Window stubborn, using hard kill..."
                        xdotool windowkill "$WIN_ID" 2>/dev/null
                        WIN_PID=$(xdotool getwindowpid "$WIN_ID" 2>/dev/null)
                        [[ -n "$WIN_PID" && "$WIN_PID" != "0" ]] && kill -9 "$WIN_PID" 2>/dev/null
                    fi
                fi
            done
            [[ "$MATCH_FOUND" == "false" ]] && echo "No matches found for '$TITLE_SUBSTRING'."
        fi

        break
    fi
    sleep 10
done

echo "Done."
