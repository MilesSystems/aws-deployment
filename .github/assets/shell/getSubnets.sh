#!/bin/bash

set -eEBx

# Usage: ./script.sh <VPC_ID> <REGION> <ACCOUNT_ID> <PRIVATE_AZA_SUBNET_BLOCK> <PUBLIC_AZA_SUBNET_BLOCK> <DATA_AZA_SUBNET_BLOCK> ...

if [[ "$#" -ne 12 ]]; then
  echo "Usage: $0 <VPC_ID> <REGION> <ACCOUNT_ID> <PRIVATE_AZA_SUBNET_BLOCK> <PUBLIC_AZA_SUBNET_BLOCK> <DATA_AZA_SUBNET_BLOCK> <PRIVATE_AZB_SUBNET_BLOCK> <PUBLIC_AZB_SUBNET_BLOCK> <DATA_AZB_SUBNET_BLOCK> <PRIVATE_AZC_SUBNET_BLOCK> <PUBLIC_AZC_SUBNET_BLOCK> <DATA_AZC_SUBNET_BLOCK>"
  exit 1
fi

VPC_ID=$1
REGION=$2
ACCOUNT_ID=$3
PRIVATE_AZA_SUBNET_BLOCK=$4
PUBLIC_AZA_SUBNET_BLOCK=$5
DATA_AZA_SUBNET_BLOCK=$6
PRIVATE_AZB_SUBNET_BLOCK=$7
PUBLIC_AZB_SUBNET_BLOCK=$8
DATA_AZB_SUBNET_BLOCK=$9
PRIVATE_AZC_SUBNET_BLOCK=${10}
PUBLIC_AZC_SUBNET_BLOCK=${11}
DATA_AZC_SUBNET_BLOCK=${12}
GITHUB_ENV=${13}

echo "Account ($ACCOUNT_ID) VPC ID ($VPC_ID) for region $REGION"
echo "Listing all subnets in region $REGION for verification"
aws ec2 describe-subnets --region "$REGION" --output json

# Function to retrieve subnet ID based on CIDR block
get_subnet_id() {
  local cidr_block=$1
  local subnet_id
  subnet_id=$(aws ec2 describe-subnets --region "$REGION" --query "Subnets[?CidrBlock=='$cidr_block'].SubnetId" --output text)
  if [[ -z "$subnet_id" ]]; then
    echo "Error: Unable to retrieve subnet ID for CIDR block $cidr_block in region $REGION."
    exit 1
  fi
  echo "$subnet_id"
}

# Retrieve subnet IDs
PRIVATE_AZA_SUBNET_ID=$(get_subnet_id "$PRIVATE_AZA_SUBNET_BLOCK")
PUBLIC_AZA_SUBNET_ID=$(get_subnet_id "$PUBLIC_AZA_SUBNET_BLOCK")
DATA_AZA_SUBNET_ID=$(get_subnet_id "$DATA_AZA_SUBNET_BLOCK")
PRIVATE_AZB_SUBNET_ID=$(get_subnet_id "$PRIVATE_AZB_SUBNET_BLOCK")
PUBLIC_AZB_SUBNET_ID=$(get_subnet_id "$PUBLIC_AZB_SUBNET_BLOCK")
DATA_AZB_SUBNET_ID=$(get_subnet_id "$DATA_AZB_SUBNET_BLOCK")
PRIVATE_AZC_SUBNET_ID=$(get_subnet_id "$PRIVATE_AZC_SUBNET_BLOCK")
PUBLIC_AZC_SUBNET_ID=$(get_subnet_id "$PUBLIC_AZC_SUBNET_BLOCK")
DATA_AZC_SUBNET_ID=$(get_subnet_id "$DATA_AZC_SUBNET_BLOCK")

# Set Environment Variables
echo "vpc=${VPC_ID}" >> "$GITHUB_ENV"

# Output subnet IDs
cat <<EOF > REGIONAL-NETWORKING.txt
vpc=${VPC_ID}
privateAZASubnet=${PRIVATE_AZA_SUBNET_ID}
publicAZASubnet=${PUBLIC_AZA_SUBNET_ID}
dataAZASubnet=${DATA_AZA_SUBNET_ID}
privateAZBSubnet=${PRIVATE_AZB_SUBNET_ID}
publicAZBSubnet=${PUBLIC_AZB_SUBNET_ID}
dataAZBSubnet=${DATA_AZB_SUBNET_ID}
privateAZCSubnet=${PRIVATE_AZC_SUBNET_ID}
publicAZCSubnet=${PUBLIC_AZC_SUBNET_ID}
dataAZCSubnet=${DATA_AZC_SUBNET_ID}
publicSubnet=${PUBLIC_AZA_SUBNET_ID},${PUBLIC_AZB_SUBNET_ID},${PUBLIC_AZC_SUBNET_ID}
privateSubnet=${PRIVATE_AZA_SUBNET_ID},${PRIVATE_AZB_SUBNET_ID},${PRIVATE_AZC_SUBNET_ID}
dataSubnet=${DATA_AZA_SUBNET_ID},${DATA_AZB_SUBNET_ID},${DATA_AZC_SUBNET_ID}
EOF

echo "Subnet IDs saved to REGIONAL-NETWORKING.txt"
cat REGIONAL-NETWORKING.txt
