#!/bin/bash
# Fix the update_ssh_keys.sh script on the bastion host
set -e

# Run a series of commands to fix the update_ssh_keys.sh script
echo "Fixing the update_ssh_keys.sh script on the bastion host..."

# Command 1: Fix the GitHub URL variable
echo "1. Fixing the GitHub URL variable..."
ssh -i /tmp/bastion_key ubuntu@52.91.240.160 "sudo sed -i 's|^GITHUB_REPO_URL=.*|GITHUB_REPO_URL=\$(cat /etc/ssh/github_repo_url)|' /usr/local/bin/update_ssh_keys.sh"

# Command 2: Fix the curl command
echo "2. Fixing the curl command..."
ssh -i /tmp/bastion_key ubuntu@52.91.240.160 "sudo sed -i 's|curl -s -f -L -o /tmp/\$KEYS_FILE_NAME \"\$GITHUB_REPO_URL\"|curl -s -f -L -o /tmp/\$KEYS_FILE_NAME \"\$GITHUB_REPO_URL\"|' /usr/local/bin/update_ssh_keys.sh"

# Command 3: Fix the log message
echo "3. Fixing the log message..."
ssh -i /tmp/bastion_key ubuntu@52.91.240.160 "sudo sed -i 's|log \"Fetching keys from \"|log \"Fetching keys from \$GITHUB_REPO_URL\"|' /usr/local/bin/update_ssh_keys.sh"

# Command 4: Create the log directory
echo "4. Creating the log directory..."
ssh -i /tmp/bastion_key ubuntu@52.91.240.160 "sudo mkdir -p /var/log && sudo touch /var/log/ssh_key_updates.log && sudo chmod 644 /var/log/ssh_key_updates.log"

# Command 5: Run the fixed script
echo "5. Running the fixed script..."
ssh -i /tmp/bastion_key ubuntu@52.91.240.160 "sudo bash /usr/local/bin/update_ssh_keys.sh"

echo "SSH key management fix completed"
