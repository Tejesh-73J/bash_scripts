#!/bin/bash

# ============================================================
# kill_process_at_time.sh
# Kills a process matching 'team' at a specified time.
# Usage: ./kill_process_at_time.sh HH:MM "your_sudo_password"
# Example: ./kill_process_at_time.sh 18:30 "mypassword"
# ============================================================

TARGET_TIME="$1"
SUDO_PASS="$2"
PROCESS_NAME="Bosscoder"

# --- Validate arguments ---
if [[ -z "$TARGET_TIME" || -z "$SUDO_PASS" ]]; then
    echo "Usage: $0 HH:MM \"your_sudo_password\""
    echo "Example: $0 18:30 \"mypassword\""
    exit 1
fi

# Validate time format HH:MM
if ! [[ "$TARGET_TIME" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "Error: Invalid time format. Please use HH:MM (24-hour format)."
    exit 1
fi

echo "Scheduler armed. Will kill process matching '$PROCESS_NAME' at $TARGET_TIME (IST)."
echo "Current time (IST): $(TZ="Asia/Kolkata" date '+%H:%M:%S')"
echo "Waiting..."

# --- Wait until target time ---
while true; do
    # Get current time in India timezone
    CURRENT_TIME=$(TZ="Asia/Kolkata" date '+%H:%M')
    
    if [[ "$CURRENT_TIME" == "$TARGET_TIME" ]]; then
        echo ""
        echo "[$(TZ="Asia/Kolkata" date '+%H:%M:%S')] Target time (IST) reached! Killing processes matching '$PROCESS_NAME'..."

        PIDS=$(ps aux | grep -i "$PROCESS_NAME" | grep -v grep | grep -v "$0" | awk '{print $2}')

        if [[ -z "$PIDS" ]]; then
            echo "No running processes found matching '$PROCESS_NAME'."
        else
            echo "Found PIDs: $PIDS"
            echo "$SUDO_PASS" | sudo -S kill -9 $PIDS 2>/dev/null
            if [[ $? -eq 0 ]]; then
                echo "Successfully killed process(es): $PIDS"
            else
                echo "Failed to kill process(es). Check your sudo password or permissions."
            fi
        fi

        break
    fi
    sleep 10  # Check every 10 seconds to save CPU
done

echo "Done."
