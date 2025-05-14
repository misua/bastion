#!/bin/bash
set -e # Exit on error

LOG_FILE="/var/log/secure_ssh_dirs.log"
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a $LOG_FILE
}

log "Starting SSH directory security check..."

# Ensure chattr is available
if ! command -v chattr &>/dev/null; then
    log "ERROR: 'chattr' command not found. Cannot make directories immutable."
    exit 1 # Or choose to continue without immutability
fi

# Process existing user home directories
# Using getent for potentially better compatibility (e.g., LDAP users)
home_dirs=$(getent passwd | awk -F: '$6 ~ /\/home\// {print $6}' | sort -u)

for home_dir in $home_dirs; do
    if [ ! -d "$home_dir" ]; then
        log "Skipping non-existent home directory: $home_dir"
        continue
    fi

    user=$(basename $home_dir)
    ssh_dir="$home_dir/.ssh"

    log "Processing user: $user, directory: $ssh_dir"

    # Create .ssh directory if it doesn't exist
    if [ ! -d "$ssh_dir" ]; then
      log "Creating directory $ssh_dir"
      mkdir -p "$ssh_dir"
      chown $user:$user "$ssh_dir"
      chmod 700 "$ssh_dir"
    fi

    # Ensure correct ownership and permissions even if it exists
    current_owner=$(stat -c '%U:%G' $ssh_dir)
    current_perms=$(stat -c '%a' $ssh_dir)
    if [ "$current_owner" != "$user:$user" ]; then
        log "Correcting ownership for $ssh_dir (was $current_owner)"
        chown $user:$user "$ssh_dir"
    fi
    if [ "$current_perms" != "700" ]; then
        log "Correcting permissions for $ssh_dir (was $current_perms)"
        chmod 700 "$ssh_dir"
    fi

    # Check if immutable flag is already set
    if lsattr -d "$ssh_dir" 2>/dev/null | grep -q -- '-i-'; then
        log "Directory $ssh_dir is already immutable."
    else
        log "Making directory $ssh_dir immutable."
        chattr +i "$ssh_dir"
    fi

    # Create/update the warning file
    readme_file="$ssh_dir/README"
    echo "This directory is managed by the central SSH key system." > "$readme_file"
    echo "Keys should be added through the GitHub repository." >> "$readme_file"
    chown $user:$user "$readme_file"
    chmod 644 "$readme_file"

done

log "Finished SSH directory security check."
exit 0
