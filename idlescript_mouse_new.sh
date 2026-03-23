#!/bin/bash

# Install xdotool if not installed
# On Ubuntu/Debian systems: sudo apt-get install xdotool

# Define sleep interval in seconds between mouse movements
INTERVAL=2

# Infinite loop to keep moving the mouse
while true; do
    # Move the mouse 1 pixel to the right
    xdotool mousemove_relative 200 0
    
    # Wait for the defined interval
    sleep $INTERVAL
    

    # Move the mouse 1 pixel to the left (back to original position)
    
    xdotool mousemove_relative -- -200 0

    # Wait again before repeating
    sleep $INTERVAL
done

