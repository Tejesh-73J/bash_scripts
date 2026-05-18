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
            echo "No running processes found matching '$PROCESS_NAME'."
        else
            echo "Found PIDs matching '$PROCESS_NAME': $PIDS"
            
            # Try normal kill first (since teamlogger/whatsapp run as the user)
            echo "Attempting to terminate process(es)..."
            kill -15 $PIDS 2>/dev/null
            sleep 1
            
            # Force kill if still running
            STUBBORN_PIDS=""
            for PID in $PIDS; do
                if kill -0 "$PID" 2>/dev/null; then
                    STUBBORN_PIDS="$STUBBORN_PIDS $PID"
                fi
            done
            
            if [ -n "$STUBBORN_PIDS" ]; then
                echo "Force-killing stubborn process(es):$STUBBORN_PIDS..."
                if [ -n "$SUDO_PASS" ]; then
                    echo "$SUDO_PASS" | sudo -S kill -9 $STUBBORN_PIDS 2>/dev/null
                else
                    kill -9 $STUBBORN_PIDS 2>/dev/null
                fi
            fi
            echo "Process termination complete."
        fi

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
