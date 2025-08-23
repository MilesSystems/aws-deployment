#!/usr/bin/env bash

set -eEBx

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

if [ -z "$1" ] || [ -z "$2" ] ; then
  echo "$usage"
  exit 2
fi

shopt -s failglob
set -eu -o pipefail

REGION="$1"
STACK_NAME="$2"
shift 2
extra_args=("$@")

echo "Checking if stack exists ..."

if ! aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK_NAME" >/dev/null 2>&1; then
  echo -e "\nStack does not exist, creating ..."

  aws cloudformation create-stack \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    "${extra_args[@]}"

  echo "Waiting for stack to be created ..."
  aws cloudformation wait stack-create-complete \
    --region "$REGION" \
    --stack-name "$STACK_NAME"

else
  echo -e "\nStack exists, checking for parameter changes ..."

  if ! command -v jq &> /dev/null; then
    echo "❌ 'jq' is required for parameter diffing but not installed."
    exit 3
  fi

  current_params=$(aws cloudformation describe-stacks \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Parameters" \
    --output json)

  [ "$current_params" = "null" ] && current_params="[]"

  param_array=()
  for arg in "${extra_args[@]}"; do
    trimmed_arg=$(echo "$arg" | xargs)
    if [[ "$trimmed_arg" == ParameterKey=* ]]; then
      key=$(echo "$trimmed_arg" | cut -d',' -f1 | cut -d= -f2)
      value=$(echo "$trimmed_arg" | cut -d',' -f2 | cut -d= -f2-)
      param_array+=("{\"ParameterKey\":\"$key\",\"ParameterValue\":\"$value\"}")
    fi
  done

  if [ ${#param_array[@]} -eq 0 ]; then
    echo "✅ No CloudFormation parameters provided. Skipping parameter diffing."
    new_params="[]"
  else
    new_params="[${param_array[*]}]"
    new_params=$(echo "$new_params" | sed 's/} {/}, {/g') # clean up spacing
  fi

  [ "$new_params" = "null" ] && new_params="[]"

  if [ "$new_params" = "[]" ] && [ "$current_params" = "[]" ]; then
    echo "✅ Both current and new parameters are empty. Skipping update."
    exit 0
  fi

  if [ "$new_params" = "[]" ]; then
    echo "✅ New parameters are empty. Skipping update."
    exit 0
  fi

  if diff <(echo "$current_params" | jq -S .) <(echo "$new_params" | jq -S .) > /dev/null; then
    echo "✅ Parameters have not changed. Skipping update."
    exit 0
  fi

  echo "📦 Parameters changed — proceeding with update ..."

  max_retries=5
  attempt=1
  while true; do
    set +e
    update_output=$( aws cloudformation update-stack \
      --region "$REGION" \
      --stack-name "$STACK_NAME" \
      --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
      "${extra_args[@]}" 2>&1 )
    status=$?
    set -e

    echo "$update_output"

    if [ $status -eq 0 ]; then
      break
    fi

    if [[ $update_output == *"ValidationError"* && $update_output == *"No updates"* ]]; then
      echo -e "\nFinished create/update - no updates to be performed"
      exit 0
    fi

    if [[ $update_output == *"ValidationError"* && $update_output == *"UPDATE_IN_PROGRESS"* ]]; then
      if (( attempt >= max_retries )); then
        echo "❌ Stack is still UPDATE_IN_PROGRESS after $attempt attempts."
        exit $status
      fi
      echo "⏳ Stack UPDATE_IN_PROGRESS. Waiting before retrying ($attempt/$max_retries)..."
      aws cloudformation wait stack-update-complete --region "$REGION" --stack-name "$STACK_NAME"
      ((attempt++))
      continue
    fi

    exit $status
  done

  sleep 10
  echo "Waiting for stack update to complete ..."
  aws cloudformation wait stack-update-complete \
    --region "$REGION" \
    --stack-name "$STACK_NAME"
fi

echo "Finished create/update successfully!"
