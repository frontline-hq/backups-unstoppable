#!/bin/bash

# Fail on any error
set -e

# Check runtime arguments or environment variables
SFTP_USER=${SFTP_USER:-$1}
SFTP_HOST=${SFTP_HOST:-$2}
SFTP_MOUNT_PATH_IN_DOCKER=${SFTP_MOUNT_PATH_IN_DOCKER:-$3}
REMOTE_BUCKET_NAME=${REMOTE_BUCKET_NAME:-$4}
REMOTE_PATH=${REMOTE_PATH:-$5}
REMOTE_KEY_ID=${REMOTE_KEY_ID:-$6}
REMOTE_ACCESS_KEY=${REMOTE_ACCESS_KEY:-$7}

# Ensure all necessary information is provided
if [[ -z "$SFTP_USER" || -z "$SFTP_HOST" || -z "$REMOTE_PATH" || -z "$SFTP_MOUNT_PATH_IN_DOCKER" || -z "$REMOTE_BUCKET_NAME" || -z "$REMOTE_KEY_ID" || -z "$REMOTE_ACCESS_KEY" ]]; then
  echo "Usage: $0 <SFTP_USER> <SFTP_HOST> <SFTP_MOUNT_PATH_IN_DOCKER> <REMOTE_BUCKET_NAME> <REMOTE_PATH> <REMOTE_KEY_ID>  <REMOTE_ACCESS_KEY>" >&2
  echo "Or set the corresponding environment variables: SFTP_USER, SFTP_HOST, REMOTE_PATH, SFTP_MOUNT_PATH_IN_DOCKER" >&2
  exit 1
fi

# Create the .config/rustic directory
mkdir -p $HOME/.config/rustic

# Perform environment variable substitution in config.toml
envsubst < /tmp/rustic.template.toml > $HOME/.config/rustic/rustic.toml

# Create the local mount point if it doesn't exist
mkdir -p "$SFTP_MOUNT_PATH_IN_DOCKER"

# Mount the SFTP directory using sshfs
echo "Mounting SFTP directory..."
sshfs "${SFTP_USER}@${SFTP_HOST}:${REMOTE_PATH}" "$SFTP_MOUNT_PATH_IN_DOCKER" \
    -o IdentityFile=/root/.ssh/id_rsa \
    -o allow_other \
    -o reconnect \
    -o ServerAliveInterval=15

echo "SFTP directory mounted successfully at $SFTP_MOUNT_PATH_IN_DOCKER"

# Init rustic repo
# Should only do this once, even if called multiple times: https://github.com/rustic-rs/rustic/issues/1141
rustic init

# Run rustic
exec rustic "$@"