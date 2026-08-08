#!/bin/bash
#
# Exim4 Docker Entrypoint Script
#
# This script configures Exim4 from environment variables and starts the service

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Exim4 with Keycloak OAuth2${NC}"
echo -e "${GREEN}========================================${NC}"

# Configure Keycloak settings from environment variables
if [[ -n "$KEYCLOAK_URL" ]]; then
    echo -e "${GREEN}[INFO]${NC} Configuring Keycloak URL: $KEYCLOAK_URL"
    sed -i "s|^KEYCLOAK_URL=.*|KEYCLOAK_URL=\"$KEYCLOAK_URL\"|" /etc/exim4/keycloak.conf
fi

if [[ -n "$KEYCLOAK_REALM" ]]; then
    echo -e "${GREEN}[INFO]${NC} Configuring Keycloak Realm: $KEYCLOAK_REALM"
    sed -i "s|^KEYCLOAK_REALM=.*|KEYCLOAK_REALM=\"$KEYCLOAK_REALM\"|" /etc/exim4/keycloak.conf
fi

if [[ -n "$KEYCLOAK_CLIENT_ID" ]]; then
    echo -e "${GREEN}[INFO]${NC} Configuring Client ID: $KEYCLOAK_CLIENT_ID"
    sed -i "s|^KEYCLOAK_CLIENT_ID=.*|KEYCLOAK_CLIENT_ID=\"$KEYCLOAK_CLIENT_ID\"|" /etc/exim4/keycloak.conf
fi

if [[ -n "$KEYCLOAK_CLIENT_SECRET" ]]; then
    echo -e "${GREEN}[INFO]${NC} Configuring Client Secret: ****"
    sed -i "s|^KEYCLOAK_CLIENT_SECRET=.*|KEYCLOAK_CLIENT_SECRET=\"$KEYCLOAK_CLIENT_SECRET\"|" /etc/exim4/keycloak.conf
fi

if [[ -n "$SMTP_USERNAME" ]]; then
    echo -e "${GREEN}[INFO]${NC} Configuring SMTP Username: $SMTP_USERNAME"
    sed -i "s|^SMTP_USERNAME=.*|SMTP_USERNAME=\"$SMTP_USERNAME\"|" /etc/exim4/keycloak.conf
fi

if [[ -n "$KEYCLOAK_DEBUG" ]]; then
    echo -e "${GREEN}[INFO]${NC} Setting debug mode: $KEYCLOAK_DEBUG"
    sed -i "s|^KEYCLOAK_DEBUG=.*|KEYCLOAK_DEBUG=\"$KEYCLOAK_DEBUG\"|" /etc/exim4/keycloak.conf
fi

# Configure Exim4 settings
if [[ -n "$PRIMARY_HOSTNAME" ]]; then
    echo -e "${GREEN}[INFO]${NC} Configuring primary hostname: $PRIMARY_HOSTNAME"
    sed -i "s|^primary_hostname = .*|primary_hostname = $PRIMARY_HOSTNAME|" /etc/exim4/exim4.conf
fi

if [[ -n "$LOCAL_DOMAINS" ]]; then
    echo -e "${GREEN}[INFO]${NC} Configuring local domains: $LOCAL_DOMAINS"
    sed -i "s|^domainlist local_domains = .*|domainlist local_domains = @ : localhost : $LOCAL_DOMAINS|" /etc/exim4/exim4.conf
fi

if [[ -n "$SMTP_HOST" ]]; then
    echo -e "${GREEN}[INFO]${NC} Configuring SMTP smarthost: $SMTP_HOST:${SMTP_PORT:-587}"
    sed -i "s|route_list = \* .*|route_list = * ${SMTP_HOST}::${SMTP_PORT:-587} byname|" /etc/exim4/exim4.conf
fi

# Ensure proper permissions
chown -R Debian-exim:Debian-exim /var/spool/exim4/keycloak
chown -R Debian-exim:Debian-exim /var/log/exim4
chmod 700 /var/spool/exim4/keycloak
chmod 600 /etc/exim4/keycloak.conf

# Test configuration
echo -e "${GREEN}[INFO]${NC} Testing Exim4 configuration..."
if exim4 -bV > /dev/null 2>&1; then
    echo -e "${GREEN}[SUCCESS]${NC} Exim4 configuration valid"
else
    echo -e "${YELLOW}[WARN]${NC} Exim4 configuration may have issues"
fi

# Test Keycloak token script (if not using default placeholder values)
if [[ "$KEYCLOAK_CLIENT_SECRET" != "your-client-secret" ]] && [[ "$KEYCLOAK_CLIENT_SECRET" != "your-client-secret-here" ]]; then
    echo -e "${GREEN}[INFO]${NC} Testing Keycloak token retrieval..."
    if timeout 10 sudo -u Debian-exim /usr/local/bin/keycloak_token.sh > /dev/null 2>&1; then
        echo -e "${GREEN}[SUCCESS]${NC} Keycloak authentication working"
    else
        echo -e "${YELLOW}[WARN]${NC} Could not retrieve Keycloak token (may not be configured yet)"
    fi
else
    echo -e "${YELLOW}[WARN]${NC} Keycloak client secret not configured, skipping token test"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Starting Exim4...${NC}"
echo -e "${GREEN}========================================${NC}"

# Execute the command passed to the container
exec "$@"
