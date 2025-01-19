#!/bin/bash

# Enable debugging and error handling
set -eEBx

# List of repositories from GitHub
repositories=(
  "git@github.com:nicoledodge/NikkiDodgePhotography.com.git"
  "git@github.com:MilesSystems/chylle.miles.systems.git"
  "git@github.com:MilesSystems/bnb-studios.com.git"
  "git@github.com:MilesSystems/renovate.company.git"
  "git@github.com:MilesSystems/eatery.restaurant.git"
  "git@github.com:RichardTMiles/Stats.Coach.git"
)

# Define the Apache config template
config_template=$(cat <<'TEMPLATE'
<VirtualHost *:80>
  ServerAdmin webmaster@$domain
  ServerName $domain
  ServerAlias www.$domain  # Handle both domain and www prefix
  DocumentRoot $target_dir
  ErrorLog /var/log/httpd/$domain-error_log
  CustomLog /var/log/httpd/$domain-access_log combined

  <Directory $target_dir>
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>
TEMPLATE
)

# Loop through each repository and extract the domain name dynamically
for repo in "${repositories[@]}"; do

  # Extract the domain name from the repository URL
  domain=$(echo "$repo" | sed -E 's/.*github\.com[:\/]([^\/]+\/)?([^\/]+)\.git/\2/' | tr '[:upper:]' '[:lower:]')

  # Define the target directory for the clone
  target_dir="/var/www/$domain"

  # Clone the repository into the appropriate folder if it doesn't already exist or is empty
  if [ -d "$target_dir" ] && [ "$(ls -A "$target_dir")" ]; then
    echo "Skipping $domain: Target directory '$target_dir' exists and is not empty."
  else
    echo "Cloning $domain from $repo..."
    git clone "$repo" "$target_dir"
  fi

  # Define the Apache config file location (in /etc/httpd/conf.d/)
  config_file="/etc/httpd/conf.d/$domain.conf"

  # Export variables so envsubst can substitute them in the config_template
  export domain
  export target_dir

  # Create the Apache config file for the domain
  echo "Creating Apache config for $domain in /etc/httpd/conf.d/... ($config_file)"
  echo "$config_template" | envsubst > "$config_file"

  # Check if the specified directory exists
  if [ ! -d "$target_dir" ]; then
    echo "Error: Directory '$target_dir' does not exist."
    exit 1
  fi

  echo "Post-clone setup started for directory: $target_dir"
  cd "$target_dir" || exit 1

  set +e

  # For a Node.js project:
  if [ -f "package.json" ]; then
    echo "Installing npm dependencies..."
    npm install
  fi

  # For a Python project:
  if [ -f "requirements.txt" ]; then
    echo "Installing Python dependencies..."
    pip install -r requirements.txt
  fi

  # For a Composer-based PHP project:
  if [ -f "composer.json" ]; then
    echo "Installing PHP dependencies..."
    composer install
  fi

  set -e

  echo "Post-clone setup completed for directory: $target_dir"

done

echo "All sites are configured."
