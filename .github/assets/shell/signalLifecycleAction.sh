#!/bin/bash

set -x

SERVICE_NAME="aws_deployment_boot_scripts.service"

# Check if the service exists
if systemctl list-unit-files | grep -q "^${SERVICE_NAME}"; then
  # Service exists, check its status
  systemctl status "${SERVICE_NAME}"
else
  echo "Service ${SERVICE_NAME} does not exist."
fi

EC2_INSTANCE_ID=$(jq -r '.["instance-id"]' /var/aws-deployment/aws.json)
EC2_REGION=$(jq -r '.placement.region' /var/aws-deployment/aws.json)
AutoScalingGroup=$(aws autoscaling describe-auto-scaling-instances --instance-ids "$EC2_INSTANCE_ID" --query "AutoScalingInstances[0].AutoScalingGroupName" --output text)
AWS_STACK_NAME=$(aws cloudformation describe-stack-resources --physical-resource-id "$EC2_INSTANCE_ID" --query "StackResources[0].StackName" --output text)

sleep 80

if [ "$1" = "0" ] || [ -z "$1" ]; then
  ACTION_RESULT='CONTINUE'
  EXIT_CODE=0
else
  ACTION_RESULT='ABANDON'
  EXIT_CODE=1
fi

aws autoscaling complete-lifecycle-action --instance-id "$EC2_INSTANCE_ID" --lifecycle-hook-name "ready-hook" --auto-scaling-group-name "$AutoScalingGroup" --region "$EC2_REGION" --lifecycle-action-result "$ACTION_RESULT"

/opt/aws/bin/cfn-signal --stack "$AWS_STACK_NAME" --resource "AutoScalingGroup" --region "$EC2_REGION" --exit-code "$EXIT_CODE"

exit $1
