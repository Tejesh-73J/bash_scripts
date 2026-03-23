#!/bin/bash

# ============================================================
# kill_specific_window.sh
# Kills a specific browser window based on its title substring.
# Usage: ./kill_specific_window.sh "browser_name" "title_substring"
# Example: ./kill_specific_window.sh chrome youtube
# ============================================================

BROWSER_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
TITLE_SUBSTRING="$2"

# --- Help message ---
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Kill Specific Window"
    echo "===================="
    echo "This script immediately targets and kills a specific browser window."
    echo ""
    echo "Usage: $0 browser_name title_substring"
    echo ""
    echo "Arguments:"
    echo "  browser_name     The name of the browser (e.g., chrome, firefox, brave)"
    echo "  title_substring  A string found in the window title (e.g., youtube, netflix, whatsapp)"
    echo ""
    echo "Example:"
    echo "  $0 chrome youtube   # Immediately closes the YouTube window in Chrome"
    exit 0
fi

if [[ -z "$BROWSER_NAME" || -z "$TITLE_SUBSTRING" ]]; then
    echo "Usage: $0 \"browser_name\" \"title_substring\""
    echo "Try '$0 --help' for more information."
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
    edge|microsoft-edge)
        BROWSER_CLASS="Microsoft-edge"
        ;;
    *)
        BROWSER_CLASS="$1" # Try using the input value directly
        ;;
esac

echo "Looking for $BROWSER_CLASS windows with title containing '$TITLE_SUBSTRING'..."

# Search for windows belonging to the browser class
# We catch IDs and process each to check the title
WINDOW_IDS=$(xdotool search --class "$BROWSER_CLASS" 2>/dev/null)

if [[ -z "$WINDOW_IDS" ]]; then
    echo "No windows found for browser class '$BROWSER_CLASS'."
    exit 0
fi

MATCH_FOUND=false

for WIN_ID in $WINDOW_IDS; do
    # Get current window title
    WIN_TITLE=$(xdotool getwindowname "$WIN_ID" 2>/dev/null)
    
    # Simple check for title match (case-insensitive)
    if echo "$WIN_TITLE" | grep -iq "$TITLE_SUBSTRING"; then
        echo "Found: '$WIN_TITLE' (ID: $WIN_ID)"
        MATCH_FOUND=true
        
        # Step 1: Force focus/activation
        # Using windowfocus + windowactivate to be extra sure
        xdotool windowfocus --sync "$WIN_ID" 2>/dev/null
        xdotool windowactivate --sync "$WIN_ID" 2>/dev/null
        sleep 0.5
        
        # Step 2: Attempt standard window close (Alt+F4)
        # This triggers confirmation dialogs if they exist
        echo "Closing window..."
        xdotool key --clearmodifiers alt+F4
        
        # Step 3: Handle alerts / "Leave site?" boxes
        # We send Return/Enter to confirm departure
        # We also send Space just in case. 
        # Repeating helps if multiple alerts stack up.
        for i in {1..2}; do
            sleep 1
            echo "Attempting to accept/clear alert ($i/2)..."
            xdotool key --clearmodifiers Return
            sleep 0.5
            xdotool key --clearmodifiers Space
        done
        
        # Step 4: Verification and Clean Up
        sleep 2
        if xdotool getwindowname "$WIN_ID" &>/dev/null; then
            echo "Window is still open after soft close. Forcing termination..."
            # Try xdotool windowkill first - it usually terminates the process associated with window
            xdotool windowkill "$WIN_ID" 2>/dev/null
            
            # If still around, find the PID and kill -9
            WIN_PID=$(xdotool getwindowpid "$WIN_ID" 2>/dev/null)
            if [[ -n "$WIN_PID" && "$WIN_PID" != "0" ]]; then
                echo "Killing associated process PID: $WIN_PID"
                kill -9 "$WIN_PID" 2>/dev/null
            fi
        else
            echo "Successfully closed '$WIN_TITLE'."
        fi
    fi
done

if [[ "$MATCH_FOUND" = false ]]; then
    echo "No window found matching '$TITLE_SUBSTRING' in browser '$BROWSER_NAME'."
fi

echo "Done."
