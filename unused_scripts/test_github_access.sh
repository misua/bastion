#!/bin/bash
# Script to test GitHub access using the token from terraform.tfvars

# Extract GitHub token and URL from terraform.tfvars
GITHUB_TOKEN=$(grep github_token /Users/charles/Desktop/bastion/terraform/terraform.tfvars | cut -d'"' -f2)
GITHUB_REPO_URL=$(grep github_repo_url /Users/charles/Desktop/bastion/terraform/terraform.tfvars | cut -d'"' -f2)

echo "GitHub Token: ${GITHUB_TOKEN:0:5}...${GITHUB_TOKEN: -5}" # Show only first and last 5 chars for security
echo "GitHub Repo URL: $GITHUB_REPO_URL"

# Construct the URL with token
if [ -n "$GITHUB_TOKEN" ]; then
  GITHUB_RAW_URL="$(echo $GITHUB_REPO_URL | sed 's|https://|https://'"$GITHUB_TOKEN"'@|')"
else
  GITHUB_RAW_URL="$GITHUB_REPO_URL"
fi

echo "Constructed URL: ${GITHUB_RAW_URL//$GITHUB_TOKEN/<TOKEN>}" # Hide token in output

# Test GitHub access
echo -e "\nTesting GitHub access..."
if curl -s -f -L -o /tmp/test_keys "$GITHUB_RAW_URL"; then
  echo "SUCCESS: File downloaded successfully"
  echo -e "\nFile content:"
  cat /tmp/test_keys
  rm /tmp/test_keys
else
  echo "ERROR: Failed to download file from GitHub"
  echo -e "\nTesting with verbose output (hiding auth token):"
  curl -v -L "$GITHUB_RAW_URL" 2>&1 | grep -v "Authorization:"
fi
