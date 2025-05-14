terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for the bastion host, allowing SSH and essential outbound"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
    description = "Allow SSH inbound"
  }

  # Allow all outbound traffic for proper initialization
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

resource "aws_instance" "bastion_host" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name # Optional: for initial access

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  # Use templatefile with the original wrapper script
  user_data = templatefile("${path.module}/user_data_wrapper.sh.tftpl", {
    github_token    = var.github_token
    github_repo_url = var.github_repo_url
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags    = "enabled"
  }

  tags = {
    Name = "${var.project_name}-host"
  }

  # Add lifecycle rules if needed, e.g., prevent destroy
  # lifecycle {
  #   prevent_destroy = true
  # }
}
