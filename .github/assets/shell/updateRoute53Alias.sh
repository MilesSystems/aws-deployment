#!/bin/bash

set -eEBx

# Ensure that three arguments (domain, load balancer DNS, canonical hosted zone ID) are provided
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <domain> <load balancer dns> <canonical hosted zone id>"
  exit 1
fi

DOMAIN=$1
LB_DNS=$2
LB_ZONE=$3

# Traverse domain to find hosted zone
FULL_DOMAIN="$DOMAIN"
while [[ "$FULL_DOMAIN" == *.* ]]; do
  HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$FULL_DOMAIN" \
    --query "HostedZones[?Name == '$FULL_DOMAIN.'].Id" --output text)
  if [[ -n "$HOSTED_ZONE_ID" && "$HOSTED_ZONE_ID" != "None" ]]; then
    break
  fi
  FULL_DOMAIN="${FULL_DOMAIN#*.}"
done

if [[ -z "$HOSTED_ZONE_ID" || "$HOSTED_ZONE_ID" == "None" ]]; then
  echo "No hosted zone found for $DOMAIN"
  exit 1
fi

# UPSERT the A alias record
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch "{
  \"Changes\": [{
    \"Action\": \"UPSERT\",
    \"ResourceRecordSet\": {
      \"Name\": \"$DOMAIN\",
      \"Type\": \"A\",
      \"AliasTarget\": {
        \"HostedZoneId\": \"$LB_ZONE\",
        \"DNSName\": \"$LB_DNS\",
        \"EvaluateTargetHealth\": false
      }
    }
  }]
}"

echo "✅ Route 53 alias record created or updated for $DOMAIN → $LB_DNS in zone $FULL_DOMAIN ($HOSTED_ZONE_ID)"
