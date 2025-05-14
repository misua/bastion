#!/bin/bash
# Script to test and debug the user_data_wrapper.sh.tftpl file

# Create a simplified version of the template for testing
cat > /tmp/test_template.tftpl << 'EOF'
#!/bin/bash
# Simple test template

# GitHub token and repo URL from Terraform variables
GITHUB_TOKEN="${github_token}"
GITHUB_REPO_URL="${github_repo_url}"

# Create a tool to search audit logs by user
cat > /usr/local/bin/test-script.sh << EOF
#!/bin/bash
# Test script with variables

if [ \$# -lt 1 ]; then
  echo "Usage: \$0 <parameter>"
  exit 1
fi

PARAM="\$1"
echo "Parameter: \$PARAM"
EOF

chmod +x /usr/local/bin/test-script.sh
echo "Test complete"
EOF

echo "Created test template at /tmp/test_template.tftpl"
echo "Running terraform console to test templatefile function..."

# Run terraform console with a command to test the template
terraform console -c 'templatefile("/tmp/test_template.tftpl", {github_token = "test-token", github_repo_url = "https://github.com/example/repo"})' 2>&1

# Check the exit code
if [ $? -eq 0 ]; then
  echo "Template parsing successful!"
else
  echo "Template parsing failed. See error above."
fi
