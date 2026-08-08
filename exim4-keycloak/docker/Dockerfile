FROM debian:bookworm-slim

LABEL maintainer="Exim4 Keycloak Integration"
LABEL description="Exim4 mail server with Keycloak OAuth2 authentication support"

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    exim4-daemon-heavy \
    exim4-base \
    curl \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /var/spool/exim4/keycloak \
    && mkdir -p /var/log/exim4 \
    && chown -R Debian-exim:Debian-exim /var/spool/exim4/keycloak \
    && chown -R Debian-exim:Debian-exim /var/log/exim4 \
    && chmod 700 /var/spool/exim4/keycloak

# Copy token script
COPY scripts/keycloak_token.sh /usr/local/bin/keycloak_token.sh
RUN chmod 755 /usr/local/bin/keycloak_token.sh

# Copy Keycloak configuration
COPY config/keycloak.conf /etc/exim4/keycloak.conf
RUN chown Debian-exim:Debian-exim /etc/exim4/keycloak.conf \
    && chmod 600 /etc/exim4/keycloak.conf

# Copy Exim4 configuration
COPY config/exim4.conf /etc/exim4/exim4.conf
RUN chown root:root /etc/exim4/exim4.conf \
    && chmod 644 /etc/exim4/exim4.conf

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SMTP ports
EXPOSE 25 587 465

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD exim4 -bpc > /dev/null || exit 1

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command
CMD ["exim4", "-bdf", "-q30m"]
