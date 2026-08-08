# Exim4 with Keycloak OAuth2 Authentication

This directory contains a complete Exim4 mail server configuration that integrates with Keycloak for OAuth2/OIDC authentication using the XOAUTH2 mechanism.

## Overview

Exim4 doesn't natively support OAuth2/OIDC, so this implementation uses:
- **XOAUTH2 SASL mechanism** for SMTP authentication
- **External token script** that fetches access tokens from Keycloak
- **Client Credentials Grant** flow for server-to-server authentication

## Architecture

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Exim4     │─────>│ Token Script │─────>│  Keycloak   │
│ SMTP Server │      │ (OAuth2)     │      │   Server    │
└─────────────┘      └──────────────┘      └─────────────┘
       │                     │
       │                     ├─ Fetch Access Token
       │                     ├─ Cache Token
       │                     └─ Return to Exim4
       │
       └─ Authenticate with XOAUTH2
```

## Directory Structure

```
exim4-keycloak/
├── README.md                          # This file
├── scripts/
│   ├── keycloak_token.sh             # Token fetching script
│   └── install.sh                     # Installation script
├── config/
│   ├── exim4.conf                    # Main Exim4 configuration
│   ├── authenticators/
│   │   └── 30_keycloak_oauth2        # OAuth2 authenticator config
│   ├── routers/
│   │   └── 200_keycloak_relay        # Router for OAuth2 relay
│   └── transports/
│       └── 30_keycloak_smtp          # SMTP transport config
├── docker/
│   ├── Dockerfile                     # Exim4 container image
│   └── docker-compose.yml            # Complete stack with Keycloak
└── docs/
    ├── SETUP.md                       # Setup instructions
    └── KEYCLOAK_CONFIG.md            # Keycloak configuration guide
```

## Quick Start

### Option 1: Docker Compose (Recommended)

```bash
cd exim4-keycloak
docker-compose up -d
```

This starts:
- Keycloak server (port 8080)
- PostgreSQL database for Keycloak
- Exim4 mail server (ports 25, 587)

### Option 2: Manual Installation

```bash
# 1. Install dependencies
sudo apt-get update
sudo apt-get install exim4-daemon-heavy curl jq

# 2. Configure Keycloak credentials
cp scripts/keycloak_token.sh.example scripts/keycloak_token.sh
nano scripts/keycloak_token.sh
# Edit KEYCLOAK_URL, CLIENT_ID, CLIENT_SECRET

# 3. Run installation script
sudo ./scripts/install.sh

# 4. Test configuration
sudo exim4 -bV
sudo /usr/local/bin/keycloak_token.sh test
```

## Configuration

### Environment Variables

Create a `.env` file with your Keycloak settings:

```bash
# Keycloak Server
KEYCLOAK_URL=https://keycloak.example.com
KEYCLOAK_REALM=master
KEYCLOAK_CLIENT_ID=exim4-client
KEYCLOAK_CLIENT_SECRET=your-client-secret

# Email Configuration
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=mailserver@example.com
SMTP_FROM=noreply@example.com
```

### Keycloak Client Setup

1. Log in to Keycloak Admin Console
2. Navigate to your realm (or create one)
3. Create a new client:
   - **Client ID**: `exim4-client`
   - **Client Protocol**: `openid-connect`
   - **Access Type**: `confidential`
   - **Standard Flow**: Disabled
   - **Direct Access Grants**: Disabled
   - **Service Accounts**: Enabled
4. Copy the client secret from the Credentials tab
5. Assign appropriate service account roles if needed

See [docs/KEYCLOAK_CONFIG.md](docs/KEYCLOAK_CONFIG.md) for detailed instructions.

## How It Works

### Authentication Flow

1. **Exim4 needs to send email** via external SMTP server
2. **Exim4 calls token script** (`/usr/local/bin/keycloak_token.sh`)
3. **Script checks token cache** in `/var/spool/exim4/keycloak/`
4. **If expired, fetches new token** from Keycloak using Client Credentials Grant
5. **Returns XOAUTH2 formatted string** to Exim4
6. **Exim4 authenticates** to remote SMTP server with token

### Token Caching

- Tokens are cached in `/var/spool/exim4/keycloak/access_token.json`
- Script checks expiry before requesting new token
- Reduces API calls to Keycloak
- Cache files readable only by `Debian-exim` user

### Security Features

- Client secret stored in protected file (`600` permissions)
- Token cache secured with proper ownership
- TLS required for all SMTP connections
- Secrets can be integrated with external vaults

## Testing

### Test Token Retrieval

```bash
# Test script manually
sudo -u Debian-exim /usr/local/bin/keycloak_token.sh

# Should output base64-encoded XOAUTH2 string
```

### Test SMTP Authentication

```bash
# Send test email
echo "Test message" | mail -s "Test" user@example.com

# Check Exim logs
sudo tail -f /var/log/exim4/mainlog
```

### Debug Mode

Enable debug logging in Exim4:

```bash
# Add to exim4.conf
log_selector = +all

# Or test with debug flag
sudo exim4 -d -bt user@example.com
```

## Troubleshooting

### Token Fetch Fails

```bash
# Check Keycloak connectivity
curl -v https://keycloak.example.com/realms/master/.well-known/openid-configuration

# Verify client credentials
curl -X POST "https://keycloak.example.com/realms/master/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=exim4-client" \
  -d "client_secret=your-secret"
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R Debian-exim:Debian-exim /var/spool/exim4/keycloak/
sudo chmod 700 /var/spool/exim4/keycloak/
sudo chmod 600 /var/spool/exim4/keycloak/*
```

### Exim4 Configuration Errors

```bash
# Test configuration syntax
sudo exim4 -bV
sudo exim4 -C /etc/exim4/exim4.conf -bV

# Test routing
sudo exim4 -bt user@example.com
```

## Limitations

1. **Client-side only**: This configures Exim4 as an OAuth2 **client** to authenticate to external SMTP servers
2. **Server-side auth not supported**: Incoming connections cannot authenticate via Keycloak OIDC natively
3. **Token size limits**: Very large JWT tokens may exceed Exim4 buffer size (4096 bytes in older versions)
4. **No refresh token support**: Uses Client Credentials Grant which provides access tokens only

## Production Recommendations

1. **Use external secret management** (HashiCorp Vault, AWS Secrets Manager)
2. **Monitor token expiry** and adjust refresh timing
3. **Set up log rotation** for Exim4 and script logs
4. **Use TLS everywhere** for SMTP and Keycloak connections
5. **Implement monitoring** for failed authentications
6. **Regular security audits** of permissions and credentials
7. **Keep Exim4 updated** to latest version for security patches

## Alternative Solutions

If you need full OIDC/OAuth2 support for incoming mail authentication, consider:

- **Apache James** - Native OIDC support with Keycloak
- **Dovecot + Postfix** - Better OAuth2 integration options
- **Docker Mailserver** - OAuth2 support via Dovecot
- **API Gateway** - Proxy authentication for IMAP/SMTP

## References

- [Exim4 Documentation](https://exim.org/docs.html)
- [RFC 7628 - SASL OAuth](https://datatracker.ietf.org/doc/html/rfc7628)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [oauth2ForExim Project](https://gitlab.com/clearfocus/oauth2_exim)

## License

This configuration is provided as-is for educational and production use.

## Support

For issues specific to this configuration, check the logs and troubleshooting section above. For Exim4 issues, consult the official documentation. For Keycloak issues, refer to Keycloak documentation.
