#!/bin/bash
# Test script for SSH key identifier functionality

# Set up test environment
echo "Setting up test environment..."
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR" || exit 1

# Create test files
mkdir -p etc/ssh/key_mapping
mkdir -p etc/ssh/session_mappings
mkdir -p usr/local/bin
mkdir -p var/log

# Create a test authorized_keys file
cat > etc/ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEiVBQXlvYq9JBowE9yiwZGCBQ7RRqYrZHOjliFGQNSk charles.pino@viewtrade.net
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCvJvz0fvXCLGXPkvuWwxMJ9QJ4qQCXQH9EfX9NLb3JGS6/pWnTKAvGIzO1TvpwQY2H5yv7y/iMVVQl8Xw4QAUQA+wULHhmZ5lKuJ+ugUkvl+9b8dY1xUhbvdvnlAcpkHcTuPPrVGm1jWvS4Xvx6DVFS5MTr5+GnH1JGzsQpFLK4SGgxqmECL0nDqVmdqhU0bbDrySF8P0jmXGUy5Lf1c5/NWgeLt0ByQHAKwbLmTUxNYYXvFPeqMvWUr7rjL0GBwKC6RicIJSdvpnTYEYxXi7tTwIKvbFEG8e6Kp4yUDUJBRUG98BnDT7LfDEaOBi/V3LsipPj6RtL4LMQRpMkdvbPJ/cBCyFh6wMwRZ/c+zDFPWJlnZvnlPjYUYwlYV+3MjOlxGJZSbKGKyGAiLTYlMnvOUZHGnJnMOm3KIKfUGtGIFLlxBIZ3OMHNjpzKO1J5mL8F1kybYYRBvQxgHCT9HBKVBgAH4oFcwdvwBjGD7lVPBRQn5I5ycmYQXK0+qs= jane.doe@example.com
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJlGEkxA+OJQhxjRxiMkRYvh+Vhuj7x+Lk5nKd5eX5tzAQnGvWqNhvL9bIXNjbCw2rR7+fs9eMhGl0HPyMJS4XVvRZa9J4wto6cgAGYYRvJ5DhVJ5GoqIcx8tfdwxDMNskLDNgG8jqYbZ4MLJZpqT8KgWHOTYCGFWk9A7j4yjYRLzLnxvE/2LJEw1IUx4qK1VD6oZJTjWVEh/TUFXVgUkLGe5jKwYQqDOSmJU6ev+uKUkYl6jbNJa+kUJCFp8rvCKK3zHbiHX9MGGjQIfGCaIJUhVka8oLnUjnKQZNUkA/yDKOC6QJMvkqVFpQYS5LEaXQEmvVIUUHnOLOKQjlxjR6Jf3BPzq0VvZJJbCxrxDLzZ3xUCcSR9sMrCy0eHSRlhMMKMQiQZNvTkYT7Exg5SZOJfnnvgyWYkCo4I9KrCQQwfiBxzWDDGhgP1+ghvC7k5UyETfZMPGTCVRIV8yDKjOmVg+aK7LLjXt0ZEh1Ht+NRVd3YmOF9ZcCH0E+9Yk= john.smith@example.org
EOF

# Create a standalone test function for key identifier extraction
cat > usr/local/bin/test_extract_key_identifiers.sh << 'EOF'
#!/bin/bash

# Function to extract identifiers from authorized_keys
extract_key_identifiers() {
  local auth_keys_file="./etc/ssh/authorized_keys"
  local mapping_file="./etc/ssh/key_mapping/fingerprint_to_user.txt"
  
  # Clear existing mapping
  rm -f "$mapping_file"
  touch "$mapping_file"
  chmod 644 "$mapping_file"
  
  # Process each line in authorized_keys
  while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" == \#* ]]; then
      continue
    fi
    
    # Use a simpler approach - just write the entire line to the temp file
    # This preserves the exact format expected by ssh-keygen
    echo "$line" > ./tmp_key.pub
    
    # Get the fingerprint, suppressing errors
    fingerprint=$(ssh-keygen -lf ./tmp_key.pub 2>/dev/null | awk '{print $2}')
    if [ -z "$fingerprint" ]; then
      fingerprint="FINGERPRINT_UNAVAILABLE"
    fi
    
    # Extract the comment/email (usually at the end of the line)
    identifier=$(echo "$line" | awk '{print $NF}')
    
    # If identifier looks like a valid email or username
    if [[ "$identifier" == *@* || "$identifier" =~ ^[a-zA-Z0-9._-]+$ ]]; then
      echo "$fingerprint $identifier" >> "$mapping_file"
      echo "Mapped fingerprint $fingerprint to user $identifier"
    else
      echo "No valid identifier found for key with fingerprint $fingerprint"
    fi
  done < "$auth_keys_file"
  
  # Clean up
  rm -f ./tmp_key.pub
}

# Run the function
extract_key_identifiers

# Test results
echo ""
echo "=== Test Results ==="
if [ -s "./etc/ssh/key_mapping/fingerprint_to_user.txt" ]; then
  echo "PASS: Fingerprint mapping file was created"
  echo "Contents:"
  cat "./etc/ssh/key_mapping/fingerprint_to_user.txt"
  
  # Check if all identifiers were extracted
  EXPECTED_COUNT=3
  ACTUAL_COUNT=$(wc -l < "./etc/ssh/key_mapping/fingerprint_to_user.txt")
  
  if [ "$ACTUAL_COUNT" -eq "$EXPECTED_COUNT" ]; then
    echo "PASS: All $EXPECTED_COUNT identifiers were extracted"
  else
    echo "FAIL: Expected $EXPECTED_COUNT identifiers, but found $ACTUAL_COUNT"
  fi
else
  echo "FAIL: Fingerprint mapping file was not created or is empty"
fi
EOF

# Make the test script executable
chmod +x usr/local/bin/test_extract_key_identifiers.sh

# Run the test
echo "Running tests..."
./usr/local/bin/test_extract_key_identifiers.sh

# Clean up
echo "Cleaning up..."
cd /
rm -rf "$TEST_DIR"

echo "Tests completed."
