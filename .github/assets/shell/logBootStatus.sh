#!/bin/bash

build_version="$1"
COMMANDS="$2"
PATH_WORKING_CONTEXT=$(pwd)

if [[ "$(pwd)" == *"/.aws/Assets/shell" ]]; then
  cd ../../..
fi

INSTANCE_IDS=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId' \
  --filters "Name=instance-state-name,Values=running" ${build_version:+"Name=tag:Version,Values=${build_version}"} \
  --output text)

if [[ -z "${LOG_NUMBER+x}" ]]; then
  echo "Starting Log Count"
  LOG_NUMBER=0
fi

LOG_NUMBER=$((LOG_NUMBER + 1))

echo -e "Instance IDs\n###################\n$INSTANCE_IDS\n###################"

set +e

if ! command -v unbuffer &>/dev/null; then
  echo "unbuffer could not be found, installing it"
  if command -v apt-get &>/dev/null; then
    sudo apt-get install expect -y
  elif command -v dnf &>/dev/null; then
    sudo dnf install expect -y
  else
    echo "Package manager not found. Install 'expect' manually."
  fi
fi

if [[ -n "$INSTANCE_IDS" ]]; then
  while read -r instanceid; do
    if [[ -z "$instanceid" ]]; then
      continue
    fi

    echo -e "######################################$instanceid######################################\n($LOG_NUMBER)"

    echo "Script ($COMMANDS) to run: ($(cat "$COMMANDS"))"

    echo "aws ssm start-session on ($instanceid)"

    # Determine platform
    PLATFORM=$(aws ec2 describe-instances --instance-ids $instanceid --query "Reservations[*].Instances[*].[Platform]" --output text)

    if [[ "$PLATFORM" == "None" ]]; then
      PLATFORM="linux"
    else
      PLATFORM="windows"
    fi

    echo "PLATFORM: ($PLATFORM)"

    PARAMETERS_JSON=$(php ./.github/assets/php/createCommandParameters.php "$COMMANDS" "$PLATFORM")

    echo "PARAMETERS_JSON: ($(cat $PARAMETERS_JSON))"

    unbuffer aws ssm start-session --color on \
          --document-name 'AWS-StartNonInteractiveCommand' \
          --parameters "file://$PARAMETERS_JSON" \
          --target "$instanceid"

    echo "aws ssm start-session on ($instanceid) completed with EXIT ($?)"

  done <<<"$INSTANCE_IDS"
else
  echo "No instances for logging"
fi

set -e

cd "$PATH_WORKING_CONTEXT"
