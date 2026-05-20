#!/bin/bash

# ============================================================
# kill_process_at_time.sh
# Kills a process and terminates a parent script at a specified time.
# Usage: ./kill_process_at_time.sh [HH:MM] [PROCESS_NAME] [PARENT_PID] [SUDO_PASS]
# Default: ./kill_process_at_time.sh 22:35 teamlogger
# ============================================================

# 1. Parse arguments with smart defaults
TARGET_TIME="${1:-22:35}"
PROCESS_NAME="${2:-teamlogger}"
PARENT_PID="${3:-}"
SUDO_PASS="${4:-}"

# Validate time format HH:MM
if ! [[ "$TARGET_TIME" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "Error: Invalid time format '$TARGET_TIME'. Please use HH:MM (24-hour format)."
    exit 1
fi

echo "================================================="
echo "Scheduler Armed:"
echo "  Target Process:  $PROCESS_NAME"
echo "  Target Time:     $TARGET_TIME (IST)"
if [ -n "$PARENT_PID" ]; then
    echo "  Parent PID:      $PARENT_PID (will terminate on completion)"
fi
echo "================================================="

# Calculate target epoch time
TARGET_EPOCH=$(TZ="Asia/Kolkata" date -d "$TARGET_TIME" +%s)
CURRENT_EPOCH=$(TZ="Asia/Kolkata" date +%s)

# If target time is already in the past for today, schedule it for tomorrow
if [ $TARGET_EPOCH -lt $CURRENT_EPOCH ]; then
    TARGET_EPOCH=$(TZ="Asia/Kolkata" date -d "tomorrow $TARGET_TIME" +%s)
    echo "Target time has already passed for today. Scheduled for tomorrow."
fi

TARGET_DATE_STR=$(TZ="Asia/Kolkata" date -d "@$TARGET_EPOCH" "+%Y-%m-%d %H:%M:%S")
echo "Trigger Date/Time: $TARGET_DATE_STR (IST)"
echo "Current Time:      $(TZ="Asia/Kolkata" date "+%Y-%m-%d %H:%M:%S") (IST)"
echo "Monitoring... Press Ctrl+C to cancel."

while true; do
    CURRENT_EPOCH=$(TZ="Asia/Kolkata" date +%s)
    
    if [ $CURRENT_EPOCH -ge $TARGET_EPOCH ]; then
        echo ""
        echo "[$(TZ="Asia/Kolkata" date '+%Y-%m-%d %H:%M:%S')] Target time reached!"
        
        # 1. Stop via systemd user manager to prevent GNOME Session from auto-restarting the application.
        # We use --no-block to prevent our script from hanging on stubborn Electron processes.
        echo "Telling systemd/GNOME to stop matching application scopes..."
        SYSTEMD_UNITS=$(systemctl --user list-units --all --no-legend | grep -i "$PROCESS_NAME" | awk '{print $1}')
        if [ -n "$SYSTEMD_UNITS" ]; then
            echo "Stopping systemd units: $SYSTEMD_UNITS"
            systemctl --user stop --no-block $SYSTEMD_UNITS 2>/dev/null
            sleep 0.5
        fi

        # 2. Loop up to 8 times to ensure all remaining/stubborn/newly spawned processes are dead
        PROCESS_KILLED=false
        for attempt in {1..8}; do
            # Find all process IDs matching the process name case-insensitively
            # Excluding grep, the script itself, and common utilities
            PIDS=$(pgrep -f -i "$PROCESS_NAME" | grep -v "$$" | grep -v "$PPID")
            
            if [ -n "$PARENT_PID" ]; then
                # Also exclude the parent script from process list to avoid double killing it here
                PIDS=$(echo "$PIDS" | grep -v "$PARENT_PID")
            fi
            
            # Flatten PIDs to a space-separated string
            PIDS=$(echo $PIDS)

            if [ -z "$PIDS" ]; then
                if [ "$PROCESS_KILLED" = true ]; then
                    echo "All processes matching '$PROCESS_NAME' have been successfully terminated."
                else
                    echo "No running processes found matching '$PROCESS_NAME'."
                fi
                break
            fi
            
            PROCESS_KILLED=true
            echo "Found PIDs matching '$PROCESS_NAME' (Attempt $attempt/8): $PIDS"
            if [ $attempt -eq 1 ]; then
                echo "Attempting graceful termination (SIGTERM)..."
                kill -15 $PIDS 2>/dev/null
            else
                echo "Forcefully killing remaining/newly-spawned processes (SIGKILL)..."
                if [ -n "$SUDO_PASS" ]; then
                    echo "$SUDO_PASS" | sudo -S kill -9 $PIDS 2>/dev/null
                else
                    kill -9 $PIDS 2>/dev/null
                fi
            fi
            sleep 1.0
        done

        # Close the parent script if specified
        if [ -n "$PARENT_PID" ]; then
            if kill -0 "$PARENT_PID" 2>/dev/null; then
                echo "Terminating parent script (PID: $PARENT_PID)..."
                # Send SIGTERM to allow parent to run its cleanup trap
                kill -15 "$PARENT_PID" 2>/dev/null
            else
                echo "Parent script (PID: $PARENT_PID) is not running."
            fi
        fi

        break
    fi
    sleep 5
done

echo "Done."
