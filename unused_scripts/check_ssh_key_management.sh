#!/bin/bash
# Script to check the status of the SSH key management system on the bastion host

# Get the bastion host public IP from Terraform output
BASTION_IP=$(cd /Users/charles/Desktop/bastion/terraform && terraform output -raw bastion_public_ip)

echo "Connecting to bastion host at $BASTION_IP..."
echo "Checking SSH key management system status..."

# Use SSH to check the status of the SSH key management system
ssh -o StrictHostKeyChecking=no ubuntu@$BASTION_IP << 'EOF'
  echo "=== GitHub Repository URL ==="
  cat /etc/ssh/github_repo_url
  
  echo -e "\n=== Authorized Keys File ==="
  if [ -f "/etc/ssh/authorized_keys" ]; then
    ls -la /etc/ssh/authorized_keys
    echo "Content:"
    cat /etc/ssh/authorized_keys
  else
    echo "File does not exist"
  fi
  
  echo -e "\n=== SSH Key Mapping Directory ==="
  ls -la /etc/ssh/key_mapping/
  
  echo -e "\n=== SSH Key Update Log ==="
  if [ -f "/var/log/ssh_key_updates.log" ]; then
    cat /var/log/ssh_key_updates.log
  else
    echo "Log file does not exist"
  fi
  
  echo -e "\n=== Update SSH Keys Script ==="
  cat /usr/local/bin/update_ssh_keys.sh
EOF

echo "Check complete."
