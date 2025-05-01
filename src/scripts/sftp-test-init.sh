#!/bin/bash

# This script is meant to be run on test runs to init the atmoz sftp container
# to fill it with sample contents that can be backed up

# Check if openssl is installed, if not, install it
if ! command -v openssl &> /dev/null; then
    echo "OpenSSL not found. Installing..."
    apt-get update
    apt-get install -y openssl
    echo "OpenSSL installed."
fi

# Search through all direct child directories of /home
for user_home in /home/*/; do
    # Remove trailing slash from path
    user_home=${user_home%/}
    # Get username from path
    username=$(basename "$user_home")

    # Check if genbackupdata.sh exists in this user's home directory
    if [ -f "$user_home/genbackupdata.sh" ]; then
        echo "Found genbackupdata.sh in $user_home, generating backup data..."

        # Change to the user's directory
        cd "$user_home"

        # Execute the script with the parameters
        ./genbackupdata.sh -c 4096 -f 256 -q "$user_home/backupdata"

        echo "Backup data generated for user $username"
    fi
done

echo "Initialization complete"
