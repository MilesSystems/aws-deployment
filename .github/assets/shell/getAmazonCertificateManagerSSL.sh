#!/bin/bash

# Ensure at least one domain is provided
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 domain1,domain2,..."
  exit 1
fi

# Convert spaces to commas, then split into an array
DOMAINS_STRING="${1// /,}"

# Use mapfile to split the string into an array
IFS=',' read -r -a DOMAINS <<< "$DOMAINS_STRING"

# Remove empty values from the array
DOMAINS=("${DOMAINS[@]}")

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd "$SCRIPT_DIR" || exit 55
cd ../../..

err() {
  IFS=' ' read line file <<< "$(caller)"
  ERROR_MESSAGE="$( echo -e "Error occurred with status ($2) on/near ($(caller)) trapped in ($0):\n" &&
  awk 'NR>L-4 && NR<L+4 { printf "%-5d%3s%s\n",NR,(NR==L?">>>":""),$file }' L="$line" "$file" )"
  echo -e "$ERROR_MESSAGE"
  exit "$2"
}
trap 'err $LINENO $?' ERR

set -eEBxuo pipefail

# Fetch certificate ARNs from AWS
CERTIFICATES=$( aws acm list-certificates --query 'CertificateSummaryList[*].CertificateArn' --output text | sed 's/[[:space:]]/,/g' )

VALID_CERTIFICATES=()

# Loop through each certificate to check for matching domains
for cert in ${CERTIFICATES//,/ }; do
  echo "Searching ($cert) for domain(s) (${DOMAINS[*]})"

  CERTIFIED_ALTERNATIVE=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.SubjectAlternativeNames' --output text || echo "")
  CERTIFIED_DOMAIN=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.DomainName' --output text || echo "")
  CERTIFIED_STATUS=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.Status' --output text || echo "")

  echo "CERTIFIED_ALTERNATIVE: $CERTIFIED_ALTERNATIVE"
  echo "CERTIFIED_DOMAIN: $CERTIFIED_DOMAIN"
  echo "CERTIFIED_STATUS: $CERTIFIED_STATUS"

  for domain in "${DOMAINS[@]}"; do
    domain=$(echo "$domain" | xargs)  # Trim whitespaces

    if [[ "$domain" == "$CERTIFIED_DOMAIN" || "$CERTIFIED_ALTERNATIVE" == *"$domain"* ]]; then
      echo "Domain found: $domain"
      if [[ "$CERTIFIED_STATUS" == "ISSUED" ]]; then
        VALID_CERTIFICATES+=("$cert")
        break
      else
        echo "The certificate found for (${domain}) is in status ($CERTIFIED_STATUS)!"
        exit 14
      fi
    else
      echo "No match for domain: $domain"
    fi
  done
done

# Request new certificates for domains without valid certificates
for domain in "${DOMAINS[@]}"; do
  found=0
  for cert in "${VALID_CERTIFICATES[@]}"; do
    CERTIFIED_DOMAIN=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.DomainName' --output text || echo "")
    if [[ "$domain" == "$CERTIFIED_DOMAIN" || "$CERTIFIED_ALTERNATIVE" == *"$domain"* ]]; then
      found=1
      break
    fi
  done

  if [[ $found -eq 0 ]]; then
    echo "No certificate issued for $domain"
    NEW_CERT=$(aws acm request-certificate --domain-name "$domain" --subject-alternative-names "*.$domain" --validation-method DNS | jq --raw-output '.CertificateArn')
    echo "Sleeping for 20 seconds to allow AWS to process the request"
    sleep 20
    VALID_CERTIFICATES+=("$NEW_CERT")
  fi
done

# Verify all requested certificates are issued
for cert in "${VALID_CERTIFICATES[@]}"; do
  echo "Waiting for certificate to be validated: ($cert)"
  aws acm wait certificate-validated --certificate-arn "$cert"
done

# Output the list of valid certificates
CERTIFICATES=$(IFS=,; echo "${VALID_CERTIFICATES[*]}")
echo "CERTIFICATES: ($CERTIFICATES)"
echo "certificates=$CERTIFICATES" >> $GITHUB_OUTPUT
echo "certificates=$CERTIFICATES" >> LOAD-BALANCERS.txt

source LOAD-BALANCERS.txt
