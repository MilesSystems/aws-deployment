#!/bin/bash

set -e  # Exit on any error

# Validate inputs
if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <encryption_key> <encrypted_payload> <file1> [file2 ... fileN]"
  exit 1
fi

ENCRYPTION_KEY="$1"
ENCRYPTED_PAYLOAD="$2"
shift 2
FILES_TO_REPLACE=("$@")

# Decrypt the payload
echo "$ENCRYPTED_PAYLOAD" | openssl enc -aes-256-cbc -d -a -pbkdf2 -pass pass:"$ENCRYPTION_KEY" > decrypted_payload.json
echo "Decrypted payload written to decrypted_payload.json"

# Replace placeholders in files
for file in "${FILES_TO_REPLACE[@]}"; do
  if [ ! -f "$file" ]; then
    echo "File '$file' not found. Skipping."
    continue
  fi

  echo "Processing file: $file"
  for key in $(jq -r 'keys[]' decrypted_payload.json); do
    value=$(jq -r ".\"$key\"" decrypted_payload.json)

    # Temporarily disable verbose logging
    { set +x; } 2>/dev/null

    # Mask each line of the value
    while IFS= read -r line; do
      echo "::add-mask::$line"
    done <<< "$value"

    # Re-enable verbose logging if it was set
    { set -x; } 2>/dev/null

    # Replace placeholders in the file
    sed -i "s|$key|$value|g" "$file"
  done
done

echo "Placeholder replacement complete."
