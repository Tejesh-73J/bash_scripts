#!/bin/bash

echo "Searching for Chrome windows with 'WhatsApp' in the title..."
echo "--------------------------------------------------------"

# Find all visible Chrome windows with WhatsApp in the title
ALL_IDS=$(xdotool search --onlyvisible --name "WhatsApp" 2>/dev/null)

if [ -z "$ALL_IDS" ]; then
    echo "No WhatsApp windows found."
    exit 1
fi

for ID in $ALL_IDS; do
    # Verify it is a Google Chrome window
    CLASS=$(xprop -id "$ID" WM_CLASS 2>/dev/null)
    if [[ "$CLASS" == *"Google-chrome"* ]]; then
        NAME=$(xdotool getwindowname "$ID")
        GEOM=$(xdotool getwindowgeometry "$ID" | grep "Geometry" | awk '{print $2}')
        POSITION=$(xdotool getwindowgeometry "$ID" | grep "Position" | awk '{print $2}')
        
        echo "Window ID:   $ID"
        echo "Name:        $NAME"
        echo "Dimensions:  $GEOM"
        echo "Position:    $POSITION"
        echo "--------------------------------------------------------"
    fi
done
