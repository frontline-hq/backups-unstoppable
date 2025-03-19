ARG ENV=production
# Add build args for UID and GID
ARG USER_ID
ARG GROUP_ID

FROM rclone/rclone:latest

# Need to redefine args after FROM
ARG USER_ID
ARG GROUP_ID

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
    openssl \
    diffoscope

# Ensure FUSE is configured for non-root environments
RUN echo "user_allow_other" >> /etc/fuse.conf

# Add the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create a group and user with host UID/GID
RUN addgroup -S -g "${GROUP_ID}" appgroup && \
    adduser -S -u "${USER_ID}" -G appgroup appuser

# Create required directories and set permissions
RUN mkdir -p /home/appuser/templates /home/appuser/tmp /persisted && \
    chown -R appuser:appgroup /home/appuser /persisted && \
    chmod 700 /home/appuser/templates

# Copy files with correct ownership
COPY --chown=appuser:appgroup genbackupdata.sh /home/appuser/tmp/genbackupdata.sh
COPY --chown=appuser:appgroup rustic.template.toml /home/appuser/tmp/rustic.template.toml
RUN chmod +x /home/appuser/tmp/genbackupdata.sh

# Tell docker that all future commands should run as the appuser user
USER appuser

# Entry point handles mounting the SFTP directory and environment variable substitution
ENTRYPOINT ["/entrypoint.sh"]

# Default command (can be overridden)
CMD ["/rustic", "--help"]
