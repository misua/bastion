#!/bin/bash
# Comprehensive script to check for unescaped bash variables in Terraform templates

TEMPLATE_FILE="/Users/charles/Desktop/bastion/terraform/user_data_wrapper.sh.tftpl"
OUTPUT_FILE="/Users/charles/Desktop/bastion/terraform/user_data_wrapper_fixed.sh.tftpl"

echo "Checking for unescaped bash variables in $TEMPLATE_FILE..."

# Define known Terraform variables that should not be escaped
TERRAFORM_VARS=("github_token" "github_repo_url")

# Create a grep pattern to exclude Terraform variables
EXCLUDE_PATTERN=""
for var in "${TERRAFORM_VARS[@]}"; do
  if [ -n "$EXCLUDE_PATTERN" ]; then
    EXCLUDE_PATTERN="$EXCLUDE_PATTERN|\${$var}"
  else
    EXCLUDE_PATTERN="\${$var}"
  fi
done

# Find all bash variables that aren't in heredocs or escaped
find_unescaped_vars() {
  # Find all lines with $ that aren't in heredocs (marked with 'EOF') and aren't already escaped
  grep -n '\$[a-zA-Z_][a-zA-Z0-9_]*\|\${[^}]*}' "$TEMPLATE_FILE" | \
  grep -v "'EOF'" | \
  grep -v "\$\$" | \
  grep -v "\\\$" | \
  grep -v "\$(" | \
  grep -v "\$?" | \
  grep -v "\$#" | \
  grep -v "\$@" | \
  grep -v "\$*" | \
  grep -v "\$1" | \
  grep -v "\$2" | \
  grep -v "\$3" | \
  grep -v "\$4" | \
  grep -v "\$5" | \
  grep -v "\$6" | \
  grep -v "\$7" | \
  grep -v "\$8" | \
  grep -v "\$9"
  
  # Also check for rsyslog variables
  grep -n '\$[a-zA-Z]\+' "$TEMPLATE_FILE" | grep "syslog\|msg"
}

# Get all unescaped variables
UNESCAPED_LINES=$(find_unescaped_vars)

# Exclude Terraform variables
if [ -n "$EXCLUDE_PATTERN" ]; then
  UNESCAPED_LINES=$(echo "$UNESCAPED_LINES" | grep -v -E "$EXCLUDE_PATTERN")
fi

UNESCAPED_COUNT=$(echo "$UNESCAPED_LINES" | wc -l)

if [ -n "$UNESCAPED_LINES" ] && [ "$UNESCAPED_COUNT" -gt 0 ]; then
  echo "Found $UNESCAPED_COUNT unescaped bash variable expansions that need to be escaped for Terraform:"
  echo "$UNESCAPED_LINES"
  
  # Show the lines with context
  echo -e "\nDetailed view of problematic lines:"
  echo "$UNESCAPED_LINES" | cut -d: -f1 | while read line_num; do
    echo -e "\nLine $line_num:"
    sed -n "$((line_num-1)),$((line_num+1))p" "$TEMPLATE_FILE"
  done
  
  exit 1
else
  echo "No unescaped Terraform interpolation syntax found!"
  exit 0
fi
