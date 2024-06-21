#!/usr/bash

set -eEBx

ARN="$1"

echo "ARN=$ARN"

ENVIRONMENT="$2"

echo "ENVIRONMENT=$ENVIRONMENT"

REPOSITORY_NICENAME="$3"

echo "REPOSITORY_NICENAME=$REPOSITORY_NICENAME"

PIPELINE_ARN="$4"

echo "PIPELINE_ARN=$PIPELINE_ARN"

REGION="$5"

echo "REGION=$REGION"

BRANCH="$6"

echo "BRANCH=$BRANCH"

TRY=-1;

getStatus() {
  STATUS=$( aws imagebuilder get-image --output text --query 'image.state.status' --image-build-version-arn $ARN );
  TRY=$((1+$TRY));
}

echo "Sleeping for 2 minutes to allow the image to be get started.";

getStatus;

echo "Build detected ($STATUS)";

while [[ "$STATUS" == "PENDING"
      || "$STATUS" == "BUILDING"
      || "$STATUS" == "TESTING"
      || "$STATUS" == "DISTRIBUTING" ]]; do

    set +e;

    # this will run into a timing issue when image pending on pipeline create, but it doesn't matter, ignore errors with set and continue :)
    aws logs tail "/aws/imagebuilder/recipe-imagebuilder-${ENVIRONMENT}-${REPOSITORY_NICENAME}" --color on --since 70s

    set -e;

    echo "( $STATUS ) Waiting for 60 seconds... (min:$TRY)";

    sleep 60 ;

    getStatus;

    if [[ "$STATUS" == "AVAILABLE" ]];
    then

      echo "Oh ya! Our image is ($STATUS).";

      break 1;

    fi

    if [[ $STATUS == "FAILED" ]];
    then

      echo "Well damn.";

      break 1;

    fi

done

if [[ $STATUS == "FAILED" ]];
then

  echo "The build ended with status (FAILED).";

  FAILURE_REASON="$( aws imagebuilder get-image --output text --query 'image.state.reason' --image-build-version-arn "${ARN}" )";

  echo "FAILURE_REASON: $FAILURE_REASON";

  if [[ "$FAILURE_REASON" == "None of the provided Instance Types are available in the current region." ]]; then

    echo -e "Even though amazon could not run it due to capacity issues in (${REGION}); they still made an empty ami.. Fucking stupid & it costs us money.. \nDeleting failed ami due to lack of capacity in (${REGION}).."
    echo "Waiting to delete until @link https://support.console.aws.amazon.com/support/home?region=us-east-1#/case/?displayId=10755088491&language=en"
    # TODO - REMOVE THIS AFTER THE ABOVE CASE IS CLOSED
    echo ">> aws imagebuilder delete-image --image-build-version-arn ${ARN} || exit 8"

  fi

  exit 1;

fi

echo "Build detected ($STATUS)";

TRY=0;

getAMI() {

  AMI="$( aws imagebuilder get-image --output text --query 'image.outputResources.amis[0].image' --image-build-version-arn ${ARN} )";

  TRY=$((1+$TRY));

}

getAMI;

echo "AMI=$AMI";

if [[ "$AMI" == "None" ]];
then

  echo "No AMI has been found on ( ${PIPELINE_ARN} ) for ( ${ARN} )";

fi

while [[ "$AMI" == "None" ]];
do

    echo "Waiting 2 seconds ($STATUS)... (attempt:$TRY)";

    sleep 2 ;

    getAMI;

done

echo "AMI=$AMI";

echo "Running >> aws ec2 wait image-available --image-ids '$AMI'; # to verify";

echo "ami=$AMI" >> $GITHUB_OUTPUT
echo "ami=$AMI" >> IMAGE-BUILDER.txt

aws ec2 wait image-available --image-ids "$AMI";