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

  # If jq is not installed, fallback
  if ! command -v jq &> /dev/null; then
    echo "❌ 'jq' is required for parameter diffing but not installed."
    exit 3
  fi

  # Get current parameters as JSON
  current_params=$(aws cloudformation describe-stacks \
    --region "$1" \
    --stack-name "$2" \
    --query "Stacks[0].Parameters" \
    --output json)

  # Build new parameters JSON from CLI args
  new_params=$(aws cloudformation \
    --region "$1" \
    --stack-name "$2" \
    ${@:3} \
    --dry-run 2>/dev/null | jq '.Parameters')

  # Sort and compare
  if diff <(echo "$current_params" | jq -S .) <(echo "$new_params" | jq -S .) > /dev/null; then
    echo "✅ Parameters have not changed. Skipping update."
    exit 0
  fi

  echo "📦 Parameters changed — proceeding with update ..."

  echo -e "\nStack exists, attempting update ..."

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

