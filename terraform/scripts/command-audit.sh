#!/bin/bash

# Prevent duplicate session logging if script is sourced multiple times
if [ -n "$SCRIPT_STARTED" ]; then
    return
fi

# Log only interactive sessions, not scripts or cron jobs
if [ -z "$PS1" ]; then
    return
fi

# Avoid logging for root user if desired (adjust logic as needed)
if [ "$(whoami)" = "root" ]; then
    # Consider if root actions should also be logged via script
    return
fi

# Define log file path
SESSION_LOG_DIR="/var/log/user-sessions"
LOG_FILE="$SESSION_LOG_DIR/$(whoami)-session-$(date +%Y%m%d_%H%M%S)-$.log"

# Ensure the directory exists and has correct permissions
# Note: Directory creation is handled earlier in user_data

# Start the 'script' command to capture TTY output
# -a: append to log file
# -q: quiet mode
# -f: flush output after each write
# -t=0: do not create timing file (or specify path like /tmp/timing.$.log)
export SCRIPT_STARTED=1 # Mark that script has started
script -a -q -f "$LOG_FILE"

# Exit the parent shell process that sourced this script
# This is crucial so the user's shell doesn't terminate immediately
# Instead, 'script' command takes over the TTY
# The user's shell continues *inside* the 'script' session
