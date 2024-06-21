#!/bin/bash

# This will delete the given ami-id and it's associated snapshots
# @link https://serverfault.com/questions/436648/how-to-delete-ec2-ami
# taken from link above

AMI_ID=$1

echo "Gather snapshots for AMI ($AMI_ID)"

# This will error if there are no snapshots which may happen if the distribution stage failed
set +e

SNAPSHOTS=$(aws ec2 describe-images --image-ids "${AMI_ID}" | jq '.Images[] .BlockDeviceMappings[] .Ebs .SnapshotId')

STATUS=$?

set -e

echo -e "SNAPSHOTS for ($AMI_ID) = ($SNAPSHOTS)"

if [ $STATUS -ne 0 ]; then

    if [[ "$SNAPSHOTS" == *"does not exist"* || "$SNAPSHOTS" == *"does not exist"* ]]; then

      echo "AMI does not exist"

      exit 0

    fi

    echo "Error describe-images for ami-id (${AMI_ID})"

    exit $STATUS

fi


echo "$$) Unregistering AMI (${AMI_ID})"

set +e

aws ec2 deregister-image --image-id "${AMI_ID}"

set -e

while IFS= read -r line; do

    if [[ "" == "$line" ]]; then

      continue

    fi

    echo "$$) Processing Snapshot ($line)"

    snapshot_id=$(echo "$line" | tr -d '"')

    if [[ "${snapshot_id}" != *"snap-"* ]]; then

      echo "ERROR: Invalid snapshot id (${snapshot_id})!!!"

      continue

    fi

    echo "$$) Deleting Snapshot (${snapshot_id})"

    set +e

    aws ec2 delete-snapshot --snapshot-id "${snapshot_id}" >> /dev/null 2>&1

    set -e

done <<< "$SNAPSHOTS"

echo "$$) Done"