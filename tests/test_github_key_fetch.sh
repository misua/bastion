#!/bin/bash
# Test script for GitHub SSH key fetching functionality

# Set up test environment
echo "Setting up test environment..."
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR" || exit 1

# Create test directories
mkdir -p etc/ssh
mkdir -p usr/local/bin
mkdir -p home/ubuntu/.ssh

# Create a mock GitHub API response for testing
cat > github_keys_response.json << 'EOF'
{
  "name": "authorized_keys",
  "path": "authorized_keys",
  "sha": "abc123def456",
  "size": 747,
  "url": "https://api.github.com/repos/test/repo/contents/authorized_keys?ref=main",
  "html_url": "https://github.com/test/repo/blob/main/authorized_keys",
  "git_url": "https://api.github.com/repos/test/repo/git/blobs/abc123def456",
  "download_url": "https://raw.githubusercontent.com/test/repo/main/authorized_keys",
  "type": "file",
  "content": "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUVWN1ZkMGRaMnBMUWxOaFdYTlhiMlJhVUVwT1ZVNUJOMWt6TUZwRVFsQk9JR2RwZEdodVluVnpRR1Y0WVcxd2JHVXVZMjl0Cg==",
  "encoding": "base64",
  "_links": {
    "self": "https://api.github.com/repos/test/repo/contents/authorized_keys?ref=main",
    "git": "https://api.github.com/repos/test/repo/git/blobs/abc123def456",
    "html": "https://github.com/test/repo/blob/main/authorized_keys"
  }
}
EOF

# Create a test update_ssh_keys.sh script
cat > usr/local/bin/update_ssh_keys.sh << 'EOF'
#!/bin/bash
# Test script for updating SSH keys from GitHub

# Mock curl function to return our test response
curl() {
  # Check if this is a GitHub API call
  if [[ "$*" == *"api.github.com"* ]]; then
    cat ./github_keys_response.json
    return 0
  else
    echo "Unexpected curl call: $*"
    return 1
  fi
}

# Mock jq function to extract content
jq() {
  # Check if this is extracting the content field
  if [[ "$*" == *".content"* ]]; then
    grep -o '"content": "[^"]*"' ./github_keys_response.json | cut -d'"' -f4
    return 0
  else
    echo "Unexpected jq call: $*"
    return 1
  fi
}

# Function to update SSH keys from GitHub
update_ssh_keys() {
  local github_token="test_token"
  local github_repo_url="https://api.github.com/repos/test/repo"
  local auth_keys_file="./etc/ssh/authorized_keys"
  local ubuntu_auth_keys="./home/ubuntu/.ssh/authorized_keys"
  
  echo "Updating SSH keys from GitHub..."
  
  # Ensure directories exist
  mkdir -p ./etc/ssh
  mkdir -p ./home/ubuntu/.ssh
  
  # Create a backup of the current authorized_keys file if it exists
  if [ -f "$auth_keys_file" ]; then
    cp "$auth_keys_file" "${auth_keys_file}.bak"
    echo "Backed up existing authorized_keys file"
  fi
  
  # Fetch the authorized_keys file from GitHub
  echo "Fetching authorized_keys from GitHub..."
  local github_response=$(curl -s -H "Authorization: token $github_token" "${github_repo_url}/contents/authorized_keys")
  
  # Check if the response contains an error message
  if [[ "$github_response" == *"Bad credentials"* ]]; then
    echo "ERROR: GitHub API authentication failed. Check your token."
    return 1
  fi
  
  if [[ "$github_response" == *"Not Found"* ]]; then
    echo "ERROR: authorized_keys file not found in the repository."
    return 1
  fi
  
  # Extract the content (base64 encoded)
  local encoded_content=$(echo "$github_response" | jq -r '.content')
  
  if [ -z "$encoded_content" ]; then
    echo "ERROR: Failed to extract content from GitHub response."
    return 1
  fi
  
  # Decode the content
  local decoded_content=$(echo "$encoded_content" | base64 -d)
  
  if [ -z "$decoded_content" ]; then
    echo "ERROR: Failed to decode content."
    return 1
  fi
  
  # Write the content to the authorized_keys file
  echo "$decoded_content" > "$auth_keys_file"
  chmod 644 "$auth_keys_file"
  
  # Also update the ubuntu user's authorized_keys file
  cp "$auth_keys_file" "$ubuntu_auth_keys"
  chown ubuntu:ubuntu "$ubuntu_auth_keys"
  chmod 600 "$ubuntu_auth_keys"
  
  echo "SSH keys updated successfully."
  return 0
}

# Run the update function
update_ssh_keys

# Verify the results
echo ""
echo "=== Test Results ==="
if [ -f "./etc/ssh/authorized_keys" ]; then
  echo "PASS: authorized_keys file was created in /etc/ssh/"
  echo "Contents:"
  cat "./etc/ssh/authorized_keys"
else
  echo "FAIL: authorized_keys file was not created in /etc/ssh/"
fi

if [ -f "./home/ubuntu/.ssh/authorized_keys" ]; then
  echo "PASS: authorized_keys file was created in ubuntu user's .ssh directory"
else
  echo "FAIL: authorized_keys file was not created in ubuntu user's .ssh directory"
fi

# Check if any SSH key was properly decoded
if grep -q "ssh-" "./etc/ssh/authorized_keys"; then
  echo "PASS: SSH keys were properly decoded and added"
  echo "Content of authorized_keys:"
  cat "./etc/ssh/authorized_keys"
else
  echo "FAIL: No SSH keys were found in the authorized_keys file"
fi
EOF

# Make the test script executable
chmod +x usr/local/bin/update_ssh_keys.sh

# Run the test
echo "Running tests..."
./usr/local/bin/update_ssh_keys.sh

# Clean up
echo "Cleaning up..."
cd /
rm -rf "$TEST_DIR"

echo "Tests completed."
