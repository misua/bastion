#!/bin/bash
# Script to fix the GitHub token handling in the user data wrapper script

# Create a backup of the original file
cp /Users/charles/Desktop/bastion/terraform/user_data_wrapper.sh.tftpl /Users/charles/Desktop/bastion/terraform/user_data_wrapper.sh.tftpl.bak

# Replace the GitHub token handling section
sed -i '' '8,14c\
# Construct the GitHub URL with token if provided\
if [ -n "$$GITHUB_TOKEN" ]; then \
  # Insert token into URL for private repo access - simplified approach\
  GITHUB_RAW_URL="https://$$GITHUB_TOKEN@raw.githubusercontent.com/OrbisSystems/centralized-keys/main/authorized_keys"\
else\
  # No token needed for public repos\
  GITHUB_RAW_URL="$$GITHUB_BASE_URL"\
fi' /Users/charles/Desktop/bastion/terraform/user_data_wrapper.sh.tftpl

echo "GitHub token handling fixed in user_data_wrapper.sh.tftpl"
