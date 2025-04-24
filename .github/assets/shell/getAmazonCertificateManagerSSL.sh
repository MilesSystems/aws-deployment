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
PENDING_CERTIFICATES=()
DOMAINS_WITH_CNAME=""

# Loop through each certificate to check for matching domains
for cert in ${CERTIFICATES//,/ }; do
  echo "Searching ($cert) for domain(s) (${DOMAINS[*]})"

  CERTIFIED_ALTERNATIVE=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.SubjectAlternativeNames' --output text || echo "")
  CERTIFIED_DOMAIN=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.DomainName' --output text || echo "")
  CERTIFIED_STATUS=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.Status' --output text || echo "")

  CERTIFIED_ALTERNATIVE="${CERTIFIED_ALTERNATIVE:-}"

  echo "CERTIFIED_ALTERNATIVE: $CERTIFIED_ALTERNATIVE"
  echo "CERTIFIED_DOMAIN: $CERTIFIED_DOMAIN"
  echo "CERTIFIED_STATUS: $CERTIFIED_STATUS"

  for domain in "${DOMAINS[@]}"; do
    domain=$(echo "$domain" | xargs)  # Trim whitespaces

    if [[ "$domain" == "$CERTIFIED_DOMAIN" || "$CERTIFIED_ALTERNATIVE" == *"$domain"* ]]; then
      echo "Domain found: $domain"

      # Add certificate to the appropriate list
      if [[ "$CERTIFIED_STATUS" == "ISSUED" ]]; then
        VALID_CERTIFICATES+=("$cert")
        break
      elif [[ "$CERTIFIED_STATUS" == "PENDING" ]]; then
        PENDING_CERTIFICATES+=("$cert")
      fi

      # Fetch the CNAME and validation value for DNS validation
      CNAME_RECORD=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.DomainValidationOptions[0].ResourceRecord' --output json)
      CNAME=$(echo $CNAME_RECORD | jq -r '.Name')
      VALUE=$(echo $CNAME_RECORD | jq -r '.Value')

      # Append the CNAME and value to the output string for later steps
      DOMAINS_WITH_CNAME="$DOMAINS_WITH_CNAME$domain=$CNAME:$VALUE,"

      break
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

    # Fetch the CNAME and validation value for DNS validation for the newly requested certificate
    CNAME_RECORD=$(aws acm describe-certificate --certificate-arn "$NEW_CERT" --query 'Certificate.DomainValidationOptions[0].ResourceRecord' --output json)
    CNAME=$(echo $CNAME_RECORD | jq -r '.Name')
    VALUE=$(echo $CNAME_RECORD | jq -r '.Value')

    # Append the CNAME and value to the output string for later steps
    DOMAINS_WITH_CNAME="$DOMAINS_WITH_CNAME$domain=$CNAME:$VALUE,"
  fi
done

# Output the list of valid certificates
CERTIFICATES=$(IFS=,; echo "${VALID_CERTIFICATES[*]}")
echo "CERTIFICATES: ($CERTIFICATES)"
echo "certificates=$CERTIFICATES" >> $GITHUB_OUTPUT
echo "certificates=$CERTIFICATES" >> CERTIFICATES.txt

# Output the list of pending certificates (if any)
PENDING_CERTIFICATES_LIST=$(IFS=,; echo "${PENDING_CERTIFICATES[*]}")
echo "PENDING_CERTIFICATES: ($PENDING_CERTIFICATES_LIST)"
echo "pending_certificates=$PENDING_CERTIFICATES_LIST" >> $GITHUB_OUTPUT
echo "pending_certificates=$PENDING_CERTIFICATES_LIST" >> CERTIFICATES.txt

# Output the domains with CNAME records to be used in later steps
echo "domains_with_cname=$DOMAINS_WITH_CNAME" >> $GITHUB_ENV
echo "domains_with_cname=$DOMAINS_WITH_CNAME" >> CERTIFICATES.txt
