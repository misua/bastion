#!/bin/bash
# Script to automatically fix bash variables in Terraform templates

TEMPLATE_FILE="/Users/charles/Desktop/bastion/terraform/user_data_wrapper.sh.tftpl"
OUTPUT_FILE="/Users/charles/Desktop/bastion/terraform/user_data_wrapper_fixed.sh.tftpl"

echo "Fixing bash variables in $TEMPLATE_FILE..."

# Define known Terraform variables that should not be escaped
TERRAFORM_VARS=("github_token" "github_repo_url")

# Define heredoc markers to detect
HEREDOC_MARKERS=("EOF" "RSYSLOGEOF")

# Clear the output file
> "$OUTPUT_FILE"

# Initialize variables
in_heredoc=false
heredoc_marker=""

# Process the file line by line
while IFS= read -r line; do
  # Check if we're starting a heredoc
  for marker in "${HEREDOC_MARKERS[@]}"; do
    if [[ "$line" == *"'$marker'"* || "$line" == *"\"$marker\""* ]]; then
      echo "$line" >> "$OUTPUT_FILE"
      in_heredoc=true
      heredoc_marker="$marker"
      continue 2
    fi
  done
  
  # Check if we're exiting a heredoc
  if [[ "$in_heredoc" == true && "$line" == "$heredoc_marker" ]]; then
    echo "$line" >> "$OUTPUT_FILE"
    in_heredoc=false
    continue
  fi
  
  # If we're in a heredoc, don't modify the line
  if [[ "$in_heredoc" == true ]]; then
    echo "$line" >> "$OUTPUT_FILE"
    continue
  fi
  
  # Skip lines with Terraform variables
  skip_line=false
  for var in "${TERRAFORM_VARS[@]}"; do
    if [[ "$line" == *"\${$var}"* ]]; then
      skip_line=true
      break
    fi
  done
  
  if [[ "$skip_line" == true ]]; then
    echo "$line" >> "$OUTPUT_FILE"
    continue
  fi
  
  # Manual fix for specific cases
  # Fix variable in quotes like "$VAR"
  modified_line=$(echo "$line" | sed -E 's/"\$([a-zA-Z_][a-zA-Z0-9_]*)"/"\$\$\1"/g')
  
  # Fix variable in quotes with path like "$VAR/path"
  modified_line=$(echo "$modified_line" | sed -E 's/"\$([a-zA-Z_][a-zA-Z0-9_]*)\/([^"]*)"/"\$\$\1\/\2"/g')
  
  # Fix variable at start of line
  modified_line=$(echo "$modified_line" | sed -E 's/^\$([a-zA-Z_][a-zA-Z0-9_]*)/\$\$\1/g')
  
  # Fix variable after space
  modified_line=$(echo "$modified_line" | sed -E 's/([[:space:]])\$([a-zA-Z_][a-zA-Z0-9_]*)/\1\$\$\2/g')
  
  # Fix variable after equals sign
  modified_line=$(echo "$modified_line" | sed -E 's/=\$([a-zA-Z_][a-zA-Z0-9_]*)/=\$\$\1/g')
  
  # Fix variable in command substitution
  modified_line=$(echo "$modified_line" | sed -E 's/\$\(([^)]*)\$([a-zA-Z_][a-zA-Z0-9_]*)([^)]*)\)/\$\(\1\$\$\2\3\)/g')
  
  # Fix variable in parameter expansion
  modified_line=$(echo "$modified_line" | sed -E 's/\$\{([a-zA-Z_][a-zA-Z0-9_]*)([-:+?#%\/]*)([^}]*)\}/\$\$\{\1\2\3\}/g')
  
  # Don't escape $( command substitution at start
  modified_line=$(echo "$modified_line" | sed -E 's/^\$\$\(/\$\(/g')
  
  # Don't escape $( command substitution after space
  modified_line=$(echo "$modified_line" | sed -E 's/([[:space:]])\$\$\(/\1\$\(/g')
  
  # Don't escape positional parameters $1, $2, etc.
  modified_line=$(echo "$modified_line" | sed -E 's/\$\$([0-9])/\$\1/g')
  
  # Don't escape special parameters $@, $*, $#, etc.
  modified_line=$(echo "$modified_line" | sed -E 's/\$\$([@*#?])/\$\1/g')
  
  # Don't double-escape already escaped variables
  modified_line=$(echo "$modified_line" | sed -E 's/\$\$\$\$/\$\$/g')
  
  echo "$modified_line" >> "$OUTPUT_FILE"
done < "$TEMPLATE_FILE"

# Replace the original file with the fixed version
cp "$OUTPUT_FILE" "$TEMPLATE_FILE"
echo "Fixed bash variables in $TEMPLATE_FILE"

# Verify the changes
echo "Verifying changes..."
grep -n '\$[a-zA-Z_][a-zA-Z0-9_]*' "$TEMPLATE_FILE" | grep -v '\$\$' | grep -v '\${github_token}' | grep -v '\${github_repo_url}' | grep -v "'EOF'" | grep -v "'RSYSLOGEOF'"
