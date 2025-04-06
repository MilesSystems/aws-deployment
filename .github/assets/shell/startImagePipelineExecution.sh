#!/bin/bash

set -eEuo pipefail

ENVIRONMENT="$1"
REPOSITORY_NICENAME="$2"
IMAGES_TO_SAVE="$3"
NeedImageRebuild="${4:-false}"
ImageBuilderForceRebuild="${5:-false}"

PIPELINE_ARN=$(aws imagebuilder list-image-pipelines \
  --filter "name=name,values=imagebuilder-${ENVIRONMENT}-${REPOSITORY_NICENAME}" \
  --query 'imagePipelineList[?name==`imagebuilder-'"${ENVIRONMENT}"'-'"${REPOSITORY_NICENAME}"'`].arn' \
  --output text || true)

echo "PIPELINE_ARN: $PIPELINE_ARN"

if [[ -z "$PIPELINE_ARN" || "$PIPELINE_ARN" == "None" ]]; then
  echo "No pipeline was found. Exiting."
  exit 3
else
  echo "Pipeline was found."
fi

echo "pipeline_arn=$PIPELINE_ARN" >> $GITHUB_OUTPUT
echo "pipeline_arn=$PIPELINE_ARN" >> DEPLOY.txt

NEXT_PAGE=''
ALL_IMAGE_SUMMARIES="[]"

# Paginate through image lists
while :; do
  if [[ -n "$NEXT_PAGE" ]]; then
    PAGE_DATA=$(aws imagebuilder list-image-pipeline-images --image-pipeline-arn "$PIPELINE_ARN" \
      --filters "name=name,values=recipe-imagebuilder-${ENVIRONMENT}-${REPOSITORY_NICENAME}" \
      --next-token "$NEXT_PAGE")
  else
    PAGE_DATA=$(aws imagebuilder list-image-pipeline-images --image-pipeline-arn "$PIPELINE_ARN" \
      --filters "name=name,values=recipe-imagebuilder-${ENVIRONMENT}-${REPOSITORY_NICENAME}")
  fi

  echo "$PAGE_DATA" | jq --color-output

  PAGE_SUMMARIES=$(echo "$PAGE_DATA" | jq '.imageSummaryList')
  ALL_IMAGE_SUMMARIES=$(jq -s '.[0] + .[1]' <(echo "$ALL_IMAGE_SUMMARIES") <(echo "$PAGE_SUMMARIES"))

  NEXT_PAGE=$(echo "$PAGE_DATA" | jq -r '.nextToken // empty')
  [[ -z "$NEXT_PAGE" ]] && break

  echo "THE NEXT PAGE TOKEN ($NEXT_PAGE)"
done

IMAGE_ARNS=$(echo "$ALL_IMAGE_SUMMARIES" | jq -r '.[].arn')
IMAGE_STATUSES=$(echo "$ALL_IMAGE_SUMMARIES" | jq -r '.[].state.status')

# Print image summary
printf "\n%-40s %-20s\n" "IMAGE ARN" "STATUS"
printf "%-40s %-20s\n" "----------------------------------------" "--------------------"

IFS=$'\n' read -r -d '' -a IMAGE_ARN_ARRAY < <(echo "$IMAGE_ARNS" && printf '\0')
IFS=$'\n' read -r -d '' -a IMAGE_STATUS_ARRAY < <(echo "$IMAGE_STATUSES" && printf '\0')

for ((i=0; i<${#IMAGE_ARN_ARRAY[@]}; i++)); do
  printf "%-40s %-20s\n" "${IMAGE_ARN_ARRAY[$i]}" "${IMAGE_STATUS_ARRAY[$i]}"
done

TOTAL_ARNS=${#IMAGE_ARN_ARRAY[@]}
echo "TOTAL_ARNS = $TOTAL_ARNS"

count=0

for arn in ${IMAGE_ARN_ARRAY[@]}; do
  [[ -z "$arn" ]] && continue

  count=$((count + 1))
  [ ! $((count + IMAGES_TO_SAVE)) -lt $TOTAL_ARNS ] && break

  echo "Inspecting image $arn"

  aws imagebuilder get-image --image-build-version-arn "$arn" | jq --color-output '.image.outputResources'
  AMIS=$(aws imagebuilder get-image --image-build-version-arn "$arn" | jq -r '.image.outputResources.amis[].image')

  if [[ -z "$AMIS" ]]; then
    echo "No AMIs found for image $arn"
  else
    echo -e "Found the following AMIs:\n$AMIS\nCleaning them up."
    while IFS= read -r AMI; do
      source ./.github/assets/shell/deleteAMI.sh "$AMI"
    done <<< "$AMIS"
  fi

  echo "$count ) Deleting image: $arn"
  aws imagebuilder delete-image --image-build-version-arn "$arn" || echo "Failed to delete $arn"
done

# Get last image info if available
LAST_BUILD_INFO=$(echo "$ALL_IMAGE_SUMMARIES" | jq '.[-1]')

if [[ "$LAST_BUILD_INFO" == "null" || -z "$LAST_BUILD_INFO" ]]; then
  echo "No previous images found."
  LAST_BUILD_STATS="none"
  LAST_BUILD_ARN=""
  NeedImageRebuild="true"
else
  LAST_BUILD_ARN=$(echo "$LAST_BUILD_INFO" | jq -r '.arn')
  LAST_BUILD_STATS=$(echo "$LAST_BUILD_INFO" | jq -r '.state.status')
  echo "The last build status was ($LAST_BUILD_STATS)"
fi

if [[ "$NeedImageRebuild" == "true" || "$ImageBuilderForceRebuild" == "true" ]]; then
  if [[ "$LAST_BUILD_STATS" == "BUILDING" && -n "$LAST_BUILD_ARN" ]]; then
    echo "Canceling last image build ($LAST_BUILD_ARN)"
    aws imagebuilder cancel-image-creation --image-build-version-arn "$LAST_BUILD_ARN"
  fi

  echo "Creating new image for pipeline: $PIPELINE_ARN"

  BUILT_IMAGE_ARN=$(aws imagebuilder start-image-pipeline-execution \
    --image-pipeline-arn "$PIPELINE_ARN" \
    --query 'imageBuildVersionArn' \
    --output text)

  sleep 2

  echo "image_rebuilt=1" >> $GITHUB_OUTPUT
  echo "image_rebuilt=1" >> IMAGE_BUILDER.txt
  echo "STARTED BUILT_IMAGE_ARN=$BUILT_IMAGE_ARN"
else
  echo "No changes detected :)"
  BUILT_IMAGE_ARN="$LAST_BUILD_ARN"

  echo "image_rebuilt=0" >> $GITHUB_OUTPUT
  echo "image_rebuilt=0" >> IMAGE_BUILDER.txt
  echo "USING ALREADY BUILT_IMAGE_ARN=$BUILT_IMAGE_ARN"
fi

echo "image_arn=$BUILT_IMAGE_ARN" >> $GITHUB_OUTPUT
echo "image_arn=$BUILT_IMAGE_ARN" >> IMAGE_BUILDER.txt
