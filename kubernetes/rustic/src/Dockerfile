# Start from the rustic image
FROM ghcr.io/rustic-rs/rustic:latest as rustic

FROM alpine

COPY --from=rustic / /

# Install necessary packages
RUN apk add --no-cache \
    openssh-client \
    sshfs \
    fuse \
    bash \
    ca-certificates \
    gettext

# Ensure FUSE is configured for non-root environments
RUN echo "user_allow_other" >> /etc/fuse.conf

# Copy config.toml to a temporary location
COPY rustic.template.toml /tmp/rustic.template.toml

# Create a directory for the SFTP mount point
RUN mkdir -p /mnt/sftp

# Set the working directory
WORKDIR /mnt/sftp

# Add an entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Entry point handles mounting the SFTP directory and environment variable substitution
ENTRYPOINT ["/entrypoint.sh"]

# Default command (can be overridden)
CMD ["backup"]
