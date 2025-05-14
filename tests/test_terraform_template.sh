#!/bin/bash
# Test script for Terraform template interpolation

# Set up test environment
echo "Setting up test environment..."
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR" || exit 1

# Copy the template files
cp /Users/charles/Desktop/bastion/terraform/user_data.sh.tftpl .
cp /Users/charles/Desktop/bastion/terraform/user_data_wrapper.sh.tftpl .

# Create a test values file
cat > test_values.json << 'EOF'
{
  "github_token": "test_token",
  "github_repo_url": "https://example.com/test/repo"
}
EOF

# Test the template interpolation using Terraform's templatefile function
echo "Testing template interpolation..."
echo "This will validate that the template syntax is correct without applying any changes."

# Create a test Terraform configuration
cat > test.tf << 'EOF'
terraform {
  required_version = ">= 0.12"
}

variable "github_token" {
  type = string
}

variable "github_repo_url" {
  type = string
}

output "rendered_wrapper" {
  value = templatefile("${path.module}/user_data_wrapper.sh.tftpl", {
    github_token    = var.github_token
    github_repo_url = var.github_repo_url
  })
  sensitive = true
}

# Test that the wrapper script correctly embeds the main script
locals {
  main_script = file("${path.module}/user_data.sh.tftpl")
}
EOF

# Initialize Terraform
terraform init

# Apply with test values
terraform apply -auto-approve -var-file=test_values.json

# Check if there were any errors
if [ $? -eq 0 ]; then
  echo "PASS: Template interpolation successful"
  
  # Get the rendered template and check for specific patterns
  terraform output -raw rendered_wrapper > rendered_wrapper.sh
  
  # Check for common interpolation issues
  if grep -q "\\${" rendered_wrapper.sh; then
    echo "FAIL: Found unescaped Terraform interpolation syntax (\\${) in rendered template"
    grep -n "\\${" rendered_wrapper.sh
  else
    echo "PASS: No unescaped Terraform interpolation syntax found"
  fi
  
  # Check that test values were properly interpolated
  if grep -q "test_token" rendered_wrapper.sh; then
    echo "PASS: Test token was properly interpolated"
  else
    echo "FAIL: Test token was not found in rendered template"
  fi
  
  if grep -q "https://example.com/test/repo" rendered_wrapper.sh; then
    echo "PASS: Test URL was properly interpolated"
  else
    echo "FAIL: Test URL was not found in rendered template"
  fi
else
  echo "FAIL: Template interpolation failed"
fi

# Clean up
echo "Cleaning up..."
cd /
rm -rf "$TEST_DIR"

echo "Tests completed."
