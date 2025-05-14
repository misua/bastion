#!/bin/bash
# Script to add audit functionality to the bastion host

# Install auditd if not already installed
apt-get update
apt-get install -y auditd

# Configure audit rules for SSH session tracking
cat > /etc/audit/rules.d/ssh-session-tracking.rules << 'EOF'
# Track SSH sessions
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/ssh/ssh_config -p wa -k ssh_config
-w /etc/ssh/session_mappings -p wa -k ssh_sessions
-w /var/log/auth.log -p r -k ssh_auth_log
EOF

# Restart auditd to apply new rules
systemctl restart auditd

# Create key mapping script
cat > /usr/local/bin/update_key_mappings.sh << 'EOF'
#!/bin/bash

# Create directories
mkdir -p /etc/ssh/key_mapping
mkdir -p /etc/ssh/session_mappings
chmod 1777 /etc/ssh/session_mappings

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
      echo "Mapped key $fingerprint to $identifier"
    fi
  fi
done < /etc/ssh/authorized_keys
EOF

chmod +x /usr/local/bin/update_key_mappings.sh

# Create SSH RC script
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
/usr/local/bin/update_key_mappings.sh

# Update the download_keys.sh script to also update key mappings
sed -i '/systemctl restart sshd/i\  # Update key mappings\n  /usr/local/bin/update_key_mappings.sh' /usr/local/bin/download_keys.sh

echo "Audit functionality has been added to the bastion host."
echo "You can now use the following commands:"
echo "  - /usr/local/bin/search-by-email.sh <email> : Search for SSH sessions by email"
echo "  - /usr/local/bin/update_key_mappings.sh : Update key mappings manually"
