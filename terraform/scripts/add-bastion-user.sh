#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Check if username is provided
if [ $# -lt 1 ]; then
  echo "Usage: $0 <username>" >&2
  exit 1
fi

USERNAME=$1

# Check if user already exists
if id "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' already exists." >&2
    exit 1
fi

# Create user with home directory and bash shell
echo "Creating user '$USERNAME'..."
useradd -m -s /bin/bash $USERNAME
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create user '$USERNAME'." >&2
    exit 1
fi

# Secure the .ssh directory immediately for the new user
USER_SSH_DIR="/home/$USERNAME/.ssh"
echo "Securing $USER_SSH_DIR..."
mkdir -p "$USER_SSH_DIR"
chown $USERNAME:$USERNAME "$USER_SSH_DIR"
chmod 700 "$USER_SSH_DIR"

if command -v chattr &>/dev/null; then
    chattr +i "$USER_SSH_DIR"
fi

echo "This directory is managed by the central SSH key system." > "$USER_SSH_DIR/README"
echo "Keys should be added through the GitHub repository." >> "$USER_SSH_DIR/README"
chown $USERNAME:$USERNAME "$USER_SSH_DIR/README"

echo "User '$USERNAME' created successfully."
echo "Their public key MUST be added to the GitHub repository via PR."
echo "Once merged, the key will be automatically deployed."

exit 0
