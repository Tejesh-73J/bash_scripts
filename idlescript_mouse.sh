#!/bin/bash

# Get IST time function
get_ist_time() {
    date +%H:%M --date="TZ=\"Asia/Kolkata\""
}

INTERVAL=30

while true; do
    # Get current IST time in HH:MM format
    current_time=$(TZ="Asia/Kolkata" date "+%H:%M")

    # Restricted time window: 12:30 to 13:15 IST
    if [[ "$current_time" > "12:29" && "$current_time" < "12:35" ]]; then
        echo "[$current_time] Skipping mouse movement (within 12:30 PM - 1:10 PM IST)"
        sleep $INTERVAL      # Check again every 1 minute
        continue
    fi

    # Normal mouse movement operations
    ist_time=$(TZ="Asia/Kolkata" date "+%Y-%m-%d %H:%M:%S")

    # Move mouse right
    for i in {1..3}; do
        xdotool mousemove_relative $i 0
        sleep $INTERVAL
    done
    
    sleep $INTERVAL

    # Move mouse left
    for i in {1..3}; do
        xdotool mousemove_relative -- -$i 0
        sleep $INTERVAL
    done

    sleep $INTERVAL
done

