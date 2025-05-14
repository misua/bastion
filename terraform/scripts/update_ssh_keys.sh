#!/bin/bash
set -e

# Configuration
GITHUB_REPO_URL_VAR="${github_repo_url}"
KEYS_FILE_NAME="authorized_keys"
LOCAL_FILE="/etc/ssh/authorized_keys"
LOG_FILE="/var/log/ssh_key_updates.log"

# Log function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a $LOG_FILE
}

log "Starting SSH key update"

# Fetch the authorized_keys file from GitHub
log "Fetching keys from $GITHUB_REPO_URL_VAR"
# Use curl with fail-early, silent, and location-follow options
if ! curl -s -f -L -o /tmp/$KEYS_FILE_NAME $GITHUB_REPO_URL_VAR; then
  log "ERROR: Failed to download authorized_keys from $GITHUB_REPO_URL_VAR (curl exit code: $?)"
  # Exit if download fails to prevent wiping keys on transient network issues
  exit 1
fi

# Verify it's not empty and looks like SSH keys
# Improved grep pattern for various key types
if [ ! -s "/tmp/$KEYS_FILE_NAME" ] || ! grep -qE '^(ssh-(rsa|dss|ed25519|ecdsa)|ecdsa-sha2-nistp(256|384|521)) ' "/tmp/$KEYS_FILE_NAME"; then
  log "ERROR: Downloaded file /tmp/$KEYS_FILE_NAME is empty or doesn't contain valid SSH key formats. Aborting update."
  rm -f /tmp/$KEYS_FILE_NAME
  exit 1
fi

# Make immutable flag removable if set before comparison/copy
IMMUTABLE_SET=false
if command -v chattr &>/dev/null && [ -f "$LOCAL_FILE" ]; then
    if lsattr "$LOCAL_FILE" 2>/dev/null | grep -q -- '-i-'; then
        log "Making $LOCAL_FILE mutable before update."
        sudo chattr -i "$LOCAL_FILE"
        IMMUTABLE_SET=true # Remember that we need to re-apply it
    fi
fi

# Compare with current file to see if update is needed
if [ -f "$LOCAL_FILE" ] && cmp -s "/tmp/$KEYS_FILE_NAME" "$LOCAL_FILE"; then
  log "No changes detected in authorized_keys"
  # Re-apply immutable flag if it was removed
  if [ "$IMMUTABLE_SET" = true ] && command -v chattr &>/dev/null; then
     sudo chattr +i "$LOCAL_FILE" 2>/dev/null || true
     log "Re-applied immutable flag to $LOCAL_FILE."
  fi
  rm -f /tmp/$KEYS_FILE_NAME
  exit 0
fi

log "Changes detected. Updating $LOCAL_FILE."

# Back up current file if it exists
if [ -f "$LOCAL_FILE" ]; then
  BACKUP_FILE="$LOCAL_FILE.$(date +%Y%m%d%H%M%S).bak"
  log "Backing up current keys to $BACKUP_FILE"
  sudo cp "$LOCAL_FILE" "$BACKUP_FILE"
fi

# Update the authorized_keys file
sudo cp "/tmp/$KEYS_FILE_NAME" "$LOCAL_FILE"
sudo chown root:root "$LOCAL_FILE"
sudo chmod 644 "$LOCAL_FILE"

# Make immutable to prevent local changes
if command -v chattr &>/dev/null; then
  log "Making $LOCAL_FILE immutable."
  sudo chattr +i "$LOCAL_FILE" 2>/dev/null || true # Use sudo here too
fi

log "SSH keys updated successfully"

# Restart SSH service if keys changed
log "Restarting SSH service (sshd)"
sudo systemctl restart sshd
log "SSH service restart command issued."

# Clean up
rm -f /tmp/$KEYS_FILE_NAME

exit 0
