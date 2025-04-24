#!/bin/bash

set -eEBx

# Ensure that two arguments (domain and certificate ARN) are provided
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <domain> <cname> <value>"
  exit 1
fi

DOMAIN=$1
CNAME=$2
VALUE=$3

# Fetch Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query 'HostedZones[0].Id' --output text)

if [ "$HOSTED_ZONE_ID" == "None" ] || [ -z "$HOSTED_ZONE_ID" ]; then
  echo "No hosted zone found for $DOMAIN"
  exit 1
fi

aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch "{
  \"Changes\": [{
    \"Action\": \"UPSERT\",
    \"ResourceRecordSet\": {
      \"Name\": \"$CNAME\",
      \"Type\": \"CNAME\",
      \"TTL\": 300,
      \"ResourceRecords\": [{ \"Value\": \"$VALUE\" }]
    }
  }]
}"


echo "Route 53 CNAME record created for domain validation."
