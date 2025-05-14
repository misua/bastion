#!/bin/bash
# Bastion Host Diagnostic Script
# This script checks the SSH key management system on the bastion host

# Function to print section headers
print_header() {
  echo "===== $1 ====="
}

# Check if we're running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script should be run as root for full diagnostics."
  echo "Running with limited capabilities..."
fi

# Check system logs for user data script execution
print_header "User Data Script Logs"
if [ -f /var/log/bastion_userdata.log ]; then
  echo "User data log exists. Last 20 lines:"
  tail -n 20 /var/log/bastion_userdata.log
else
  echo "User data log not found at /var/log/bastion_userdata.log"
fi

# Check cloud-init logs
print_header "Cloud-Init Logs"
if [ -f /var/log/cloud-init.log ]; then
  echo "Cloud-init log exists. Last 20 lines:"
  tail -n 20 /var/log/cloud-init.log
else
  echo "Cloud-init log not found at /var/log/cloud-init.log"
fi

# Check SSH key update logs
print_header "SSH Key Update Logs"
if [ -f /var/log/ssh_key_updates.log ]; then
  echo "SSH key update log exists. Last 20 lines:"
  tail -n 20 /var/log/ssh_key_updates.log
else
  echo "SSH key update log not found at /var/log/ssh_key_updates.log"
fi

# Check authorized_keys file
print_header "Authorized Keys"
if [ -f /etc/ssh/authorized_keys ]; then
  echo "Authorized keys file exists at /etc/ssh/authorized_keys"
  echo "File permissions: $(ls -la /etc/ssh/authorized_keys)"
  echo "Number of keys: $(grep -c "^ssh-" /etc/ssh/authorized_keys)"
else
  echo "Authorized keys file not found at /etc/ssh/authorized_keys"
fi

# Check SSH configuration
print_header "SSH Configuration"
if [ -f /etc/ssh/sshd_config ]; then
  echo "SSH config exists. Checking for authorized keys file configuration:"
  grep -i "AuthorizedKeysFile" /etc/ssh/sshd_config
else
  echo "SSH config not found at /etc/ssh/sshd_config"
fi

# Check SSH key mapping directory
print_header "SSH Key Mapping"
if [ -d /etc/ssh/key_mapping ]; then
  echo "Key mapping directory exists at /etc/ssh/key_mapping"
  echo "Directory permissions: $(ls -la /etc/ssh/ | grep key_mapping)"
  echo "Number of mappings: $(ls -la /etc/ssh/key_mapping | wc -l)"
else
  echo "Key mapping directory not found at /etc/ssh/key_mapping"
fi

# Check session mappings directory
print_header "Session Mappings"
if [ -d /etc/ssh/session_mappings ]; then
  echo "Session mappings directory exists at /etc/ssh/session_mappings"
  echo "Directory permissions: $(ls -la /etc/ssh/ | grep session_mappings)"
else
  echo "Session mappings directory not found at /etc/ssh/session_mappings"
fi

# Check if update_ssh_keys.sh script exists
print_header "Update SSH Keys Script"
if [ -f /usr/local/bin/update_ssh_keys.sh ]; then
  echo "Update SSH keys script exists at /usr/local/bin/update_ssh_keys.sh"
  echo "File permissions: $(ls -la /usr/local/bin/update_ssh_keys.sh)"
else
  echo "Update SSH keys script not found at /usr/local/bin/update_ssh_keys.sh"
fi

# Check cron jobs for key updates
print_header "Cron Jobs"
if command -v crontab &> /dev/null; then
  echo "Checking for cron jobs related to SSH key updates:"
  crontab -l 2>/dev/null | grep -i ssh || echo "No user cron jobs found for SSH key updates"
  if [ -f /etc/crontab ]; then
    grep -i ssh /etc/crontab || echo "No system cron jobs found for SSH key updates"
  fi
else
  echo "Crontab command not found"
fi

# Check GitHub repository URL configuration
print_header "GitHub Repository URL"
if [ -f /etc/ssh/github_repo_url ]; then
  echo "GitHub repo URL file exists at /etc/ssh/github_repo_url"
  echo "Contents: $(cat /etc/ssh/github_repo_url)"
else
  echo "GitHub repo URL file not found at /etc/ssh/github_repo_url"
fi

# Check for curl and jq which are needed for GitHub API access
print_header "Required Tools"
echo "curl: $(command -v curl || echo 'Not installed')"
echo "jq: $(command -v jq || echo 'Not installed')"

# Check network connectivity to GitHub
print_header "GitHub Connectivity"
if command -v curl &> /dev/null; then
  echo "Testing connection to GitHub:"
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://api.github.com || echo "Failed to connect to GitHub"
else
  echo "curl not installed, cannot test GitHub connectivity"
fi

# Check the sshrc script
print_header "SSH RC Script"
if [ -f /etc/ssh/sshrc ]; then
  echo "SSH RC script exists at /etc/ssh/sshrc"
  echo "File permissions: $(ls -la /etc/ssh/sshrc)"
  echo "Contents:"
  cat /etc/ssh/sshrc
else
  echo "SSH RC script not found at /etc/ssh/sshrc"
fi

print_header "Diagnostic Complete"
echo "End of diagnostic script"
