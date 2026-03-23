#!/bin/bash

echo "Fetching all open window titles..."
xdotool search --onlyvisible --name ".*" getwindowname %@

echo "Enter a regex pattern to match the window title:"
read WINDOW_REGEX

echo "Finding windows matching: $WINDOW_REGEX..."
WINDOW_IDS=($(xdotool search --name ".*" | while read ID; do 
    WIN_TITLE=$(xdotool getwindowname "$ID")
    if [[ "$WIN_TITLE" =~ $WINDOW_REGEX ]]; then
        echo "$ID"
    fi
done))

# Check if multiple windows are found
if [[ ${#WINDOW_IDS[@]} -gt 1 ]]; then
    echo "Multiple windows found matching '$WINDOW_REGEX':"
    for i in "${!WINDOW_IDS[@]}"; do
        WIN_TITLE=$(xdotool getwindowname "${WINDOW_IDS[$i]}")
        echo "[$i] $WIN_TITLE"
    done

    echo "Enter the number of the window to focus on:"
    read WIN_INDEX
    WINDOW_ID=${WINDOW_IDS[$WIN_INDEX]}
elif [[ ${#WINDOW_IDS[@]} -eq 1 ]]; then
    WINDOW_ID=${WINDOW_IDS[0]}
else
    echo "No window found matching '$WINDOW_REGEX'. Exiting..."
    exit 1
fi

echo "Keeping focus on window: $(xdotool getwindowname $WINDOW_ID)"

while true; do
    xdotool windowactivate "$WINDOW_ID"
    sleep 1
done

