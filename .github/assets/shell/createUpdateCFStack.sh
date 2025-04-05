#!/usr/bin/env bash

set -eEBx

# https://gist.github.com/mdjnewman/b9d722188f4f9c6bb277a37619665e77

usage="Usage: $(basename "$0") region stack-name [aws-cli-opts]
where:
  region       - the AWS region
  stack-name   - the stack name
  aws-cli-opts - extra options passed directly to create-stack/update-stack
"

if [ "$1" == "-h" ] || [ "$1" == "--help" ] || [ "$1" == "help" ] || [ "$1" == "usage" ] ; then
  echo "$usage"
  exit 1
fi

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] ; then
  echo "$usage"
  exit 2
fi

shopt -s failglob
set -eu -o pipefail

echo "Checking if stack exists ..."

if ! aws cloudformation describe-stacks --region $1 --stack-name $2 | cat ; then

  echo -e "\nStack does not exist, creating ..."

  # @link https://unix.stackexchange.com/questions/92978/what-does-this-2-mean-in-shell-scripting
  aws cloudformation create-stack \
    --region $1 \
    --stack-name $2 \
    ${@:3}

  echo "Waiting for stack to be created ..."

  aws cloudformation wait stack-create-complete \
    --region $1 \
    --stack-name $2

else

echo -e "\nStack exists, checking for parameter changes ..."

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
  echo "❌ 'jq' is required for parameter diffing but not installed."
  exit 3
fi

# Usage: script.sh region stack-name [ParameterKey=...,ParameterValue=...]...
if [ "$#" -lt 2 ]; then
  echo "Usage: $(basename "$0") region stack-name [ParameterKey=...,ParameterValue=...]..."
  exit 1
fi

REGION="$1"
STACK_NAME="$2"
shift 2

# Get current parameters as JSON
current_params=$(aws cloudformation describe-stacks \
  --region "$REGION" \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Parameters" \
  --output json)

# If no parameters are set, convert null to empty array
if [ "$current_params" = "null" ]; then
  current_params="[]"
fi

# Build new parameters JSON manually from remaining CLI arguments.
# Expecting each argument in the form: ParameterKey=SomeKey,ParameterValue=SomeValue
param_json="["
for p in "$@"; do
  # Extract the key and value parts
  key=$(echo "$p" | cut -d',' -f1 | cut -d'=' -f2)
  value=$(echo "$p" | cut -d',' -f2 | cut -d'=' -f2-)
  # Append a JSON object; note that we wrap value in quotes (adjust if numeric)
  param_json+="{\"ParameterKey\":\"$key\",\"ParameterValue\":\"$value\"},"
done
# Remove trailing comma and close the array
param_json="${param_json%,}]"
new_params=$(echo "$param_json" | jq '.')

# Convert new_params null to empty array (just in case)
if [ "$new_params" = "null" ]; then
  new_params="[]"
fi

# Check if the new parameters are empty and, if so, skip the update.
if [ "$new_params" = "[]" ]; then
  echo "✅ New parameters are empty. Skipping update."
  exit 0
fi

# Sort and compare the current and new parameters
if diff <(echo "$current_params" | jq -S .) <(echo "$new_params" | jq -S .) > /dev/null; then
  echo "✅ Parameters have not changed. Skipping update."
  exit 0
fi

echo "📦 Parameters changed — proceeding with update ..."
# Proceed with update-stack (or whatever command you need)

  set +e
  update_output=$( aws cloudformation update-stack \
    --region $1 \
    --stack-name $2 \
    ${@:3}  2>&1)
  status=$?
  set -e

  echo "$update_output"

  if [ $status -ne 0 ] ; then

    # Don't fail for no-op update
    if [[ $update_output == *"ValidationError"* && $update_output == *"No updates"* ]] ; then
      echo -e "\nFinished create/update - no updates to be performed"
      exit 0
    else
      exit $status
    fi

  fi
  sleep 10
  echo "Waiting for stack update to complete ..."
  aws cloudformation wait stack-update-complete \
    --region $1 \
    --stack-name $2

fi

echo "Finished create/update successfully!"

