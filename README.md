# GitHub Actions AWS Deployment Workflow(s)

Amazon Web Services (AWS) provides a wide range of services and tools to help you deploy and manage your applications.
To put it lightly, AWS is a vast and complex ecosystem that can be overwhelming for beginners. This repository aims to
quickly qet users up and running with AWS by providing a set of GitHub Actions workflows that automate the deployment of
CloudFormation templates. 

![ServiceArchitecture.svg](Diagrams%2FServiceArchitecture.svg)



# Configure

To set up the AWS access keys for your GitHub Actions workflow, you need to follow these steps:

1. Create IAM User: Log in to your AWS Management Console, go to the IAM service, and create a new IAM user or use an
   existing one. Make sure the user has the necessary permissions to deploy resources to your AWS environment.
    - AWSCloudFormationFullAccess
    - AmazonVPCFullAccess
    -
2. Generate Access Keys: After creating the IAM user, generate access keys for the user. You'll get an Access Key ID and
   a Secret Access Key.
3. Store Access Keys in GitHub Secrets: Go to your GitHub repository, navigate to "Settings" > "Secrets", and add the
   Access Key ID and Secret Access Key as secrets. For example, you can name them NONPROD_AWS_ACCESS_KEY_ID and
   NONPROD_AWS_SECRET_ACCESS_KEY.



## Actions Workflow Breakdown

1. Workflow Inputs: The workflow requires various inputs, including account information, regions, instance capacities,
   VPC settings, and optional settings for NAT and VPC flow logs.
2. Concurrency Management: It uses concurrency to ensure that only one workflow run per branch and repository is active
   at a time.
3. Job Definitions:
   - CONSTANTS: Initializes necessary variables and checks out the repository.
   - SHARED-NETWORKING: Sets up shared networking resources across specified AWS regions.
   - REGIONAL-NETWORKING: Sets up regional-specific networking resources.
   - LOAD-BALANCERS: Configures Application and Network Load Balancers.
   - MAGE-BUILDER: Builds and manages Amazon Machine Images (AMI) using AWS Image Builder.
   - DEPLOY: Deploys the application stack and manages auto-scaling groups.

### GitHub Actions OIDC

Create the OIDC role for the GitHub Actions workflow to assume.
You can use the following command from the root of this repository to create the role, note that the parameters are
case-sensitive and must match the GitHub organization, repository, and branch exactly:

```shell
aws cloudformation deploy \
   --template-file ./CloudFormation/githubConnect.yaml \
   --stack-name GitHubOIDCRoleStack \
   --capabilities CAPABILITY_NAMED_IAM \
   --parameter-overrides \
      GitHubOrg=your-github-org \
      GitHubRepo=your-repo \
      GitHubBranch=refs/heads/main \
      RoleName=YourCustomRoleName
```

You may be required to specify a cli `--profile` and/or `--region` if you have multiple profiles or regions configured
in your AWS CLI.
Use the command `aws configure sso --profile prod` to configure the profile for the AWS CLI to use the SSO credentials.

# AWS Architecture

https://github.com/aws-samples/aws-refarch-wordpress
https://docs.aws.amazon.com/whitepapers/latest/best-practices-wordpress/reference-architecture.html

## Networking

![NetworkingDiagram.svg](Diagrams%2FNetworkingDiagram.svg)

https://medium.com/aws-activate-startup-blog/practical-vpc-design-8412e1a18dcc#.g0txo2p4v
https://asecure.cloud/w/vpc/
https://awstip.com/provisioning-vpc-using-aws-cloudformation-7f6affc36a4e
https://aws.amazon.com/blogs/architecture/the-journey-to-cloud-networking/
https://www.slideshare.net/slideshow/20191105-aws-pretoria-meetup-setting-up-your-first-environment-and-adding-automation/190964275
https://docs.aws.amazon.com/whitepapers/latest/build-secure-enterprise-ml-platform/networking-architecture.html

#### HIPPA Networking

https://medium.com/aws-activate-startup-blog/architecting-your-healthcare-application-for-hipaa-compliance-part-2-ea841a6f62a7



## AWS Control Tower

![AccountStructure.svg](Diagrams%2FAccountStructure.svg)

https://aws.amazon.com/blogs/mt/customizing-account-configuration-aws-control-tower-lifecycle-events/
https://docs.aws.amazon.com/controltower/latest/userguide/creating-resources-with-cloudformation.html

## AWS CloudFormation

https://docs.aws.amazon.com/cloudformation/

```shell
Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash

set -eEBx

err() {
  IFS=' ' read line file <<< "$(caller)"
  echo "Error ($2) on/near line $line in $file"
  sleep 80
  aws autoscaling complete-lifecycle-action --lifecycle-action-result "ABANDON" --instance-id "$EC2_INSTANCE_ID" --lifecycle-hook-name "ready-hook" --auto-scaling-group-name "${AutoScalingGroup}" --region "${EC2_REGION}"
  /opt/aws/bin/cfn-signal --exit-code $2 --resource ${AutoScalingGroup} --region ${EC2_REGION} --stack ${AWS_STACK_NAME}
}
trap 'err $LINENO $?' ERR

EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
EC2_REGION=${EC2_AVAIL_ZONE%[a-z]}
AutoScalingGroup=$(aws autoscaling describe-auto-scaling-instances --instance-ids "$EC2_INSTANCE_ID" --query "AutoScalingInstances[0].AutoScalingGroupName" --output text)
AWS_STACK_NAME=$(aws cloudformation describe-stack-resources --physical-resource-id "$EC2_INSTANCE_ID" --query "StackResources[0].StackName" --output text)

if [ $? -eq 0 ]; then
  ACTION_RESULT='CONTINUE'
else
  ACTION_RESULT='ABANDON'
fi

aws autoscaling complete-lifecycle-action --instance-id "$EC2_INSTANCE_ID" --lifecycle-hook-name "ready-hook" --auto-scaling-group-name "$AutoScalingGroup" --region "$EC2_REGION" --lifecycle-action-result "$ACTION_RESULT"
 /opt/aws/bin/cfn-signal --stack "$AWS_STACK_NAME" --resource "$AutoScalingGroup" --region "$EC2_REGION" --exit-code $?
--//
```

```PowerShell
Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.ps1"

# PowerShell script

try {
    $EC2_INSTANCE_ID = (Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id)
    $EC2_AVAIL_ZONE = (Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/placement/availability-zone)
    $EC2_REGION = $EC2_AVAIL_ZONE -replace '[a-z]$'
    $AutoScalingGroup = (Get-ASAutoScalingInstance -InstanceId $EC2_INSTANCE_ID).AutoScalingGroupName
    $AWS_STACK_NAME = (Get-CFNStackResource -PhysicalResourceId $EC2_INSTANCE_ID).StackName
    
    if ($?) {
        $ACTION_RESULT = 'CONTINUE'
    } else {
        $ACTION_RESULT = 'ABANDON'
    }

    Complete-ASLifecycleAction -InstanceId $EC2_INSTANCE_ID -LifecycleHookName 'ready-hook' -AutoScalingGroupName $AutoScalingGroup -LifecycleActionResult $ACTION_RESULT -Region $EC2_REGION
    cfn-signal -e $? -r "Instance provisioning status" -s $AWS_STACK_NAME -r $AutoScalingGroup -region $EC2_REGION

} catch {
    Write-Host "Error occurred: $_"
    $ACTION_RESULT = 'ABANDON'
    Complete-ASLifecycleAction -InstanceId $EC2_INSTANCE_ID -LifecycleHookName 'ready-hook' -AutoScalingGroupName $AutoScalingGroup -LifecycleActionResult $ACTION_RESULT -Region $EC2_REGION
    cfn-signal -e 1 -r "Instance provisioning failed" -s $AWS_STACK_NAME -r $AutoScalingGroup -region $EC2_REGION
    exit 1
}

exit 0
--//
```

```yaml
name: Aws Deployment Workflow
on:
  push:
    branches:
      - main
jobs:
  set-variables:
    runs-on: ubuntu-latest
    outputs:
      account_name: ${{ steps.set-vars.outputs.account_name }}
      account_id: ${{ steps.set-vars.outputs.account_id }}
      current_branch: ${{ steps.set-vars.outputs.current_branch }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set account name, ID, and branch
        id: set-vars
        run: |
          DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
          CURRENT_BRANCH=${GITHUB_REF#refs/heads/}
          echo "current_branch=${CURRENT_BRANCH}" >> $GITHUB_ENV
          if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
            ACCOUNT_NAME=development
            ACCOUNT_ID=267396151348
          else
            ACCOUNT_NAME=production
            ACCOUNT_ID=391379212071
          fi
          echo "account_name=${ACCOUNT_NAME}" >> $GITHUB_ENV
          echo "account_id=${ACCOUNT_ID}" >> $GITHUB_ENV

  call-reusable-workflow:
    needs: set-variables
    uses: /.github/workflows/aws.yml@main
    with:
      accountName: ${{ needs.set-variables.outputs.account_name }}
      subnetIdentifier: 1
      networkAccountOidcRole: 12345
      instanceDeploymentAccountOidcRole: 67890
      environment: ${{ needs.set-variables.outputs.current_branch }}
      minimumRunningInstances: 1
      desiredInstanceCapacity: 1
      maximumRunningInstances: 50
      timeout: 600000
      highlyAvailableNat: false
      enableVpcFlowLogs: false

```

## Other Useful Commands

```bash
cat /etc/httpd/conf/httpd.conf
aws ssm start-session --target i-01d40968a6ceb1edf --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' --profile voltxt

ssh -o "UserKnownHostsFile=/dev/null" -o "IdentitiesOnly yes" -o "StrictHostKeyChecking=no" apache@localhost -p 9999 -N -L 7777:mydb-instance.cp0kek6goufi.us-east-1.rds.amazonaws.com:3306

aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,ImageId,Tags[*]]' --filters Name=instance-state-name,Values=running --output json | cat
php -r "passthru('aws ssm start-session --target ' . readline('instanceID: ') . ' --document-name AWS-StartPortForwardingSession --parameters \"{\\\"portNumber\\\":[\\\"22\\\"],\\\"localPortNumber\\\":[\\\"9999\\\"]}\"');"
```


