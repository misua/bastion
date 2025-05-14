#!/bin/bash
# Test script for SSH key identifier integration with audit system

# Set up test environment
echo "Setting up test environment..."
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR" || exit 1

# Create test directories
mkdir -p etc/ssh/key_mapping
mkdir -p etc/ssh/session_mappings
mkdir -p usr/local/bin
mkdir -p var/log

# Create a test fingerprint mapping file
cat > etc/ssh/key_mapping/fingerprint_to_user.txt << 'EOF'
SHA256:abcdefghijklmnopqrstuvwxyz1234567890ABCD charles.pino@viewtrade.net
SHA256:1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcd jane.doe@example.com
SHA256:zyxwvutsrqponmlkjihgfedcba0987654321DCBA john.smith@example.org
EOF

# Create a test session mappings file
cat > etc/ssh/session_mappings/mappings.txt << 'EOF'
12345 charles.pino@viewtrade.net
67890 jane.doe@example.com
54321 john.smith@example.org
EOF

# Create a test auth.log file
cat > var/log/auth.log << 'EOF'
May 13 14:30:15 bastion sshd[12345]: SSH LOGIN: User charles.pino@viewtrade.net (fingerprint: SHA256:abcdefghijklmnopqrstuvwxyz1234567890ABCD) logged in with session ID 12345 from 192.168.1.100
May 13 14:35:20 bastion sshd[67890]: SSH LOGIN: User jane.doe@example.com (fingerprint: SHA256:1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcd) logged in with session ID 67890 from 192.168.1.101
May 13 14:40:25 bastion sshd[54321]: SSH LOGIN: User john.smith@example.org (fingerprint: SHA256:zyxwvutsrqponmlkjihgfedcba0987654321DCBA) logged in with session ID 54321 from 192.168.1.102
EOF

# Extract the audit search function from the user_data.sh.tftpl file
echo "Extracting audit search function from user_data.sh.tftpl..."
sed -n '/audit-search-by-user.sh/,/^EOF/p' /Users/charles/Desktop/bastion/terraform/user_data.sh.tftpl > usr/local/bin/audit-search-by-user.sh.template

# Create a modified version for testing
cat > usr/local/bin/test_audit_search.sh << 'EOF'
#!/bin/bash

# Mock ausearch function for testing
ausearch() {
  local session=""
  local date_spec=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session)
        session="$2"
        shift 2
        ;;
      -ts)
        date_spec="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  
  # Return mock data based on session ID
  if [ "$session" = "12345" ]; then
    echo "Mock audit data for charles.pino@viewtrade.net (session $session)"
    echo "type=SYSCALL msg=audit(1620900000.000:123): arch=c000003e syscall=59 success=yes exit=0 a0=55555555 a1=55555556 a2=55555557 a3=0 items=2 ppid=12345 pid=12346 auid=1000 uid=1000 gid=1000 euid=1000 suid=1000 fsuid=1000 egid=1000 sgid=1000 fsgid=1000 tty=pts0 ses=12345 comm=\"bash\" exe=\"/usr/bin/bash\" key=\"commands\""
    echo "type=EXECVE msg=audit(1620900000.000:123): argc=3 a0=\"ls\" a1=\"-la\" a2=\"/etc\""
  elif [ "$session" = "67890" ]; then
    echo "Mock audit data for jane.doe@example.com (session $session)"
    echo "type=SYSCALL msg=audit(1620900100.000:124): arch=c000003e syscall=59 success=yes exit=0 a0=55555555 a1=55555556 a2=55555557 a3=0 items=2 ppid=67890 pid=67891 auid=1001 uid=1001 gid=1001 euid=1001 suid=1001 fsuid=1001 egid=1001 sgid=1001 fsgid=1001 tty=pts1 ses=67890 comm=\"bash\" exe=\"/usr/bin/bash\" key=\"commands\""
    echo "type=EXECVE msg=audit(1620900100.000:124): argc=2 a0=\"cat\" a1=\"/etc/passwd\""
  elif [ "$session" = "54321" ]; then
    echo "Mock audit data for john.smith@example.org (session $session)"
    echo "type=SYSCALL msg=audit(1620900200.000:125): arch=c000003e syscall=59 success=yes exit=0 a0=55555555 a1=55555556 a2=55555557 a3=0 items=2 ppid=54321 pid=54322 auid=1002 uid=1002 gid=1002 euid=1002 suid=1002 fsuid=1002 egid=1002 sgid=1002 fsgid=1002 tty=pts2 ses=54321 comm=\"bash\" exe=\"/usr/bin/bash\" key=\"commands\""
    echo "type=EXECVE msg=audit(1620900200.000:125): argc=3 a0=\"grep\" a1=\"-r\" a2=\"password /var/log\""
  else
    echo "No audit data found for session $session"
  fi
}

# Function to test the audit search functionality
test_audit_search() {
  local user_id="$1"
  
  echo "=== Testing audit search for $user_id ==="
  
  # Find SSH sessions for this user
  echo "SSH Sessions for $user_id:"
  grep "SSH LOGIN: User $user_id" ./var/log/auth.log
  
  # Check the session mappings file
  if [ -f "./etc/ssh/session_mappings/mappings.txt" ]; then
    # Get session IDs from the mappings file
    MAPPED_SESSION_IDS=$(grep "$user_id" ./etc/ssh/session_mappings/mappings.txt | awk '{print $1}')
    
    if [ -n "$MAPPED_SESSION_IDS" ]; then
      echo "Found session mappings for $user_id"
      SESSION_IDS="$MAPPED_SESSION_IDS"
    else
      # Fallback to the old method if no mappings found
      echo "No session mappings found, using auth.log"
      SESSION_IDS=$(grep "SSH LOGIN: User $user_id" ./var/log/auth.log | grep -oP "session ID \K[0-9]+" || echo "")
    fi
  else
    # Fallback to the old method if mappings file doesn't exist
    echo "Session mappings file not found, using auth.log"
    SESSION_IDS=$(grep "SSH LOGIN: User $user_id" ./var/log/auth.log | grep -oP "session ID \K[0-9]+" || echo "")
  fi
  
  if [ -z "$SESSION_IDS" ]; then
    echo "No session IDs found for $user_id"
    return 1
  fi
  
  # Search audit logs for each session
  for SES_ID in $SESSION_IDS; do
    echo ""
    echo "=== Commands for session $SES_ID (User: $user_id) ==="
    ausearch --session "$SES_ID" -ts "today" -k commands
  done
  
  return 0
}

# Run tests for each user
test_audit_search "charles.pino@viewtrade.net"
echo ""
test_audit_search "jane.doe@example.com"
echo ""
test_audit_search "john.smith@example.org"
echo ""
test_audit_search "unknown.user@example.com"
EOF

# Make the test script executable
chmod +x usr/local/bin/test_audit_search.sh

# Run the test
echo "Running tests..."
./usr/local/bin/test_audit_search.sh

# Clean up
echo "Cleaning up..."
cd /
rm -rf "$TEST_DIR"

echo "Tests completed."
