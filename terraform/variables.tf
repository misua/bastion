variable "aws_region" {
  description = "AWS region to deploy the bastion host in"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for the bastion host (ensure it's a compatible Linux distro, e.g., Ubuntu 22.04)"
  type        = string
  # Example for Ubuntu 22.04 in us-east-1, replace if needed
  default     = "ami-053b0d53c279acc90"
}

variable "key_name" {
  description = "Name of the EC2 Key Pair to allow initial SSH access for setup/debugging (optional)"
  type        = string
  default     = "bastion-test-key" # Using our newly created key pair for initial access
}

variable "github_repo_url" {
  description = "URL to the GitHub repository containing the authorized_keys file (without auth token). This must be a valid URL to a raw file containing SSH public keys in the authorized_keys format. The repository must exist and be accessible."
  type        = string
  # This is a placeholder URL and should be replaced with a valid URL to your centralized SSH keys repository
  default     = "https://raw.githubusercontent.com/example/ssh-keys-repo/main/authorized_keys"
}

variable "github_token" {
  description = "GitHub Personal Access Token for private repository access (leave empty for public repos)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Be more restrictive in production
}

variable "project_name" {
  description = "A name prefix for resources created"
  type        = string
  default     = "bastion"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file for provisioner connections"
  type        = string
  default     = "~/.ssh/id_rsa"
  sensitive   = true
}

# Add variables for allowed outbound destinations as needed
# variable "allowed_outbound_ips" {
#   description = "List of IPs/CIDRs the bastion can connect to outbound"
#   type        = list(string)
#   default     = ["<your_db_ip>/32", "<your_api_ip>/32"]
# }
