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
  description = "Security group for the bastion host"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
    description = "Allow SSH inbound"
  }

  # Default egress rule allows all outbound. We will refine this later based on Part 4.
  # If using iptables within user_data for fine-grained control, this might stay open.
  # If relying solely on SG, restrict this significantly.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound initially (will be restricted)"
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

  # Use templatefile with the minimal bootstrap script
  user_data = templatefile("${path.module}/bootstrap_only.sh.tftpl", {
    github_token    = var.github_token
    github_repo_url = var.github_repo_url
  })
  
  # Wait for instance to be ready before attempting to connect
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for instance to be fully initialized...'",
      "cloud-init status --wait"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/../test_key")
      host        = self.public_ip
      timeout     = "5m"
    }
  }

  # Upload the enhanced audit script
  provisioner "file" {
    source      = "${path.module}/../enhanced_audit.sh"
    destination = "/tmp/enhanced_audit.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/../test_key")
      host        = self.public_ip
    }
  }

  # Execute the enhanced audit script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/enhanced_audit.sh",
      "sudo bash /tmp/enhanced_audit.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/../test_key")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "${var.project_name}-host"
  }

  # Add lifecycle rules if needed, e.g., prevent destroy
  # lifecycle {
  #   prevent_destroy = true
  # }
}
