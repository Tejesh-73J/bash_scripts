#!/bin/bash

# Install xdotool if not installed
# On Ubuntu/Debian systems: sudo apt-get install xdotool

# Define sleep interval in seconds between scrolls
INTERVAL=5

# Infinite loop to keep scrolling
while true; do
    # Scroll down
    xdotool click 5
    
    # Wait for the defined interval
    sleep $INTERVAL

    # Scroll up
    xdotool click 4

    # Wait again before repeating
    sleep $INTERVAL
done

