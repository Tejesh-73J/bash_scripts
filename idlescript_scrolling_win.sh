#!/bin/bash

# Install xdotool if not installed
# On Ubuntu/Debian systems: sudo apt-get install xdotool

# Define sleep interval in seconds between scrolls
INTERVAL=4

# Define the name of the target window (partial match is allowed)
WINDOW_NAME="Outlier - Google Chrome"

# Get the window ID of the target window
WINDOW_ID=$(xdotool search --name "$WINDOW_NAME" | head -n 1)

# Check if the window ID was found
if [ -z "$WINDOW_ID" ]; then
    echo "Error: Window with name '$WINDOW_NAME' not found."
    exit 1
fi

echo "Scrolling in window with ID: $WINDOW_ID"

# Infinite loop to keep scrolling
while true; do
    # Scroll down in the specified window
    xdotool windowfocus $WINDOW_ID mousemove --window $WINDOW_ID 1 1 click 5

    # Wait for the defined interval
    sleep $INTERVAL

    # Scroll up in the specified window
    xdotool windowfocus $WINDOW_ID mousemove --window $WINDOW_ID 1 1 click 4

    # Wait again before repeating
    sleep $INTERVAL
done
