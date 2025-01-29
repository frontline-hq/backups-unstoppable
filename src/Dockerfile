FROM rclone/rclone:latest

COPY --from=ghcr.io/rustic-rs/rustic:latest / /

WORKDIR /tmp

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

# Add the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create a group and user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Tell docker that all future commands should run as the appuser user
USER appuser

# Copy config.toml template to a temporary location
COPY rustic.template.toml /tmp/rustic.template.toml

# Entry point handles mounting the SFTP directory and environment variable substitution
ENTRYPOINT ["/entrypoint.sh"]

# Default command (can be overridden)
CMD ["/rustic", "--help"]