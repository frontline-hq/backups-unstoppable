#!/bin/bash

# Fail on any error
set -e

# Function to print usage
usage() {
    echo "Usage: $0 [options] [command to execute...]" >&2
    echo "Options:" >&2
    echo "  --sftp-host HOST                  SFTP host" >&2
    echo "  --sftp-port PORT                  SFTP port (default: 22)" >&2
    echo "  --sftp-user USER                  SFTP username" >&2
    echo "  --sftp-host-pubkey KEY            SFTP host public key" >&2
    echo "  --sftp-user-privkey KEY           SFTP user private key" >&2
    echo "  --sftp-mount-path PATH            SFTP mount path in Docker" >&2
    echo "  --remote-endpoint URL             S3 endpoint URL including port" >&2
    echo "  --remote-bucket-name NAME         S3 bucket name" >&2
    echo "  --remote-path PATH                S3 path" >&2
    echo "  --remote-key-id ID                S3 access key ID" >&2
    echo "  --remote-access-key KEY           S3 secret access key" >&2
    echo "  --remote-admin-user NAME          S3 admin username" >&2
    echo "  --remote-admin-password PASSWORD  S3 admin password" >&2
    echo "  --rustic-encryption-password PWD  Rustic encryption password" >&2
    echo "Or set the corresponding environment variables" >&2
    exit 1
}

# Parse named arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sftp-host) SFTP_HOST="$2"; shift 2 ;;
        --sftp-port) SFTP_PORT="$2"; shift 2 ;;
        --sftp-user) SFTP_USER="$2"; shift 2 ;;
        --sftp-host-pubkey) SFTP_HOST_PUBKEY="$2"; shift 2 ;;
        --sftp-user-privkey) SFTP_USER_PRIVKEY="$2"; shift 2 ;;
        --sftp-mount-path) SFTP_MOUNT_PATH_IN_DOCKER="$2"; shift 2 ;;
        --remote-endpoint) REMOTE_ENDPOINT="$2"; shift 2 ;;
        --remote-bucket-name) REMOTE_BUCKET_NAME="$2"; shift 2 ;;
        --remote-path) REMOTE_PATH="$2"; shift 2 ;;
        --remote-key-id) REMOTE_ACCESS_KEY_ID="$2"; shift 2 ;;
        --remote-access-key) REMOTE_SECRET_ACCESS_KEY="$2"; shift 2 ;;
        --remote-admin-user) REMOTE_ADMIN_USER="$2"; shift 2 ;;
        --remote-admin-password) REMOTE_ADMIN_PASSWORD="$2"; shift 2 ;;
        --rustic-encryption-password) RUSTIC_ENCRYPTION_PASSWORD="$2"; shift 2 ;;
        --) shift; break ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) break ;;
    esac
done

# Use environment variables as fallback
SFTP_HOST=${SFTP_HOST:-$SFTP_HOST}
SFTP_PORT=${SFTP_PORT:-${SFTP_PORT:-22}}  # Default to 22 if not set
SFTP_USER=${SFTP_USER:-$SFTP_USER}
SFTP_HOST_PUBKEY=${SFTP_HOST_PUBKEY:-$SFTP_HOST_PUBKEY}
SFTP_USER_PRIVKEY=${SFTP_USER_PRIVKEY:-$SFTP_USER_PRIVKEY}
SFTP_MOUNT_PATH_IN_DOCKER=${SFTP_MOUNT_PATH_IN_DOCKER:-$SFTP_MOUNT_PATH_IN_DOCKER}
REMOTE_ENDPOINT=${REMOTE_ENDPOINT:-$REMOTE_ENDPOINT}
REMOTE_BUCKET_NAME=${REMOTE_BUCKET_NAME:-$REMOTE_BUCKET_NAME}
REMOTE_PATH=${REMOTE_PATH:-$REMOTE_PATH}
REMOTE_ACCESS_KEY_ID=${REMOTE_ACCESS_KEY_ID:-$REMOTE_ACCESS_KEY_ID}
REMOTE_SECRET_ACCESS_KEY=${REMOTE_SECRET_ACCESS_KEY:-$REMOTE_SECRET_ACCESS_KEY}
REMOTE_ADMIN_USER=${REMOTE_ADMIN_USER:-$REMOTE_ADMIN_USER}
REMOTE_ADMIN_PASSWORD=${REMOTE_ADMIN_PASSWORD:-$REMOTE_ADMIN_PASSWORD}
RUSTIC_ENCRYPTION_PASSWORD=${RUSTIC_ENCRYPTION_PASSWORD:-$RUSTIC_ENCRYPTION_PASSWORD}

# Ensure all necessary information is provided
if [[ -z "$SFTP_HOST" || -z "$SFTP_USER" || -z "$SFTP_HOST_PUBKEY" || -z "$SFTP_USER_PRIVKEY" || 
      -z "$SFTP_MOUNT_PATH_IN_DOCKER" || -z "$REMOTE_ENDPOINT" || -z "$REMOTE_BUCKET_NAME" || 
      -z "$REMOTE_PATH" || -z "$REMOTE_ACCESS_KEY_ID" || -z "$REMOTE_SECRET_ACCESS_KEY" || 
      -z "$REMOTE_ADMIN_USER" || -z "$REMOTE_ADMIN_PASSWORD" || -z "$RUSTIC_ENCRYPTION_PASSWORD" ]]; then
    echo "Error: Missing required options" >&2
    usage
fi

# Create the .config/rustic directory
mkdir -p $HOME/.config/rustic

# Perform environment variable substitution in config.toml
envsubst < /tmp/rustic.template.toml > $HOME/.config/rustic/rustic.toml

# Create the local mount point if it doesn't exist
mkdir -p "$SFTP_MOUNT_PATH_IN_DOCKER"

# Create rclone config directory
mkdir -p $HOME/.config/rclone

# Write user private key
PRIV_KEY_FILE="$HOME/.ssh/sftp_user_key"
mkdir -p $(dirname "$PRIV_KEY_FILE")
echo "$SFTP_USER_PRIVKEY" > "$PRIV_KEY_FILE"
chmod 600 "$PRIV_KEY_FILE"

# Set up trusted host for SSH
mkdir -p $HOME/.ssh
echo "$SFTP_HOST $SFTP_HOST_PUBKEY" >> $HOME/.ssh/known_hosts
chmod 644 $HOME/.ssh/known_hosts

# Create rclone config
cat > $HOME/.config/rclone/rclone.conf <<EOF
[sftp]
type = sftp
host = $SFTP_HOST
user = $SFTP_USER
port = $SFTP_PORT
key_file = $PRIV_KEY_FILE
EOF

# Mount the remote directory using rclone
echo "Mounting remote directory..."
rclone mount \
    sftp:$SFTP_MOUNT_PATH_IN_DOCKER \
    $SFTP_MOUNT_PATH_IN_DOCKER \
    --daemon \
    --read-only \
    --allow-other \
    --vfs-cache-mode full \
    --vfs-cache-max-size 1Gi

echo "Remote directory mounted successfully at $SFTP_MOUNT_PATH_IN_DOCKER"

# Set up s3cmd configuration
cat > $HOME/.s3cfg <<EOF
[default]
access_key = $REMOTE_ADMIN_USER
secret_key = $REMOTE_ADMIN_PASSWORD
host_base = $REMOTE_ENDPOINT
host_bucket = $REMOTE_ENDPOINT
use_https = False
signature_v2 = False
EOF

# Create bucket if it doesn't exist
if ! s3cmd ls s3://$REMOTE_BUCKET_NAME > /dev/null 2>&1; then
    s3cmd mb s3://$REMOTE_BUCKET_NAME
    echo "Created S3 bucket: $REMOTE_BUCKET_NAME"
else
    echo "S3 bucket already exists: $REMOTE_BUCKET_NAME"
fi

# Set bucket policy for restricted access to REMOTE_PATH
cat > /tmp/policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"AWS": ["*"]},
            "Action": [
                "*"
            ],
            "Resource": [
                "arn:aws:s3:::${REMOTE_BUCKET_NAME}${REMOTE_PATH}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Principal": {"AWS": ["*"]},
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::$REMOTE_BUCKET_NAME",
            "Condition": {
                "StringLike": {
                    "s3:prefix": [
                        "${REMOTE_PATH}",
                        "${REMOTE_PATH}/*"
                    ]
                }
            }
        }
    ]
}
EOF

s3cmd setpolicy /tmp/policy.json s3://$REMOTE_BUCKET_NAME
echo "Set restricted access policy for S3 bucket: $REMOTE_BUCKET_NAME, path: $REMOTE_PATH"

# Execute the command passed as arguments
if [ $# -eq 0 ]; then
    echo "No command provided. Please provide a command to execute."
    exit 1
else
    exec "$@"
fi