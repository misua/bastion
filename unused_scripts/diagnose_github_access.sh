#!/bin/bash
# Script to diagnose GitHub access from the bastion host

# Get the bastion host public IP from Terraform output
BASTION_IP=$(cd /Users/charles/Desktop/bastion/terraform && terraform output -raw bastion_public_ip)
echo "Bastion host public IP: $BASTION_IP"

# Create a diagnostic script to run on the bastion host
cat > /tmp/github_access_check.sh << 'EOF'
#!/bin/bash
set -e

# Function to print section headers
print_header() {
  echo -e "\n===== $1 ====="
}

# Check GitHub URL configuration
print_header "GitHub URL Configuration"
if [ -f /etc/ssh/github_repo_url ]; then
  echo "GitHub URL file exists:"
  cat /etc/ssh/github_repo_url
else
  echo "ERROR: GitHub URL file does not exist at /etc/ssh/github_repo_url"
fi

# Check update_ssh_keys.sh script
print_header "Update SSH Keys Script"
if [ -f /usr/local/bin/update_ssh_keys.sh ]; then
  echo "Script exists and has permissions:"
  ls -la /usr/local/bin/update_ssh_keys.sh
else
  echo "ERROR: Script does not exist at /usr/local/bin/update_ssh_keys.sh"
fi

# Test GitHub access directly
print_header "Direct GitHub Access Test"
GITHUB_URL=$(cat /etc/ssh/github_repo_url 2>/dev/null || echo "URL_NOT_FOUND")
echo "Testing access to: $GITHUB_URL"

# Try to download the file with curl
echo "Attempting to download with curl..."
if curl -s -f -L -o /tmp/test_keys "$GITHUB_URL"; then
  echo "SUCCESS: File downloaded successfully"
  echo "File content:"
  cat /tmp/test_keys
  rm /tmp/test_keys
else
  echo "ERROR: Failed to download file from GitHub"
  echo "Testing with verbose output:"
  curl -v -L "$GITHUB_URL" 2>&1 | grep -v "Authorization:"
fi

# Check if authorized_keys file exists
print_header "Authorized Keys File"
if [ -f /etc/ssh/authorized_keys ]; then
  echo "File exists and has permissions:"
  ls -la /etc/ssh/authorized_keys
  echo "Content:"
  cat /etc/ssh/authorized_keys
else
  echo "ERROR: File does not exist at /etc/ssh/authorized_keys"
fi

# Check SSH key update logs
print_header "SSH Key Update Logs"
if [ -f /var/log/ssh_key_updates.log ]; then
  echo "Log file exists:"
  cat /var/log/ssh_key_updates.log
else
  echo "Log file does not exist at /var/log/ssh_key_updates.log"
fi

# Run the update script manually to see if it works
print_header "Manual Update Script Execution"
echo "Running update_ssh_keys.sh manually..."
if [ -x /usr/local/bin/update_ssh_keys.sh ]; then
  sudo /usr/local/bin/update_ssh_keys.sh
  echo "Exit code: $?"
else
  echo "ERROR: Cannot execute update_ssh_keys.sh (not found or not executable)"
fi

# Check if the script ran successfully
print_header "Post-Update Check"
if [ -f /etc/ssh/authorized_keys ]; then
  echo "Authorized keys file after update:"
  ls -la /etc/ssh/authorized_keys
  echo "Content:"
  cat /etc/ssh/authorized_keys
else
  echo "ERROR: Still no authorized_keys file after update attempt"
fi
EOF

# Copy the diagnostic script to the bastion host and run it
echo "Copying diagnostic script to bastion host..."
scp -o StrictHostKeyChecking=no /tmp/github_access_check.sh ubuntu@$BASTION_IP:/tmp/

echo "Running diagnostic script on bastion host..."
ssh -o StrictHostKeyChecking=no ubuntu@$BASTION_IP "chmod +x /tmp/github_access_check.sh && sudo /tmp/github_access_check.sh"

echo "Diagnosis complete."
