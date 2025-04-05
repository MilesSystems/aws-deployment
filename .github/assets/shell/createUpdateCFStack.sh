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

# Usage: createUpdateCFStack.sh region stack-name [extra options...]
if [ "$#" -lt 2 ]; then
  echo "Usage: $(basename "$0") region stack-name [aws-cli-opts]"
  exit 1
fi

REGION="$1"
STACK_NAME="$2"
shift 2

# Capture extra arguments in an array to preserve their boundaries
extra_args=("$@")

echo "Checking if stack exists ..."
aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK_NAME" | cat

echo -e "\nStack exists, checking for parameter changes ..."

# Get current parameters as JSON from the existing stack
current_params=$(aws cloudformation describe-stacks \
  --region "$REGION" \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Parameters" \
  --output json)

# If no parameters are set, convert null to empty array
if [ "$current_params" = "null" ]; then
  current_params="[]"
fi

# Build new parameters JSON manually by filtering only arguments that start with "ParameterKey="
param_array=()
for arg in "${extra_args[@]}"; do
  # Trim whitespace
  trimmed_arg=$(echo "$arg" | xargs)
  if [[ "$trimmed_arg" == ParameterKey=* ]]; then
    # Expect format: ParameterKey=SomeKey,ParameterValue=SomeValue
    key=$(echo "$trimmed_arg" | cut -d',' -f1 | cut -d= -f2)
    value=$(echo "$trimmed_arg" | cut -d',' -f2 | cut -d= -f2-)
    param_array+=("{\"ParameterKey\":\"$key\",\"ParameterValue\":\"$value\"}")
  fi
done

if [ ${#param_array[@]} -eq 0 ]; then
  echo "✅ No CloudFormation parameters provided. Skipping parameter diffing."
  new_params="[]"
else
  new_params=$(printf "%s," "${param_array[@]}")
  # Remove trailing comma and wrap in array brackets
  new_params="[${new_params%,}]"
fi

# Convert new_params null to empty array (just in case)
if [ "$new_params" = "null" ]; then
  new_params="[]"
fi

# Check if both new_params and current_params are empty.
if [ "$new_params" = "[]" ] && [ "$current_params" = "[]" ]; then
  echo "✅ Both current and new parameters are empty. Skipping update."
  exit 0
fi

# If only new_params is empty, skip update.
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


  set +e
  update_output=$( aws cloudformation update-stack --region "$REGION" --stack-name "$STACK_NAME" ${extra_args[@]} 2>&1 )
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
    --region "$REGION" \
    --stack-name "$STACK_NAME"

fi

echo "Finished create/update successfully!"

