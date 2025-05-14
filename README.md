# Bastion Host SSH Key Management and Audit System

This document outlines the workflow for managing SSH access to the bastion host and using the audit functionality to track user sessions.

## Overview

The bastion host automatically downloads SSH public keys from a GitHub repository and updates both system-wide and user-specific authorized_keys files. It also maintains a mapping between SSH keys and email identifiers for audit purposes.

Current bastion host IP: **18.233.157.85**

## Deployment Options

The bastion host can be deployed in two ways:

### Option 1: Basic Deployment with Manual Audit Setup

1. Deploy the bastion host using Terraform:

   ```bash
   cd terraform
   terraform apply
   ```

2. Manually upload and execute the audit script:

   ```bash
   scp add_audit.sh ubuntu@<bastion-ip>:/tmp/
   ssh ubuntu@<bastion-ip> "sudo bash /tmp/add_audit.sh"
   ```

### Option 2: Fully Automated Deployment with Audit (Recommended)

1. Ensure your SSH private key path is correctly set in `terraform/terraform.tfvars`:

   ```hcl
   ssh_private_key_path = "/path/to/your/private/key"
   ```

2. Deploy the bastion host with Terraform:

   ```bash
   cd terraform
   terraform apply
   ```

3. The enhanced audit script will be automatically uploaded and executed via provisioners

## SSH Access Workflow

### Adding a New SSH Key

1. Generate an SSH key pair if you don't already have one:
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com"
   ```

2. Add your public key to the GitHub repository:
   - Create a pull request to add your public key to the `authorized_keys` file
   - Ensure your key includes your email as a comment at the end (this is used for audit tracking)
   - Example format: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtqgJBgVrN8xCYXDqXGJCzFW9TCQXWGIhPw4xkwiZ9X your.email@example.com`

3. Get your PR approved and merged

4. Wait for the key to be propagated:
   - Keys are automatically updated hourly via a cron job
   - Your key should be available within 1 hour of being merged

### Forcing an Immediate Key Update

If you need immediate access without waiting for the hourly cron job:

1. SSH into the bastion host (if you already have access)
2. Run the download script manually:
   ```bash
   sudo /usr/local/bin/download_keys.sh
   ```

3. Verify your key was added:
   ```bash
   grep "your.email@example.com" /etc/ssh/authorized_keys
   ```

## Audit Functionality

The bastion host includes comprehensive audit functionality that tracks SSH logins and associates them with email identifiers.

### Key Features

- **Email-based Identity Tracking**: SSH keys are mapped to email identifiers
- **Session Tracking**: Each SSH session is logged with the user's email
- **Audit Logging**: All SSH activities are logged for security and compliance

### Searching for User Sessions

To find all SSH sessions associated with a specific email:

```bash
sudo /usr/local/bin/search-by-email.sh user.email@example.com
```

This will display:
- All session IDs associated with that email
- Log entries for each session

### Viewing Audit Logs

To view all SSH-related audit logs:

```bash
sudo ausearch -k ssh_sessions
```

To view all changes to SSH configuration:

```bash
sudo ausearch -k sshd_config
```

### Viewing Raw Auth Logs

To view the raw authentication logs:

```bash
sudo grep "SSH LOGIN" /var/log/auth.log
```

## Troubleshooting

### Key Mapping Issues

If your email is not being correctly associated with your SSH key:

1. Verify your key has the correct email comment:
   ```bash
   grep "your.email@example.com" /etc/ssh/authorized_keys
   ```

2. Manually update the key mappings:
   ```bash
   sudo /usr/local/bin/update_key_mappings.sh
   ```

3. Check if your key was mapped correctly:
   ```bash
   sudo ls -la /etc/ssh/key_mapping/
   ```

### SSH Access Issues

If you're having trouble accessing the bastion host:

1. Verify your public key is in the GitHub repository
2. Check if your key was downloaded to the bastion host:
   ```bash
   sudo grep "your.email@example.com" /etc/ssh/authorized_keys
   ```

3. Force an update of the keys:
   ```bash
   sudo /usr/local/bin/download_keys.sh
   ```

## Technical Details

- Keys are stored in both `/etc/ssh/authorized_keys` (system-wide) and `/home/ubuntu/.ssh/authorized_keys` (user-specific)
- Key mappings are stored in `/etc/ssh/key_mapping/`
- Session mappings are stored in `/etc/ssh/session_mappings/`
- Audit logs are stored in `/var/log/audit/audit.log` and `/var/log/auth.log`
- The key update script runs hourly via cron

## Security Considerations

- SSH keys are the only method of authentication allowed
- All SSH sessions are logged with the user's email identifier
- Audit logs are maintained for security and compliance purposes
- The system is designed to be secure and maintainable

## Infrastructure Management

The bastion host is managed using Terraform. The configuration files are located in the `terraform/` directory.

To update the infrastructure:

1. Make changes to the Terraform files
2. Run `terraform apply` to apply the changes

Note: The audit functionality is added to the bastion host after it is created, using the `add_audit.sh` script.
