#!/bin/bash

# Abort any pending lifecycle actions for the stack's Auto Scaling group
# Arguments:
#   1. CloudFormation stack name
#   2. AWS region

set -eEx

STACK_NAME="$1"
REGION="$2"

if [[ -z "$STACK_NAME" || -z "$REGION" ]]; then
  echo "Usage: $0 <stack-name> <region>"
  exit 1
fi

# Resolve the Auto Scaling group name from the stack
ASG_NAME=$(aws --region "$REGION" cloudformation describe-stack-resources \
  --stack-name "$STACK_NAME" \
  --logical-resource-id AutoScalingGroup \
  --query 'StackResources[0].PhysicalResourceId' --output text)

echo "Auto Scaling Group: $ASG_NAME"

# Find instances stuck in a pending lifecycle state
PENDING_IDS=$(aws --region "$REGION" autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name "$ASG_NAME" \
  --query 'AutoScalingGroups[0].Instances[?starts_with(LifecycleState, `Pending`) == `true`].InstanceId' \
  --output text)

if [[ -z "$PENDING_IDS" ]]; then
  echo "No pending lifecycle actions to abandon"
else
  for id in $PENDING_IDS; do
    echo "Signaling ABANDON for instance $id"
    aws --region "$REGION" autoscaling complete-lifecycle-action \
      --instance-id "$id" \
      --lifecycle-hook-name ready-hook \
      --auto-scaling-group-name "$ASG_NAME" \
      --lifecycle-action-result ABANDON || true
  done
fi

echo "Canceling stack update for $STACK_NAME"
aws --region "$REGION" cloudformation cancel-update-stack --stack-name "$STACK_NAME" || true
