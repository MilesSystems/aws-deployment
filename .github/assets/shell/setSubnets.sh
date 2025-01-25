#!/bin/bash

# Input parameters
SUBNET_IDENTIFIER=$1
HIGHLY_AVAILABLE_NAT=$2
ENABLE_VPC_FLOW_LOGS=$3
GITHUB_OUTPUT_FILE=$4

# Validate that SUBNET_IDENTIFIER is a number
if ! [[ "$SUBNET_IDENTIFIER" =~ ^[0-9]+$ ]]; then
  echo "Error: subnetIdentifier must be a number."
  exit 1
fi

# Convert SUBNET_IDENTIFIER to an integer and validate its range (0-255)
SUBNET_ID=$((SUBNET_IDENTIFIER))
if [[ $SUBNET_ID -lt 0 || $SUBNET_ID -gt 255 ]]; then
  echo "Error: subnetIdentifier must be between 0 and 255."
  exit 1
fi

# Define VPC and subnet CIDR blocks based on the SUBNET_ID
VPC_CIDR="10.${SUBNET_ID}.0.0/16"
PRIVATE_AZA_SUBNET="10.${SUBNET_ID}.0.0/19"
PUBLIC_AZA_SUBNET="10.${SUBNET_ID}.32.0/20"
DATA_AZA_SUBNET="10.${SUBNET_ID}.48.0/21"
PRIVATE_AZB_SUBNET="10.${SUBNET_ID}.64.0/19"
PUBLIC_AZB_SUBNET="10.${SUBNET_ID}.96.0/20"
DATA_AZB_SUBNET="10.${SUBNET_ID}.112.0/21"
PRIVATE_AZC_SUBNET="10.${SUBNET_ID}.128.0/19"
PUBLIC_AZC_SUBNET="10.${SUBNET_ID}.160.0/20"
DATA_AZC_SUBNET="10.${SUBNET_ID}.176.0/21"

# Ensure GITHUB_OUTPUT_FILE is provided and writable
if [[ -z "$GITHUB_OUTPUT_FILE" ]]; then
  echo "Error: GITHUB_OUTPUT file path is required."
  exit 1
fi

if [[ ! -w "$GITHUB_OUTPUT_FILE" && ! -e "$GITHUB_OUTPUT_FILE" ]]; then
  echo "Error: GITHUB_OUTPUT file does not exist or is not writable."
  exit 1
fi

# Output all parameters to the GitHub output file
cat <<EOL >>"$GITHUB_OUTPUT_FILE"
vpcCidrParam=${VPC_CIDR}
privateAZASubnetBlock=${PRIVATE_AZA_SUBNET}
publicAZASubnetBlock=${PUBLIC_AZA_SUBNET}
dataAZASubnetBlock=${DATA_AZA_SUBNET}
privateAZBSubnetBlock=${PRIVATE_AZB_SUBNET}
publicAZBSubnetBlock=${PUBLIC_AZB_SUBNET}
dataAZBSubnetBlock=${DATA_AZB_SUBNET}
privateAZCSubnetBlock=${PRIVATE_AZC_SUBNET}
publicAZCSubnetBlock=${PUBLIC_AZC_SUBNET}
dataAZCSubnetBlock=${DATA_AZC_SUBNET}
highlyAvailableNat=${HIGHLY_AVAILABLE_NAT}
enableVpcFlowLogs=${ENABLE_VPC_FLOW_LOGS}
EOL

echo "Subnet configuration successfully written to $GITHUB_OUTPUT_FILE"
