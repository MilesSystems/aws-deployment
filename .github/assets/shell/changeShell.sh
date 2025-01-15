#!/bin/bash

# Ensure that both user and shell parameters are provided
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <username> <shell>"
  exit 1
fi

# Assign parameters to variables
user=$1
new_shell=$2

# Check if the user exists
if ! id "$user" &>/dev/null; then
  echo "User '$user' does not exist."
  exit 1
fi

# Check if the shell is valid (executable)
if [[ ! -x "$new_shell" ]]; then
  echo "The shell '$new_shell' is not valid or not executable."
  exit 1
fi

# Backup /etc/passwd before making any changes
sudo cp /etc/passwd /etc/passwd.bak

# Use sed to change the shell for the user to the new shell
sudo sed -i "s|^\($user:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\)[^:]*|\1$new_shell|" /etc/passwd

# Confirm the change
echo "The default shell for '$user' has been changed to:"
grep "^$user" /etc/passwd
