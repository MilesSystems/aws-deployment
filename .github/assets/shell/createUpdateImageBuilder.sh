#!/bin/bash

# Enable strict error handling
set -eEBxuo pipefail
shopt -s failglob

# Assign variables from arguments
DISTRIBUTION="$1"
AWS_REGION="$2"
ENVIRONMENT="$3"
REPOSITORY_NICENAME="$4"
ENCRYPTION_KEY="$5"
SECRET_PAYLOAD_ENCRYPTED="$6"
IMAGE_BUILDER_BASE_IMAGE_AMI="$7"
INFRASTRUCTURE="$8"
VOLUME_SIZE="$9"

# Ensure all required variables are provided
if [[ -z "$DISTRIBUTION" || -z "$AWS_REGION" || -z "$ENVIRONMENT" || -z "$REPOSITORY_NICENAME" ]]; then
  echo "Error: Missing required arguments." >&2
  echo "Usage: $0 <distribution> <aws-region> <environment> <repository-nicename> <script-build> <script-validate> <encryption-key> <secret-payload-encrypted> <base-image-ami> <infrastructure>" >&2
  exit 1
fi

echo "Checking if stack exists ..."

STACK_NAME="imagebuilder-$ENVIRONMENT-$REPOSITORY_NICENAME"

# Describe stacks and set action variables
if ! aws cloudformation describe-stacks --region "$AWS_REGION" --stack-name "$STACK_NAME"; then
  echo -e "\nStack does not exist, creating ..."
  action="create-stack"
  wait_action="stack-create-complete"
else
  echo -e "\nStack exists, attempting update ..."
  action="update-stack"
  wait_action="stack-update-complete"
fi

if [ -n "$SECRET_PAYLOAD_ENCRYPTED" ]; then
  chmod +x ./.github/assets/shell/parseSecrets.sh
  source ./.github/assets/shell/parseSecrets.sh \
    "$ENCRYPTION_KEY" \
    "$SECRET_PAYLOAD_ENCRYPTED" \
    ./imageBuilderScriptBuild \
    ./imageBuilderScriptValidate
fi

php ./.github/assets/php/createImageBuilderDataYaml.php ./imageBuilderScriptBuild ./imageBuilderScriptValidate

printf "Build data:\n%s\n" "$(cat ./CloudFormation/imagebuilder.yaml)"

# Get currently set variables and templates
CURRENT_VERSION=$(aws cloudformation describe-stacks --region "$AWS_REGION" --stack-name "$STACK_NAME" --query "Stacks[0].Parameters[?ParameterKey=='RecipeVersion'].ParameterValue" --output text) || CURRENT_VERSION=""
if [[ -z "$CURRENT_VERSION" ]]; then
  CURRENT_VERSION="0.0.0"
fi

echo "Current version: $CURRENT_VERSION"

template=$(aws cloudformation get-template --stack-name "$STACK_NAME" --query "TemplateBody" --output text 2>/dev/null) || template=""
echo "$template" > /tmp/latest_template.yaml
echo "Latest version template:"
cat /tmp/latest_template.yaml

parameters=$(aws cloudformation describe-stacks --region "$AWS_REGION" --stack-name "$STACK_NAME" --query "Stacks[0].Parameters" --output json 2>/dev/null) || parameters="[]"
echo "$parameters" > /tmp/latest_parameters.json
echo "Latest version parameters:"
cat /tmp/latest_parameters.json

PARAMETERS_FILE=$(php ./.github/assets/php/createAwsJsonParametersFile.php \
  "--Name=$STACK_NAME" \
  --InfrastructureConfigurationId="$INFRASTRUCTURE" \
  --DistributionConfigurationId="$DISTRIBUTION" \
  "--Ec2BaseImageAMI=$IMAGE_BUILDER_BASE_IMAGE_AMI" \
  "--RecipeVersion=$CURRENT_VERSION" \
  "--VolumeSize=$VOLUME_SIZE")

if ! diff -q ./CloudFormation/imagebuilder.yaml /tmp/latest_template.yaml > /dev/null; then
  diff --color=always -y -W 250 ./CloudFormation/imagebuilder.yaml /tmp/latest_template.yaml  >> "$GITHUB_STEP_SUMMARY" || true
  echo "Latest version template differ, bumping version..."

  YEAR=$(date +"%Y")
  MONTH=$(date +"%m")
  IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"

  if [[ "$major" == "$YEAR" && "$minor" == "$MONTH" ]]; then
    patch=$((patch + 1))
  else
    patch=0
  fi

  major=$YEAR
  minor=$MONTH
  NEW_VERSION="${major}.${minor}.${patch}"

  echo "Bumped version from $CURRENT_VERSION to $NEW_VERSION"
  CURRENT_VERSION=$NEW_VERSION
else
  echo "Templates are identical, no version bump needed."
  # Check if the template and parameters are exactly the same
  if diff -q "$PARAMETERS_FILE" /tmp/latest_parameters.json > /dev/null; then
      echo "No changes detected in parameters. Skipping stack update."
      echo "needImageRebuild=false" >> "$GITHUB_ENV"
      exit 0
  else
      diff --color=always -y -W 250 "$PARAMETERS_FILE" /tmp/latest_parameters.json >> "$GITHUB_STEP_SUMMARY" || true
      echo "Current parameters with version $CURRENT_VERSION:"
      cat "$PARAMETERS_FILE"
      rm "$PARAMETERS_FILE"
      echo "Changes detected. Proceeding with stack update..."
  fi
fi

echo "version=$CURRENT_VERSION" > IMAGE-BUILDER.txt

PARAMETERS_FILE=$(php ./.github/assets/php/createAwsJsonParametersFile.php \
  "--Name=$STACK_NAME" \
  --InfrastructureConfigurationId="$INFRASTRUCTURE" \
  --DistributionConfigurationId="$DISTRIBUTION" \
  "--Ec2BaseImageAMI=$IMAGE_BUILDER_BASE_IMAGE_AMI" \
  "--RecipeVersion=$CURRENT_VERSION" \
  "--VolumeSize=$VOLUME_SIZE")

echo "Current parameters file:"
echo "$PARAMETERS_FILE"
echo "End of parameters file."

output=$(aws cloudformation $action \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --template-body file://./CloudFormation/imagebuilder.yaml \
  --parameters "file://$PARAMETERS_FILE" \
  2>&1) || status=$?

if [ "${status:-0}" -ne 0 ] && [[ $action == "update-stack" ]]; then
  if [[ $output == *"ValidationError"* && $output == *"No updates"* ]]; then
    echo "needImageRebuild=false" >> "$GITHUB_ENV"
    echo -e "\nFinished create/update - no updates to be performed"
    exit 0
  else
    echo "$output"
    exit "$status"
  fi
fi

echo "needImageRebuild=true" >> "$GITHUB_ENV"
aws cloudformation wait "$wait_action" --region "$AWS_REGION" --stack-name "$STACK_NAME"

echo "Finished create/update successfully!"
