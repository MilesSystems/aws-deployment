# GitHub Actions AWS Deployment Workflow(s)

Amazon Web Services (AWS) provides a wide range of services and tools to help you deploy and manage your applications.
To put it lightly, AWS is a vast and complex ecosystem that can be overwhelming for beginners. This repository aims to
quickly qet users up and running with AWS by providing a set of GitHub Actions workflows that automate the deployment of
CloudFormation templates.


[Mastering Chaos - A Netflix Guide to Microservices](https://www.youtube.com/watch?v=CZ3wIuvmHeM&t=2589s)


## Rerunning Failed vs Rerunning All 
If you have your version constrained to a dynamic branch like dev-main then you may notice some unusual side effects of 
rerunning only failed jobs. If this repositories branch is updated then you may see unexpected/mixed results using rerun failed.
Restricting the action to a specific version will avoid this issue, or just re-running all everytime needed.

## 1Strategy LLC has may useful CloudFormation templates for AWS

Thanks [1Strategy LLC](https://github.com/1Strategy) for their great open-source work! All Networking and VPC that are directly
from 1Strategy LLC should have correct attribution and licensing information in the
top of the file. Our custom templates are just [AWS Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html) we've built for
you! Our custom files, as well as 1Strategy LLC's, are licensed under the Apache License, Version 2.0.

![ServiceArchitecture.svg](Diagrams%2FServiceArchitecture.svg)

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

### GitHub Actions OIDC (actions aws setup)

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

## AWS CloudFormation

https://docs.aws.amazon.com/cloudformation/

```yaml
name: Aws Deployment Workflow

on:
  push:
    branches:
      - main

concurrency:
  group: aws-${{ github.repository }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  id-token: write
  contents: read


jobs:
  variables:
    runs-on: ubuntu-latest
    outputs:
      account_name: ${{ steps.set-vars.outputs.account_name }}
      account_oidc_role: ${{ steps.set-vars.outputs.account_oidc_role }}
      network_account_oidc_role: ${{ steps.set-vars.outputs.network_account_oidc_role }}
      current_branch: ${{ steps.set-vars.outputs.current_branch }}
      subnet_identifier: ${{ steps.set-vars.outputs.subnet_identifier }}
      imageBuilderScriptBuild: ${{ steps.set-vars.outputs.imageBuilderScriptBuild }}
      imageBuilderScriptValidate: ${{ steps.set-vars.outputs.imageBuilderScriptValidate }}
      deployUserDataScript: ${{ steps.set-vars.outputs.deployUserDataScript }}
      deployTrackUserDataScript: ${{ steps.set-vars.outputs.deployTrackUserDataScript }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set account name, ID, and branch
        id: set-vars
        env:
          imageBuilderScriptValidate: |
            #!/bin/bash
            echo 'Validating dependencies step #systemctl status httpd'
            

          deployUserDataScript: |
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
            
            mkdir -p /var/aws-deployment
            
            curl -s https://gist.githubusercontent.com/RichardTMiles/145f7a8e85c974ef7c7637a9862a1a74/raw/aws_ec2_metadata_json.php | php > /var/aws-deployment/aws.json
            
            EC2_INSTANCE_ID=$(jq -r '.["instance-id"]' /var/aws-deployment/aws.json)
            EC2_REGION=$(jq -r '.placement.region' /var/aws-deployment/aws.json)
            AutoScalingGroup=$(aws autoscaling describe-auto-scaling-instances --instance-ids "$EC2_INSTANCE_ID" --query "AutoScalingInstances[0].AutoScalingGroupName" --output text)            
            AWS_STACK_NAME=$(aws cloudformation describe-stack-resources --physical-resource-id "$EC2_INSTANCE_ID" --query "StackResources[0].StackName" --output text)

            sudo cat > '/var/aws-deployment/success.sh' <<EOF
            #!/bin/bash
            
            set -x
            if [ "\$1" = "0" ] || [ -z "\$1" ]; then
              ACTION_RESULT='CONTINUE'
              EXIT_CODE=0
            else
              ACTION_RESULT='ABANDON'
              EXIT_CODE=1
            fi
            aws autoscaling complete-lifecycle-action --instance-id "$EC2_INSTANCE_ID" --lifecycle-hook-name "ready-hook" --auto-scaling-group-name "$AutoScalingGroup" --region "$EC2_REGION" --lifecycle-action-result "\$ACTION_RESULT"
            /opt/aws/bin/cfn-signal --stack "$AWS_STACK_NAME" --resource "AutoScalingGroup" --region "$EC2_REGION" --exit-code "\$EXIT_CODE"
            exit \$1
            EOF
            
            chmod +x /var/aws-deployment/success.sh
            systemctl enable "aws_deployment_boot_scripts"
            systemctl start "aws_deployment_boot_scripts"
              
            --//

          deployTrackUserDataScript: |
            #!/bin/bash
            set -x
            whoami
            systemctl status --lines=0 aws_deployment_boot_scripts || echo "Exit code: $?" 
            journalctl --since "1min ago" --utc -u aws_deployment_boot_scripts || echo "Exit code: $?"
            cat /var/log/cloud-init-output.log || echo "Exit code: $?"
            exit 0

        run: |        
          
          imageBuilderScriptBuild=$(cat << 'EOF1'
          ${{ env.imageBuilderScriptBuild }}
          EOF1
          )
          
          imageBuilderScriptValidate=$(cat << 'EOF1'
          ${{ env.imageBuilderScriptValidate }}
          EOF1
          )
          
          deployUserDataScript=$(cat << 'EOF1'
          ${{ env.deployUserDataScript }}
          EOF1
          )
          
          deployTrackUserDataScript=$(cat << 'EOF1'
          ${{ env.deployTrackUserDataScript }}
          EOF1
          )
          
          echo "imageBuilderScriptBuild<<'EOF'"$'\n'"$imageBuilderScriptBuild"$'\n\'EOF\'\n' >> $GITHUB_OUTPUT
          echo "imageBuilderScriptValidate<<'EOF'"$'\n'"$imageBuilderScriptValidate"$'\n\'EOF\'\n' >> $GITHUB_OUTPUT
          echo "deployUserDataScript<<'EOF'"$'\n'"$deployUserDataScript"$'\n\'EOF\'\n' >> $GITHUB_OUTPUT
          echo "deployTrackUserDataScript<<'EOF'"$'\n'"$deployTrackUserDataScript"$'\n\'EOF\'\n' >> $GITHUB_OUTPUT
          
          DEFAULT_BRANCH=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
          CURRENT_BRANCH="${GITHUB_REF#refs/heads/}"
          echo "current_branch=${CURRENT_BRANCH}" >> $GITHUB_OUTPUT
          echo "network_account_oidc_role=arn:aws:iam::992382562178:role/GitHubOIDCRole" >> $GITHUB_OUTPUT

          if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
            ACCOUNT_NAME=development
            SUBNET_IDENTIFIER=1
            ACCOUNT_OIDC_ROLE="arn:aws:iam::891377116173:role/GitHubOIDCRole"
          else
            ACCOUNT_NAME=production
            SUBNET_IDENTIFIER=0
            ACCOUNT_OIDC_ROLE="arn:aws:iam::637423336338:role/GitHubOIDCRole"
          fi
          
          echo "account_name=${ACCOUNT_NAME}" >> $GITHUB_OUTPUT
          echo "subnet_identifier=${SUBNET_IDENTIFIER}" >> $GITHUB_OUTPUT
          echo "account_oidc_role=${ACCOUNT_OIDC_ROLE}" >> $GITHUB_OUTPUT
          
          cat $GITHUB_OUTPUT

  AmazonWebServicesDeployment:
    needs: variables
    uses: MilesSystems/aws-deployment/.github/workflows/aws.yml@main
    secrets: inherit
    with:
      regions: us-east-1
      emailDomain: example.com
      accountName: ${{ needs.variables.outputs.account_name }}
      subnetIdentifier: ${{ needs.variables.outputs.subnet_identifier }}
      networkAccountOidcRole: ${{ needs.variables.outputs.network_account_oidc_role }}
      instanceDeploymentAccountOidcRole: ${{ needs.variables.outputs.account_oidc_role }}
      environment: ${{ needs.variables.outputs.current_branch }}
      imageBuilderScriptBuild: |
        #!/bin/bash
        
        set -eEBx
        
        dnf upgrade -y
        
        mkdir -p /var/aws-deployment
        
        groupadd apache
        useradd apache -g apache -s /usr/bin/zsh
        echo apache:apache | chpasswd
        
        wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
        rpm -ihv --nodeps ./epel-release-latest-8.noarch.rpm
        wget https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm 
        rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
        dnf install -y mysql80-community-release-el9-1.noarch.rpm
        dnf install -y epel-release gcc-c++ make git jq perl-Digest-SHA httpd httpd-tools mod_ssl links pip socat nvme-cli vsftpd expect aws-cli nodejs httpd perl pcre-devel gcc zlib zlib-devel php-pear php-devel libzip libzip-devel re2c bison autoconf make libtool ccache libxml2-devel sqlite-devel  php php-{common,pear,cgi,mbstring,curl,gd,mysqlnd,gettext,json,xml,fpm,intl,posix,dom,zip} zsh  mysql-community-server  inotify-tools ccze
        
        OHMYZSH="$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        sudo -u apache sh -c "$OHMYZSH" 2>&1
        sh -c "$OHMYZSH" 2>&1
        
        eval $(ssh-agent)
        
        mkdir -p /home/apache/.ssh/
        
        cat > /home/apache/.ssh/id_github_pull_key <<EOF
        -----BEGIN OPENSSH PRIVATE KEY-----
        your deployment key goes here
        -----END OPENSSH PRIVATE KEY-----
        EOF
        
        cat > /home/apache/.ssh/config <<EOF
        Host github.com
          IdentityFile /home/apache/.ssh/id_github_pull_key
          IdentitiesOnly yes
        EOF
        
        chown -R apache:apache /home/apache/
        chmod g+rwX /home/apache/ -R
        sudo -u apache chmod 600 /home/apache/.ssh/id_github_pull_key
        sudo -u apache chmod 600 /home/apache/.ssh/config
        sudo -u apache ssh -o StrictHostKeyChecking=no -i /home/apache/.ssh/id_github_pull_key -T git@github.com 2>&1 || true
        
        sed -i -e 's/ssm-user:\/bin\/bash/ssm-user:\/usr\/bin\/zsh/g' \
                   -e 's/apache:\/bin\/bash/apache:\/usr\/bin\/zsh/g' /etc/passwd
        
        sed -i -e 's/\/usr\/libexec\/openssh\/sftp-server/internal-sftp/g' \
                   -e 's/#Banner none/Banner \/etc\/ssh\/sshd-banner/g' \
                   -e 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        
        echo -e "\nMatch Group apache\nAllowTcpForwarding yes\nForceCommand internal-sftp" >>/etc/ssh/sshd_config
        
        sed -i 's/AllowOverride None/AllowOverride All/g' /etc/httpd/conf/httpd.conf
        
        systemctl restart sshd
        
        echo "Installing Custom PHP Version --branch (apache_websocket_accept)"
        
        dnf install -y libcurl-devel httpd-devel libffi-devel oniguruma-devel readline-devel libsodium-devel libargon2-devel systemd-devel --allowerasing
        git clone https://github.com/RichardTMiles/php-src.git --depth 1 --single-branch --branch=feature/apache_websocket_accept ~/php-src 
        cd ~/php-src
        ./buildconf
        
        # For development
        # flags that dont work:: --with-gd
        ./configure --enable-fpm --with-openssl --enable-calendar --with-curl --enable-exif \
        --with-ffi -enable-mbstring --with-mysqli --enable-pcntl --with-pdo-mysql --with-readline --enable-shmop \
        --enable-soap --enable-sockets --with-sodium --with-password-argon2 --with-pear --with-zip --with-apxs2 \
        --with-fpm-systemd --with-fpm-selinux --with-zlib --with-config-file-path=/etc/
        
        num_procs=$(nproc)
        
        # Calculate the number of jobs, subtracting 1 if num_procs is greater than 1
        if [ "$num_procs" -gt 1 ]; then
          jobs=$((num_procs - 1))
        else
          jobs=$num_procs
        fi
        
        # Run make with the calculated number of jobs
        make -j "$jobs"
        
        ./sapi/cli/php -v
        rm -rf /usr/local/bin/php /usr/bin/php /usr/sbin/php-fpm /sbin/php-fpm
        cp /root/php-src/sapi/cli/php /usr/local/bin/php
        cp /root/php-src/sapi/cli/php /usr/bin/php
        cp /root/php-src/sapi/fpm/php-fpm /usr/local/sbin/php-fpm
        cp /root/php-src/sapi/fpm/php-fpm /usr/sbin/php-fpm
        cp /root/php-src/sapi/fpm/php-fpm /sbin/php-fpm
        cd /tmp/
        
        # The value of post_max_size must be higher than the value of upload_max_filesize
        # The value of memory_limit must be higher than the value of post_max_size.
        # memory_limit > post_max_size > upload_max_filesize
        sed -i -e 's/memory_limit = 128M/memory_limit = 1024M/g' \
          -e 's/post_max_size = 8M/post_max_size = 512M/g' \
          -e 's/upload_max_filesize = 2M/upload_max_filesize = 512M/g' \
          -e 's/max_execution_time = 30/max_execution_time = 300/g' \
          -e 's/max_input_time = 60/max_input_time = 1000/g' /etc/php.ini
        
        # @link https://unix.stackexchange.com/questions/13751/kernel-inotify-watch-limit-reached/13757#13757?newreg=bff5352630a1447abcaa9a48664ef6a7
        # @link https://stackoverflow.com/questions/535768/what-is-a-reasonable-amount-of-inotify-watches-with-linux
        # @link https://stackoverflow.com/questions/69337154/aws-ec2-terminal-session-terminated-with-plugin-with-name-standard-stream-not-f
        sudo sysctl fs.inotify.max_user_watches=2147483647
        # @note preserved across restarts
        echo "fs.inotify.max_user_watches=2147483647" >> /etc/sysctl.conf sysctl -p
        
        
        cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.default
        
        # PHP-FPM user change
        # PHP-FPM will also hijack the error log ini if set.
        # restart with systemctl restart php-fpm
        sed -i -e 's/user = apache/user = apache/g' \
                  -e 's/group = apache/group = apache/g' \
                  -e 's/;listen.owner = nobody/listen.owner = apache/g' \
                  -e 's/;listen.group = nobody/listen.group = apache/g' \
                  -e 's/;listen.mode = 0660/listen.mode = 0660/g' \
                  -e 's/php_admin_value\[error_log\]/;php_admin_value[error_log]/g' \
                  -e 's/php_admin_flag\[log_errors\]/;php_admin_flag[log_errors]/g' \
                  -e 's/;catch_workers_output/catch_workers_output/g' \
                  -e 's/listen.acl_users = apache,nginx/;listen.acl_users = apache,nginx/g' /etc/php-fpm.d/www.conf
        
        cp -s /etc/php-fpm.d/www.conf /usr/local/etc/php-fpm.conf
        
        rm -f /usr/lib/systemd/system/php-fpm.service
        
        cp /root/php-src/sapi/fpm/php-fpm.service /usr/lib/systemd/system/php-fpm.service
        
        # @link https://stackoverflow.com/questions/1421478/how-do-i-use-a-new-line-replacement-in-a-bsd-sed
        sed -i -e 's/ProtectSystem=full/#ProtectSystem=full/g' \
        -e 's/ExecStart=/ExecStartPre=\/bin\/mkdir -p \/usr\/local\/var\/log\/ \nExecStart=/g' \
        -e 's/ExecStart=/ExecStartPre=\/bin\/mkdir -p \/run\/php-fpm \nExecStart=/g' /usr/lib/systemd/system/php-fpm.service
        
        cat > /etc/systemd/system/aws_deployment_boot_scripts.service <<EOF
        [Unit]
        Description=Fedora boot script(s) invoked by cloud-init (web.yaml)
        After=network.target
        
        [Service]
        Type=oneshot
        KillMode=process
        User=root
        ExecStartPre=/bin/chmod -R +x /var/aws-deployment/
        ExecStartPre=/bin/ls --color=always -lah /var/aws-deployment/
        ExecStartPre=/var/aws-deployment/success.sh 0
        ExecStartPre=/usr/bin/rm -rf /var/www/html/
        ExecStartPre=/usr/bin/chown -R apache:apache /var/www/
        ExecStartPre=/usr/bin/sudo -u apache git clone git@github.com:example/example.com.git /var/www/html
        ExecStartPre=/usr/bin/sudo -u apache chmod +x /var/www/html/getComposer.sh
        ExecStartPre=/bin/bash -c 'cd /var/www/html && sudo -u apache ./getComposer.sh'
        ExecStartPre=/usr/bin/cp /var/www/html/composer.phar /usr/bin/composer
        ExecStartPre=/bin/bash -c 'cd /var/www/html && sudo -u apache composer install --ignore-platform-reqs'
        ExecStartPre=/usr/bin/systemctl enable httpd
        ExecStartPre=/usr/bin/systemctl start httpd
        ExecStart=/var/aws-deployment/success.sh 0
        
        [Install]
        WantedBy=multi-user.target
        EOF

      imageBuilderInstanceTypes: t3.2xlarge t3.xlarge
      imageBuilderScriptValidate: ${{ needs.variables.outputs.imageBuilderScriptValidate }}
      deployUserDataScript: ${{ needs.variables.outputs.deployUserDataScript }}
      deployTrackUserDataScript: ${{ needs.variables.outputs.deployTrackUserDataScript }}
      minimumRunningInstances: 1
      desiredInstanceCapacity: 1
      maximumRunningInstances: 2
      instanceType: t3.micro
```

## Other Useful Commands

```bash
cat /etc/httpd/conf/httpd.conf
aws ssm start-session --target i-01d40968a6ceb1edf --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' --profile variables

ssh -o "UserKnownHostsFile=/dev/null" -o "IdentitiesOnly yes" -o "StrictHostKeyChecking=no" apache@localhost -p 9999 -N -L 7777:mydb-instance.cp0kek6goufi.us-east-1.rds.amazonaws.com:3306

aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,ImageId,Tags[*]]' --filters Name=instance-state-name,Values=running --output json | cat
php -r "passthru('aws ssm start-session --target ' . readline('instanceID: ') . ' --document-name AWS-StartPortForwardingSession --parameters \"{\\\"portNumber\\\":[\\\"22\\\"],\\\"localPortNumber\\\":[\\\"9999\\\"]}\"');"
```


