#!/bin/bash

echo "$@"

# @link https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html
# if a command fails and piped to `cat`, for example, the full command will exit failure,.. cat will not run.?
# @link https://distroid.net/set-pipefail-bash-scripts/?utm_source=rss&utm_medium=rss&utm_campaign=set-pipefail-bash-scripts
# @link https://transang.me/best-practice-to-make-a-shell-script/
set -eEBuo pipefail

PARAMETERS_FILE=$1

REGION=$2

ENVIRONMENT=$3

REPOSITORY_NICENAME=$4

VERSION=$5

COMMANDS=$6

STACK_NAME="$ENVIRONMENT-$REPOSITORY_NICENAME-web"

TRY=-1

SCALING_ACTIVITIES=""

NEW_SCALING_ACTIVITIES=""

getStatus() {

  set +e

  STATUS=$(aws --region "${REGION}" cloudformation describe-stacks --stack-name "${STACK_NAME}" --query 'Stacks[0].StackStatus' --output text | cat)

  if [[ "" != "$STATUS" ]]; then

    NEW_SCALING_ACTIVITIES=$(aws autoscaling describe-scaling-activities --auto-scaling-group-name "${ENVIRONMENT}-${REPOSITORY_NICENAME}-${VERSION}-asg" --max-items 3 | jq --color-output)

  fi

  set -e

  if [[ "$NEW_SCALING_ACTIVITIES" != "$SCALING_ACTIVITIES" ]]; then

    SCALING_ACTIVITIES="$NEW_SCALING_ACTIVITIES"

    echo "$NEW_SCALING_ACTIVITIES"

  fi

  echo "STATUS: ($STATUS)"

  TRY=$((1 + $TRY))

}

getLog() {
  source ./.github/assets/shell/logBootStatus.sh "$VERSION" "$COMMANDS"
}

deleteStack() {

  if [[ "$STATUS" != "DELETE_IN_PROGRESS" ]]; then

    aws cloudformation describe-stack-events --stack-name "${STACK_NAME}" --region "${REGION}" | jq --color-output

  fi

  echo "Deleting Stack (${STACK_NAME})"

  # @link https://docs.aws.amazon.com/cli/latest/reference/cloudformation/delete-stack.html
  # "Once the call completes successfully, stack deletion starts. "

  aws cloudformation delete-stack --stack-name "${STACK_NAME}" --region "${REGION}"

  set +e

  while [[ "" != "$STATUS" ]]; do

    echo "Waiting 60 seconds for the stack to delete!"

    sleep 60

    getStatus

  done

  set -e

}

getStatus

while [[ "$STATUS" == "CREATE_IN_PROGRESS" || "$STATUS" == "UPDATE_IN_PROGRESS" || "$STATUS" == "UPDATE_ROLLBACK_IN_PROGRESS" || "$STATUS" == "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS" || "$STATUS" == "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS" ]]; do

  echo -e "Can't update stack until current status ($STATUS) changes"

  getLog ALL

  getStatus

  sleep 60

done

# @link https://stackoverflow.com/questions/57932734/validationerror-stackarn-aws-cloudformation-stack-is-in-rollback-complete-state
# I want to keep the logging in github, thereby NOT letting aws automatically DELETE --on-failure DO_NOTHING,
if [[ "CREATE_FAILED" == "$STATUS" || "FAILED" == "$STATUS" || "DELETE_IN_PROGRESS" == "$STATUS" ]]; then

  deleteStack

fi

if [[ "" == "$STATUS" ]]; then

  echo -e "\nStack does not exist, creating..."

  aws cloudformation create-stack --on-failure DO_NOTHING \
    --region "${REGION}" \
    --stack-name "${STACK_NAME}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --template-body file://./CloudFormation/web.yaml \
    --parameters file://$PARAMETERS_FILE

  echo "Creating stack"

  sleep 10

  getStatus

  # @link https://stackoverflow.com/questions/34284256/how-to-output-the-stack-create-successful-info-until-all-the-resources-are-creat
  while [[ "$STATUS" == "REVIEW_IN_PROGRESS" ||
    "$STATUS" == "CREATE_IN_PROGRESS" ||
    "$STATUS" == "ROLLBACK_IN_PROGRESS" ]] \
    ; do
    # Wait 60 seconds and then check stack status again
    echo "Sleeping for 1 minute <$TRY>"
    sleep 60
    getStatus
    if [[ "$STATUS" != "ROLLBACK_IN_PROGRESS" ]]; then
      getLog "${VERSION}"
    fi
  done

  if [[ "$STATUS" == "FAILED" ||
    "$STATUS" == "CREATE_FAILED" ||
    "$STATUS" == "ROLLBACK_COMPLETE" ]] \
    ; then
    deleteStack
    exit 42
  fi

  echo "name=refresh::0" >>$GITHUB_OUTPUT
  echo "name=refresh::0" >>DEPLOY.txt

  exit 0

fi

echo -e "\nStack exists, attempting update... Current Status ($STATUS)"

set +e

update_output=$(aws cloudformation update-stack \
  --region "${REGION}" \
  --stack-name "${STACK_NAME}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --template-body file://./CloudFormation/web.yaml \
  --parameters file://$PARAMETERS_FILE 2>&1)
status=$?
set -e

echo "STATUS: $update_output"

if [ $status -ne 0 ]; then
  # Don't fail for no-op update
  if [[ $update_output == *"ValidationError"* && $update_output == *"No updates"* ]]; then
    echo -e "\nFinished create/update - no updates to be performed."
    echo "refresh=1" >> $GITHUB_OUTPUT
    echo "refresh=1" >> DEPLOY.txt
    exit 0
  elif [[ $update_output == *"UPDATE_IN_PROGRESS"* || $update_output == *"UPDATE_CLEANUP_IN_PROGRESS"* ]]; then
    echo -e "Updates already in progress!\n Changes from this build MAY NOT BE PUSHED!\nManually re-running this step MAY BE necessary!"
  else
    exit $status
  fi

fi

aws cloudformation wait stack-update-complete \
  --region "${REGION}" \
  --stack-name "${STACK_NAME}" &

UPDATE_PID=$!

echo "cloudformation wait <$UPDATE_PID>!"

while ps -p $UPDATE_PID; do
  echo -e "_________________________\nWaiting on pid <$UPDATE_PID> Sleeping for 60 seconds"
  sleep 60
  getLog "${4}"
done

wait $UPDATE_PID
update_status=$?
echo "Update finished with exit code ($status) :: $update_output"

if [ $update_status -ne 0 ]; then
  if [ $status -ne 0 ]; then
    echo "This error was from a previous build and MAY NOT reflect this builds status. Try re-running this step."
    exit $update_status
  fi
  exit $update_status
elif [ $status -ne 0 ]; then
  echo -e "This above log information was from a previous build which was successful. We will exit non-zero so we may re-run this build for the current version."
  exit $status
fi

echo "refresh=0" >>$GITHUB_OUTPUT
echo "refresh=0" >>DEPLOY.txt
