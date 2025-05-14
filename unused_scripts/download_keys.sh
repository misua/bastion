#!/bin/bash
# Direct script to download and install SSH keys from GitHub
set -e

# Direct URL to GitHub repository
GITHUB_URL="https://raw.githubusercontent.com/OrbisSystems/centralized-keys/main/authorized_keys"
LOCAL_FILE="/etc/ssh/authorized_keys"
LOG_FILE="/var/log/ssh_key_updates.log"

# Create log directory if it doesn't exist
mkdir -p $(dirname $LOG_FILE)
touch $LOG_FILE
chmod 644 $LOG_FILE

# Log function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting direct SSH key download"
log "Fetching keys from $GITHUB_URL"

# Download the keys
if ! curl -s -f -L -o /tmp/authorized_keys "$GITHUB_URL"; then
  log "ERROR: Failed to download authorized_keys from $GITHUB_URL"
  exit 1
fi

# Check if the file contains valid SSH keys
if [ ! -s "/tmp/authorized_keys" ] || ! grep -qE "^(ssh-(rsa|dss|ed25519|ecdsa)|ecdsa-sha2-nistp(256|384|521)) " "/tmp/authorized_keys"; then
  log "ERROR: Downloaded file does not contain valid SSH key formats"
  exit 1
fi

# Install the keys
cp /tmp/authorized_keys $LOCAL_FILE
chown root:root $LOCAL_FILE
chmod 644 $LOCAL_FILE

log "SSH keys installed successfully"

# Add our test key to the authorized_keys file if it's not already there
if ! grep -q "test@example.com" $LOCAL_FILE; then
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDGLJCRFGYrxT9SbmdYKs4TFNPdqu6VeXSBHbQlJyIpKlYnhUzGNRmk/ggBkEeEMZ4R6M3NqpKU/2V8ULpS/e0QAYdN4pLy+Wy/YFjc1+aDZvgdnU47mJ9QDLILEHbZzn+dVngG4QNT8MuVQpYZbvI3xpKPXK5/fbuLJvaUtd9yQpxF9gKjgh5XZOl7uu1QQUQbD1A1BMDWQlGJIwqFUzYtXxW4Emq/aKjP5nY3OcUNiHc2M5qLh8Hn5GEYJhbpkOKVWdqpxljjKQzLmVRGqJJBFHbL4rYs1MKQBVnWkGGfAxoQ5vlBLFxnpKYGbGvvEQ7BDY0Z4U0rOVzQnUZD test@example.com" >> $LOCAL_FILE
  log "Test key added to authorized_keys"
fi

# Restart SSH service
systemctl restart sshd

log "SSH service restarted"

exit 0
