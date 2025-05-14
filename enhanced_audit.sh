#!/bin/bash
# Enhanced audit script with immutable flag protection

# Log function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/ssh_key_updates.log
}

log "Starting enhanced audit setup"

# Install auditd if not already installed
log "Installing auditd"
apt-get update
apt-get install -y auditd

# Configure audit rules for SSH session tracking
log "Configuring audit rules"
cat > /etc/audit/rules.d/ssh-session-tracking.rules << 'EOF'
# Track SSH sessions
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/ssh/ssh_config -p wa -k ssh_config
-w /etc/ssh/session_mappings -p wa -k ssh_sessions
-w /var/log/auth.log -p r -k ssh_auth_log
EOF

# Restart auditd to apply new rules
log "Restarting auditd"
systemctl restart auditd

# Create key mapping script with immutable flag handling
log "Creating key mapping script"
cat > /usr/local/bin/update_key_mappings.sh << 'EOF'
#!/bin/bash

# Log function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/ssh_key_updates.log
}

# Create directories
mkdir -p /etc/ssh/key_mapping
mkdir -p /etc/ssh/session_mappings
chmod 1777 /etc/ssh/session_mappings

log "Starting key mapping update"

# Process keys for mapping
rm -f /etc/ssh/key_mapping/*
while read -r line; do
  if [[ "$line" == ssh-* ]] || [[ "$line" == ecdsa-* ]]; then
    # Get fingerprint
    key_data=$(echo "$line" | cut -d " " -f 1-2)
    fingerprint=$(echo "$key_data" | ssh-keygen -lf - 2>/dev/null | cut -d " " -f 2 | sed "s/SHA256://")
    
    # Get email (last field)
    identifier=$(echo "$line" | rev | cut -d " " -f 1 | rev)
    
    # Create safe filename (replace / with _)
    safe_fp=$(echo "$fingerprint" | tr "/" "_")
    
    # Save mapping
    if [ -n "$identifier" ] && [ -n "$fingerprint" ]; then
      echo "$identifier" > "/etc/ssh/key_mapping/$safe_fp"
      log "Mapped key $fingerprint to $identifier"
    fi
  fi
done < /etc/ssh/authorized_keys

log "Key mapping update completed"
EOF

chmod +x /usr/local/bin/update_key_mappings.sh

# Create enhanced download script with immutable flag handling
log "Creating enhanced download script"
cat > /usr/local/bin/download_keys.sh << 'EOF'
#!/bin/bash

# Log function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/ssh_key_updates.log
}

log "Starting secure key update"

# Get GitHub credentials
TOKEN=$(cat /etc/github_token)
REPO_URL=$(cat /etc/github_repo_url)
FULL_URL=$(echo "$REPO_URL" | sed "s|https://|https://$TOKEN@|")

# Download keys to temporary file
log "Downloading keys from GitHub"
curl -s -f -L -o /tmp/keys "$FULL_URL"

if [ -s "/tmp/keys" ]; then
  log "Keys downloaded successfully"
  
  # Remove immutable attribute if it exists
  log "Removing immutable attribute from authorized_keys files"
  chattr -i /etc/ssh/authorized_keys 2>/dev/null
  chattr -i /home/ubuntu/.ssh/authorized_keys 2>/dev/null
  
  # Backup existing keys
  if [ -f "/etc/ssh/authorized_keys" ]; then
    cp /etc/ssh/authorized_keys /etc/ssh/authorized_keys.bak
  fi
  
  # Update system-wide keys
  log "Updating system-wide authorized_keys"
  mkdir -p /etc/ssh
  cp /tmp/keys /etc/ssh/authorized_keys
  chmod 644 /etc/ssh/authorized_keys
  
  # Update user keys
  log "Updating user authorized_keys"
  mkdir -p /home/ubuntu/.ssh
  cp /tmp/keys /home/ubuntu/.ssh/authorized_keys
  chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
  chmod 600 /home/ubuntu/.ssh/authorized_keys
  
  # Update key mappings
  log "Updating key mappings"
  /usr/local/bin/update_key_mappings.sh
  
  # Set immutable attribute
  log "Setting immutable attribute on authorized_keys files"
  chattr +i /etc/ssh/authorized_keys
  chattr +i /home/ubuntu/.ssh/authorized_keys
  
  # Clean up
  rm /tmp/keys
  
  # Restart SSH
  log "Restarting SSH service"
  systemctl restart sshd
  
  log "Key update completed successfully"
else
  log "ERROR: Downloaded file is empty or download failed"
fi
EOF

chmod +x /usr/local/bin/download_keys.sh

# Create SSH RC script
log "Creating SSH RC script"
cat > /etc/ssh/sshrc << 'EOF'
#!/bin/bash

# Log login with user info if available
if [ -n "$SSH_CONNECTION" ]; then
  CLIENT_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
  AUTH_LOG="/var/log/auth.log"

  if [ -f "$AUTH_LOG" ]; then
    # Try to get fingerprint
    FP=$(grep -a "Accepted publickey for.*from $CLIENT_IP" $AUTH_LOG | tail -1 | grep -o "SHA256:[a-zA-Z0-9+/]\\+" | head -1)
    FP=${FP#SHA256:}
    SAFE_FP=$(echo "$FP" | tr "/" "_")
    
    # Get user ID
    if [ -n "$SAFE_FP" ] && [ -f "/etc/ssh/key_mapping/$SAFE_FP" ]; then
      USER_ID=$(cat "/etc/ssh/key_mapping/$SAFE_FP")
    else
      USER_ID="$USER"
    fi
    
    # Log and create mapping
    logger -p auth.info "SSH LOGIN: User $USER_ID from $SSH_CLIENT session: $$"
    mkdir -p /etc/ssh/session_mappings
    echo "$USER_ID" > "/etc/ssh/session_mappings/$$"
    
    # Welcome message
    echo "Welcome $USER_ID"
  fi
fi
EOF

chmod +x /etc/ssh/sshrc

# Create search script
log "Creating search-by-email script"
cat > /usr/local/bin/search-by-email.sh << 'EOF'
#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <email>"
  exit 1
fi

EMAIL="$1"
SESSIONS=$(grep -l "$EMAIL" /etc/ssh/session_mappings/* 2>/dev/null | xargs -n1 basename 2>/dev/null)

if [ -n "$SESSIONS" ]; then
  echo "Found sessions: $SESSIONS"
  for S in $SESSIONS; do
    echo "=== Session $S ==="
    grep "session: $S" /var/log/auth.log
  done
else
  echo "No sessions found for $EMAIL"
fi
EOF

chmod +x /usr/local/bin/search-by-email.sh

# Run the key mapping script
log "Running initial key mapping"
/usr/local/bin/update_key_mappings.sh

# Update the cron job to use the new download script
log "Updating cron job"
(crontab -l 2>/dev/null | grep -v "download_keys.sh" || echo "") | { cat; echo "0 * * * * /usr/local/bin/download_keys.sh"; } | crontab -

# Set immutable flag on authorized_keys files
log "Setting immutable flag on authorized_keys files"
chattr +i /etc/ssh/authorized_keys
chattr +i /home/ubuntu/.ssh/authorized_keys

log "Enhanced audit setup completed"
echo "Audit functionality has been added to the bastion host with immutable flag protection."
echo "You can now use the following commands:"
echo "  - /usr/local/bin/search-by-email.sh <email> : Search for SSH sessions by email"
echo "  - /usr/local/bin/update_key_mappings.sh : Update key mappings manually"
echo "  - /usr/local/bin/download_keys.sh : Download keys from GitHub and update mappings"
