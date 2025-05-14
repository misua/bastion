#!/bin/bash
# Test script specifically for user_data_wrapper.sh.tftpl template interpolation

# Set up test environment
echo "Setting up test environment..."
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR" || exit 1

# Copy the wrapper template file
cp /Users/charles/Desktop/bastion/terraform/user_data_wrapper.sh.tftpl .

# Create a test values file
cat > test_values.json << 'EOF'
{
  "github_token": "test_token",
  "github_repo_url": "https://example.com/test/repo"
}
EOF

# Create a simple test Terraform configuration
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
EOF

# Initialize Terraform
echo "Initializing Terraform..."
terraform init -no-color

if [ $? -ne 0 ]; then
  echo "FAIL: Terraform initialization failed"
  exit 1
fi

# Validate the Terraform configuration
echo "Validating Terraform configuration..."
terraform validate -no-color

if [ $? -ne 0 ]; then
  echo "FAIL: Terraform validation failed"
  exit 1
else
  echo "PASS: Terraform validation successful"
fi

# Try to render the template
echo "Testing template rendering..."
terraform plan -var-file=test_values.json -no-color -out=test.plan

if [ $? -ne 0 ]; then
  echo "FAIL: Template rendering failed during plan"
  
  # Try to find specific error messages related to template interpolation
  terraform plan -var-file=test_values.json -no-color 2>&1 | grep -A 5 "Error in function call" | grep -A 5 "templatefile"
  
  exit 1
else
  echo "PASS: Template rendering successful during plan"
  
  # Apply the plan to get the rendered output
  terraform apply -no-color test.plan
  
  if [ $? -ne 0 ]; then
    echo "FAIL: Failed to apply the plan"
    exit 1
  else
    echo "PASS: Plan applied successfully"
    
    # Save the rendered template to a file
    terraform output -raw rendered_wrapper > rendered_wrapper.sh
    
    # Check for common issues in the rendered template
    echo "Checking rendered template for issues..."
    
    # Check for unescaped Terraform interpolation syntax
    if grep -q "\${[^}]*}" rendered_wrapper.sh; then
      echo "FAIL: Found unescaped Terraform interpolation syntax in rendered template"
      grep -n "\${[^}]*}" rendered_wrapper.sh
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
  fi
fi

# Clean up
echo "Cleaning up..."
cd /
rm -rf "$TEST_DIR"

echo "Tests completed."
