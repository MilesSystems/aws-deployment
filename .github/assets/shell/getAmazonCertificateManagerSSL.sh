#!/bin/bash


# Ensure at least one domain is provided
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 domain1,domain2,..."
  exit 1
fi

# Capture the list of domains from the command line argument and split by comma
IFS=',' read -r -a DOMAINS <<< "$1"

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

# Fetch certificate ARNs from AWS
CERTIFICATES=$(aws acm list-certificates --query 'CertificateSummaryList[*].CertificateArn' --output text | sed 's/[[:space:]]/,/g')

VALID_CERTIFICATES=()

# Loop through each certificate to check for matching domains
for cert in ${CERTIFICATES//,/ }; do

  echo "Searching ($cert) for domain(s) (${DOMAINS[*]})"

  CERTIFIED_ALTERNATIVE=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.[SubjectAlternativeNames]' --output text)
  CERTIFIED_DOMAIN=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.[DomainName]' --output text)
  CERTIFIED_STATUS=$(aws acm describe-certificate --certificate-arn "$cert" --query 'Certificate.[Status]' --output text)

  for domain in "${DOMAINS[@]}"; do
    if [[ "$domain" == "$CERTIFIED_DOMAIN" ]]; then
      echo "Domain found: $CERTIFIED_DOMAIN"
      if [[ "ISSUED" == "$CERTIFIED_STATUS" ]]; then
        echo "${domain}=$cert" >> $GITHUB_OUTPUT
        echo "${domain}=$cert" >> IMAGE_BUILDER.txt
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
    if [[ "$domain" == "$cert" ]]; then
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
    echo "${domain}=$NEW_CERT" >> $GITHUB_OUTPUT
    echo "${domain}=$NEW_CERT" >> LOAD-BALANCERS.txt
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