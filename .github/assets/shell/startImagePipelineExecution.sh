#!/bin/bash

ENVIRONMENT="$1"

REPOSITORY_NICENAME="$2"

IMAGES_TO_SAVE="$3"

NeedImageRebuild="${4}"

ImageBuilderForceRebuild="${5}"

# [+] RDS What's New: https://aws.amazon.com/new/
# [+] AWS Database Blog: https://aws.amazon.com/blogs/database/
# [+] AWS Forums: https://forums.aws.amazon.com/forum.jspa?forumID=60
PIPELINE_ARN=$(aws imagebuilder list-image-pipelines --output text --filter "name=name,values=imagebuilder-${ENVIRONMENT}-${REPOSITORY_NICENAME}" --query 'imagePipelineList[-1].arn')

echo "PIPELINE_ARN: $PIPELINE_ARN"

if [[ "" == "$PIPELINE_ARN" || "None" == "$PIPELINE_ARN" ]]; then
  echo "No pipeline was found. Exiting."
  exit 3
else
  echo "Pipeline was found."
fi

echo "pipeline_arn=$PIPELINE_ARN" >>$GITHUB_OUTPUT
echo "pipeline_arn=$PIPELINE_ARN" >>DEPLOY.txt

NEXT_PAGE=''

IMAGE_ARNS=''

IMAGE_BUILDER_IMAGES=$(aws imagebuilder list-image-pipeline-images --image-pipeline-arn "$PIPELINE_ARN" \
  --filters "name=name,values=recipe-imagebuilder-${ENVIRONMENT}-${REPOSITORY_NICENAME}")

# Before we create new images we need to clear old resources costing us $$$ in AWS
while :; do

  if [[ "" != "$NEXT_PAGE" ]]; then

    IMAGE_BUILDER_IMAGES=$(aws imagebuilder list-image-pipeline-images --image-pipeline-arn "$PIPELINE_ARN" \
      --filters "name=name,values=recipe-imagebuilder-${ENVIRONMENT}-${REPOSITORY_NICENAME}" \
      --next-token "$NEXT_PAGE")

  fi

  echo "$IMAGE_BUILDER_IMAGES" | jq --color-output

  IMAGE_ARNS="$IMAGE_ARNS $(echo "$IMAGE_BUILDER_IMAGES" | jq '.imageSummaryList[].arn' --raw-output)"

  if [[ "$IMAGE_BUILDER_IMAGES" == *"nextToken"* ]]; then

    NEXT_PAGE=$(echo "$IMAGE_BUILDER_IMAGES" | jq '.nextToken')

  else

    break

  fi

  echo "THE NEXT PAGE TOKEN ($NEXT_PAGE)"

done

echo "$IMAGE_ARNS"

TOTAL_ARNS=$(echo "$IMAGE_ARNS" | wc -l | awk '{$1=$1};1')

count=0

echo "TOTAL_ARNS = $TOTAL_ARNS"

# The last 10 results must be kept regardless of date
# You must iterate to the last page to get the newest images.
# If the newest image ended in failure you must run the pipeline

for arn in $IMAGE_ARNS; do

  [[ "" == "$arn" ]] && continue

  count=$((count + 1))

  [ ! $((count + IMAGES_TO_SAVE)) -lt $TOTAL_ARNS ] && break

  aws imagebuilder get-image --image-build-version-arn "$arn" | jq --color-output '.image.outputResources'

  AMIS=$(aws imagebuilder get-image --image-build-version-arn "$arn" | jq '.image.outputResources.amis[].image' --raw-output)

  if [ "" = "$AMIS" ]; then

    echo "No AMI(s) found!"

  else

    echo -e "Found the following AMIs \n${AMIS}\nWe will gather EBS storage ID for deletion as well."

    while IFS= read -r AMI; do

      source ./.github/assets/shell/deleteAMI.sh "$AMI"

    done <<<"$AMIS"

  fi

  echo "$count ) aws imagebuilder delete-image --image-build-version-arn $arn"

  # TODO - We need to make sure we have the last 10 successful builds..
  aws imagebuilder delete-image --image-build-version-arn $arn || exit 8

  IMAGE_ARNS="${IMAGE_ARNS[@]/$arn/}"

done

LAST_BUILD_INFO=$(echo $IMAGE_BUILDER_IMAGES | jq '.imageSummaryList[-1]')

LAST_BUILD_ARN=$(echo $LAST_BUILD_INFO | jq '.arn' --raw-output)

LAST_BUILD_STATS=$(echo $LAST_BUILD_INFO | jq '.state.status' --raw-output)

echo "The last build status was ($LAST_BUILD_STATS)"

# we should change this outputs.all nonsense to a bash regex comparison =~
# @link https://stackoverflow.com/questions/17420994/how-can-i-match-a-string-with-a-regex-in-bash
if [[ "true" == "$NeedImageRebuild" || "true" == "$ImageBuilderForceRebuild" ]] \
  ; then

  if [[ "\"BUILDING\"" == "$LAST_BUILD_STATS" ]]; then

    echo "Canceling last image build ($LAST_BUILD_ARN)"

    aws imagebuilder cancel-image-creation --image-build-version-arn "$LAST_BUILD_ARN"

  fi

  echo "Creating new image."

  echo "PIPELINE_ARN=$PIPELINE_ARN"

  BUILT_IMAGE_ARN=$(aws imagebuilder start-image-pipeline-execution \
    --image-pipeline-arn "$PIPELINE_ARN" \
    --query 'imageBuildVersionArn' \
    --output text)

  sleep 2

  echo "image_rebuilt=1" >> $GITHUB_OUTPUT
  echo "image_rebuilt=1" >> IMAGE_BUILDER.txt

  echo "STARTED BUILT_IMAGE_ARN=$BUILT_IMAGE_ARN"

else

  echo "image_rebuilt=0" >> $GITHUB_OUTPUT
  echo "image_rebuilt=0" >> IMAGE-BUILDER.txt

  echo "No changes detected :)"

  # https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html
  BUILT_IMAGE_ARN="$LAST_BUILD_ARN"

  echo "USING ALREADY BUILT_IMAGE_ARN=$BUILT_IMAGE_ARN"
fi

echo "image_arn=$BUILT_IMAGE_ARN" >> $GITHUB_OUTPUT
echo "image_arn=$BUILT_IMAGE_ARN" >>IMAGE-BUILDER.txt
