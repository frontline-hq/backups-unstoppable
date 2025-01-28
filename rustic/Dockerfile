FROM rclone/rclone:latest

COPY --from=ghcr.io/rustic-rs/rustic:latest / /

# Ensure rustic is in PATH
ENV PATH="/:${PATH}"

# Install necessary packages
RUN apk add --no-cache \
    openssh-client \
    sshfs \
    fuse \
    bash \
    ca-certificates \
    gettext \
    s3cmd

# Ensure FUSE is configured for non-root environments
RUN echo "user_allow_other" >> /etc/fuse.conf

# Copy config.toml template to a temporary location
COPY rustic.template.toml /tmp/rustic.template.toml

# Set the working directory
WORKDIR /mnt

# Add the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Ensure .ssh directory exists with correct permissions
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Document expected environment variables
ENV SFTP_HOST=
ENV SFTP_PORT=
ENV SFTP_USER=
ENV SFTP_HOST_PUBKEY=
ENV SFTP_USER_PRIVKEY=
ENV SFTP_MOUNT_PATH_IN_DOCKER=
ENV REMOTE_ENDPOINT=
ENV REMOTE_BUCKET_NAME=
ENV REMOTE_PATH=
ENV REMOTE_ACCESS_KEY_ID=
ENV REMOTE_SECRET_ACCESS_KEY=
ENV REMOTE_ADMIN_USER=
ENV REMOTE_ADMIN_PASSWORD=
ENV RUSTIC_ENCRYPTION_PASSWORD=

# Entry point handles mounting the SFTP directory and environment variable substitution
ENTRYPOINT ["/entrypoint.sh"]

# Default command (can be overridden)
CMD ["/rustic", "--help"]