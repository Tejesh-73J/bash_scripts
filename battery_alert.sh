#!/bin/bash

# Battery Alert Script
# Monitors battery level and plays an alert sound when battery is at or below 96%

# Configuration
BATTERY_THRESHOLD=40
CHECK_INTERVAL=300  # Check every 60 seconds
sound_duration=10

# Function to get battery percentage
get_battery_percentage() {
    # Try multiple methods to get battery percentage
    local battery_level=""
    
    # Method 1: Using upower
    if command -v upower &> /dev/null; then
        battery_level=$(upower -i $(upower -e | grep BAT) | grep percentage | awk '{print $2}' | sed 's/%//')
    fi
    
    # Method 2: Using acpi (fallback)
    if [ -z "$battery_level" ] && command -v acpi &> /dev/null; then
        battery_level=$(acpi -b | grep -P -o '[0-9]+(?=%)')
    fi
    
    # Method 3: Using /sys/class/power_supply (fallback)
    if [ -z "$battery_level" ] && [ -f /sys/class/power_supply/BAT0/capacity ]; then
        battery_level=$(cat /sys/class/power_supply/BAT0/capacity)
    fi
    
    echo "$battery_level"
}

# Function to check if battery is charging
is_battery_charging() {
    local charging_status=""
    
    # Method 1: Using upower
    if command -v upower &> /dev/null; then
        charging_status=$(upower -i $(upower -e | grep BAT) | grep state | awk '{print $2}')
        if [ "$charging_status" = "charging" ] || [ "$charging_status" = "fully-charged" ]; then
            echo "true"
            return
        fi
    fi
    
    # Method 2: Using acpi
    if command -v acpi &> /dev/null; then
        charging_status=$(acpi -b | grep -o "Charging\|Discharging\|Full")
        if [ "$charging_status" = "Charging" ] || [ "$charging_status" = "Full" ]; then
            echo "true"
            return
        fi
    fi
    
    # Method 3: Using /sys/class/power_supply
    if [ -f /sys/class/power_supply/BAT0/status ]; then
        charging_status=$(cat /sys/class/power_supply/BAT0/status)
        if [ "$charging_status" = "Charging" ] || [ "$charging_status" = "Full" ]; then
            echo "true"
            return
        fi
    fi
    
    echo "false"
}

# Function to unmute and set volume to maximum
set_volume_max() {
    # Unmute and set volume to 100% using amixer
    if command -v amixer &> /dev/null; then
        amixer -D pulse sset Master unmute &> /dev/null
        amixer -D pulse sset Master 100% &> /dev/null
    fi
    
    # Also try pactl for PulseAudio
    if command -v pactl &> /dev/null; then
        pactl set-sink-mute @DEFAULT_SINK@ 0
        pactl set-sink-volume @DEFAULT_SINK@ 100%
    fi
}

# Function to play alert sound continuously for a duration
play_alert_sound_continuous() {
    local duration=$1  # Duration in seconds
    local end_time=$(($(date +%s) + duration))
    
    echo "Playing alert sound for ${duration} seconds..."
    
    while [ $(date +%s) -lt $end_time ]; do
        # Method 1: Using paplay (PulseAudio)
        if command -v paplay &> /dev/null && [ -f /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga ]; then
            paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null
            sleep 0.5
            continue
        fi
        
        # Method 2: Using speaker-test
        if command -v speaker-test &> /dev/null; then
            timeout 2 speaker-test -t sine -f 1000 &> /dev/null
            sleep 0.5
            continue
        fi
        
        # Method 3: Using beep
        if command -v beep &> /dev/null; then
            beep -f 1000 -l 500
            sleep 0.5
            continue
        fi
        
        # Method 4: Using system bell
        echo -e '\a'
        sleep 1
    done
    
    echo "Alert sound stopped after ${duration} seconds."
}

# Function to send notification
send_notification() {
    local battery_level=$1
    
    if command -v notify-send &> /dev/null; then
        notify-send -u critical "Low Battery Alert!" "Battery is at ${battery_level}%. Please charge your laptop!"
    fi
}

# Main monitoring loop
echo "Battery Alert Script Started"
echo "Monitoring battery level... (Threshold: ${BATTERY_THRESHOLD}%)"
echo "Alert duration: ${sound_duration} seconds"
echo "Press Ctrl+C to stop"

while true; do
    battery_level=$(get_battery_percentage)
    
    if [ -z "$battery_level" ]; then
        echo "Error: Could not detect battery level"
        sleep $CHECK_INTERVAL
        continue
    fi
    
    is_charging=$(is_battery_charging)
    
    if [ "$is_charging" = "true" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Battery Level: ${battery_level}% (Charging)"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Battery Level: ${battery_level}% (Not Charging)"
    fi
    
    # Check if battery is at or below threshold AND not charging
    if [ "$battery_level" -le "$BATTERY_THRESHOLD" ] && [ "$is_charging" = "false" ]; then
        echo "⚠️  ALERT: Battery at ${battery_level}% and NOT charging! Triggering alert..."
        
        # Unmute and maximize volume
        set_volume_max
        
        # Send desktop notification
        send_notification "$battery_level"
        
        # Play alert sound continuously for the configured duration
        play_alert_sound_continuous $sound_duration
        
        echo "Alert completed. Will check again in ${CHECK_INTERVAL} seconds..."
    fi
    
    sleep $CHECK_INTERVAL
done
