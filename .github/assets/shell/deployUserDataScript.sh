#!/bin/bash

set -eEBx

# Scripts directory
mkdir -p /var/aws-deployment

# Get AWS Metadata
SCRIPT_URL="https://raw.githubusercontent.com/MilesSystems/aws-deployment/${1}/.github/assets/php/createMetadataJson.php"
php <( curl -fsSL "$SCRIPT_URL" ) > /var/aws-deployment/aws.json

# Signal the lifecycle action setup
curl -o '/var/aws-deployment/signalLifecycleAction.sh' \
  https://raw.githubusercontent.com/MilesSystems/aws-deployment/${1}/.github/assets/shell/signalLifecycleAction.sh
chmod +x /var/aws-deployment/signalLifecycleAction.sh
cat /var/aws-deployment/signalLifecycleAction.sh
/var/aws-deployment/signalLifecycleAction.sh 0

err() {
  IFS=' ' read line file <<< "$(caller)"
  echo "Error ($2) on/near line $line in $file"
  /var/aws-deployment/signalLifecycleAction.sh "$2"
}
trap 'err $LINENO $?' ERR

# Composer Setup
export COMPOSER_HOME=/home/apache/.composer
EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]
then
  >&2 echo 'ERROR: Invalid installer checksum'
  rm composer-setup.php
  exit 1
fi

php composer-setup.php --quiet
rm composer-setup.php
mv composer.phar /usr/local/bin/composer

# Function to set up SSH keys for the apache user
setup_ssh_for_apache() {

  cd /home/apache/ || exit 1

  mkdir -p /home/apache/.ssh/

  cat > /home/apache/.ssh/id_github_pull_key <<EOF
${2}
EOF

  cat > /home/apache/.ssh/config <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile /home/apache/.ssh/id_github_pull_key
  IdentitiesOnly yes
EOF

  chmod g+rwX /home/apache/.ssh/ -R
  chmod 600 /home/apache/.ssh/id_github_pull_key
  chmod 600 /home/apache/.ssh/config

  eval $(ssh-agent)
  ssh-add /home/apache/.ssh/id_github_pull_key
  ssh-keyscan -H github.com >> /home/apache/.ssh/known_hosts
  # Test SSH connection to GitHub

  set +e
  SSH_OUTPUT=$(ssh -T git@github.com 2>&1)
  set -e

  # Check if the response contains "successfully authenticated"
  if echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
    echo "SSH authentication to GitHub successful!"
  else
    echo "SSH authentication to GitHub failed: $SSH_OUTPUT"
    exit 1
  fi
}

# Run the SSH setup function as the apache user; just keep both arguments passed as it makes reading the script easier
echo "Setting up SSH for apache user..."
chmod 777 /etc/httpd/conf.d/
sudo -u apache bash -c "$(declare -f setup_ssh_for_apache); setup_ssh_for_apache \"$1\" \"$2\""
chmod 755 /etc/httpd/conf.d/

# Download Apache Sites Setup Script
chown -R apache:apache /var/www/
curl -o /home/apache/setup_apache_sites.sh \
  https://raw.githubusercontent.com/MilesSystems/aws-deployment/${1}/.github/assets/shell/setup_apache_sites.sh
chmod +x /home/apache/setup_apache_sites.sh
cat /home/apache/setup_apache_sites.sh

# Download the failure service that would toggle the lifecycle hook downloaded earlier
curl -o /etc/systemd/system/aws_deployment_failure.service \
  https://raw.githubusercontent.com/MilesSystems/aws-deployment/${1}/.github/assets/system/aws_deployment_failure.service

# Download the boot scripts service that runs the Apache Sites Setup Script
curl -o /etc/systemd/system/aws_deployment_boot_scripts.service \
  https://raw.githubusercontent.com/MilesSystems/aws-deployment/${1}/.github/assets/system/aws_deployment_boot_scripts.service

# Run the Apache Sites Setup Script in a custom service
systemctl enable "aws_deployment_boot_scripts"
systemctl start "aws_deployment_boot_scripts"

