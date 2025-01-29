#!/bin/bash

# Fail on any error
set -e

# Fail on any error
set -e

usage() {
    echo "Usage: $0" >&2
    echo "Set the following required S3 environment variables before running:" >&2
    echo "  REMOTE_ENDPOINT            S3 endpoint URL including port" >&2
    echo "  REMOTE_BUCKET_NAME         S3 bucket name" >&2
    echo "  REMOTE_PATH                S3 path" >&2
    echo "  REMOTE_ACCESS_KEY_ID       S3 access key ID" >&2
    echo "  REMOTE_SECRET_ACCESS_KEY   S3 secret access key" >&2
    echo "  REMOTE_ADMIN_USER          S3 admin username" >&2
    echo "  REMOTE_ADMIN_PASSWORD      S3 admin password" >&2
    echo "  RUSTIC_ENCRYPTION_PASSWORD Rustic encryption password" >&2
    echo "  VFS_CACHE_MAX_SIZE         rclone VFS cache max size (e.g., 1Gi)" >&2
    echo >&2
    echo "Ensure that a rclone.conf.template file is mounted to the docker container at:" >&2
    echo "  ${HOME}/rclone.conf.template" >&2
    echo >&2
    echo "The following SFTP environment variables are optional and should only be set" >&2
    echo "if SFTP is the desired origin to be mounted:" >&2
    echo "  SFTP_HOST                  SFTP host" >&2
    echo "  SFTP_PORT                  SFTP port" >&2
    echo "  SFTP_USER                  SFTP username" >&2
    echo "  SFTP_HOST_PUBKEY           SFTP host public key (optional)" >&2
    echo "  SFTP_USER_PRIVKEY          SFTP user private key (optional)" >&2
    echo >&2
    echo "Note: If using SFTP, SFTP_HOST, SFTP_PORT, and SFTP_USER must all be set if any one of them is set." >&2
    echo "      SFTP_HOST_PUBKEY and SFTP_USER_PRIVKEY are optional regardless of other SFTP settings." >&2
}

# Check if any of the main SFTP variables are set
if [[ -n "$SFTP_HOST" || -n "$SFTP_PORT" || -n "$SFTP_USER" ]]; then
    # If any of these SFTP variables are set, all must be set
    if [[ -z "$SFTP_HOST" || -z "$SFTP_PORT" || -z "$SFTP_USER" ]]; then
        echo "Error: If any of SFTP_HOST, SFTP_PORT, or SFTP_USER is set, all three must be set." >&2
        echo "Current SFTP variable status:" >&2
        echo "SFTP_HOST: ${SFTP_HOST:-not set}" >&2
        echo "SFTP_PORT: ${SFTP_PORT:-not set}" >&2
        echo "SFTP_USER: ${SFTP_USER:-not set}" >&2
        echo >&2
        usage
        exit 1
    fi
fi

# Check for other required variables
required_vars=(
    "REMOTE_ENDPOINT"
    "REMOTE_BUCKET_NAME"
    "REMOTE_PATH"
    "REMOTE_ACCESS_KEY_ID"
    "REMOTE_SECRET_ACCESS_KEY"
    "REMOTE_ADMIN_USER"
    "REMOTE_ADMIN_PASSWORD"
    "RUSTIC_ENCRYPTION_PASSWORD"
    "VFS_CACHE_MAX_SIZE"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "Error: The following required environment variables are missing or empty:" >&2
    for var in "${missing_vars[@]}"; do
        echo "  - $var" >&2
    done
    echo >&2
    usage
    exit 1
fi

# Define the path to the rclone.conf file and template
RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
RCLONE_TEMPLATE="/tmp/rclone.conf.template"

# Create rclone config directory
mkdir -p "${HOME}/.config/rclone"

# Check if the template file exists
if [ -f "$RCLONE_TEMPLATE" ]; then
    # Use envsubst to replace environment variables and write to the final location
    envsubst < "$RCLONE_TEMPLATE" > "$RCLONE_CONF"

    # Check if the file exists and has content
    if [ ! -s "$RCLONE_CONF" ]; then
        echo "Error: rclone.conf file is empty or not created at $RCLONE_CONF" >&2
        exit 1
    fi

    echo "rclone.conf file created successfully at $RCLONE_CONF"
else
    echo "Error: rclone.conf.template not found at $RCLONE_TEMPLATE" >&2
    exit 1
fi

# Create the .config/rustic directory
mkdir -p "${HOME}/.config/rustic"

# Perform environment variable substitution in config.toml
envsubst < /tmp/rustic.template.toml > "${HOME}/.config/rustic/rustic.toml"

# Create the local mount point if it doesn't exist
MOUNT_PATH="${HOME}/rclone-mount"
mkdir -p "$MOUNT_PATH"

if [ -n "$SFTP_HOST" ]; then
    # SFTP configuration is needed
    mkdir -p "${HOME}/.ssh"
    chown appuser:appgroup "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    if [ -n "$SFTP_USER_PRIVKEY" ]; then
        PRIV_KEY_FILE="${HOME}/.ssh/rclone_key"
        mkdir -p $(dirname "$PRIV_KEY_FILE")
        echo "$SFTP_USER_PRIVKEY" > "$PRIV_KEY_FILE"
        chown appuser:appgroup "$PRIV_KEY_FILE"
        chmod 600 "$PRIV_KEY_FILE"
        echo "Created user priv key at ${PRIV_KEY_FILE}"
    fi

    if [ -n "$SFTP_HOST_PUBKEY" ]; then
    # Set up trusted host for SSH
        echo "$SFTP_HOST $SFTP_HOST_PUBKEY" > "${HOME}/.ssh/known_hosts"
        chmod 644 "${HOME}/.ssh/known_hosts"
        echo "Created known hosts with content:"
        cat "${HOME}/.ssh/known_hosts"
    fi

    echo "SFTP configuration completed."
else
    echo "No SFTP configuration needed."
fi

# Mount the remote directory using rclone
rclone mount \
    origin:$REMOTE_PATH \
    $MOUNT_PATH \
    --daemon \
    --read-only \
    --allow-other \
    --vfs-cache-mode full \
    --vfs-cache-max-size $VFS_CACHE_MAX_SIZE

echo "Remote directory mounted successfully at $MOUNT_PATH"

# Set up s3cmd configuration
cat > "${HOME}/.s3cfg" <<EOF
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