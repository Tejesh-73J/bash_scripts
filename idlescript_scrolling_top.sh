#!/bin/bash

# Install xdotool if not installed
# On Ubuntu/Debian systems: sudo apt-get install xdotool

# Define sleep interval in seconds between scrolls
INTERVAL=5
MAX_FAILED_SCROLLS=3  # Number of failed scrolls before moving up
failed_scrolls=0

while true; do
    # Scroll down
    xdotool click 5
    
    # Wait for the defined interval
    sleep $INTERVAL

    # Check if scrolling had an effect by comparing mouse position
    prev_pos=$(xdotool getmouselocation --shell | grep Y= | cut -d= -f2)
    sleep 0.5  # Small delay before checking position again
    new_pos=$(xdotool getmouselocation --shell | grep Y= | cut -d= -f2)

    if [[ "$prev_pos" == "$new_pos" ]]; then
        ((failed_scrolls++))
    else
        failed_scrolls=0  # Reset if successful scroll
    fi

    # If max failed scrolls reached, move 10 steps up
    if [[ $failed_scrolls -ge $MAX_FAILED_SCROLLS ]]; then
        for i in {1..10}; do
            xdotool click 4
            sleep 0.2  # Small delay for smooth scrolling
        done
        failed_scrolls=0  # Reset failed counter
    else
        # Scroll up normally
        xdotool click 4
    fi

    # Wait again before repeating
    sleep $INTERVAL
done

