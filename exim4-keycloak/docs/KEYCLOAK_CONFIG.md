# Keycloak Configuration Guide for Exim4 OAuth2

This guide walks you through setting up a Keycloak client for Exim4 OAuth2 authentication.

## Prerequisites

- Keycloak server running and accessible
- Admin access to Keycloak
- Exim4 installation ready

## Step 1: Access Keycloak Admin Console

1. Navigate to your Keycloak server: `https://keycloak.example.com`
2. Click **Administration Console**
3. Log in with admin credentials

## Step 2: Select or Create a Realm

### Option A: Use Existing Realm (Recommended for Production)

1. From the top-left dropdown, select your realm
2. If you don't have a custom realm, proceed to Option B

### Option B: Create New Realm (Production)

1. Hover over the realm name in the top-left
2. Click **Create Realm**
3. Enter realm name (e.g., `mail-server`)
4. Click **Create**

**Note**: For testing, you can use the `master` realm, but create a dedicated realm for production.

## Step 3: Create OAuth2 Client

### Basic Settings

1. From the left sidebar, click **Clients**
2. Click **Create client** button
3. Fill in the basic settings:
   - **Client type**: `OpenID Connect`
   - **Client ID**: `exim4-client` (or your preferred ID)
   - Click **Next**

### Capability Config

4. Configure client capabilities:
   - **Client authentication**: `ON` ✓
   - **Authorization**: `OFF`
   - **Authentication flow**:
     - Standard flow: `OFF`
     - Direct access grants: `OFF`
     - Implicit flow: `OFF`
     - Service accounts roles: `ON` ✓
     - OAuth 2.0 Device Authorization Grant: `OFF`
   - Click **Next**

### Login Settings

5. Configure login settings:
   - **Root URL**: Leave blank
   - **Home URL**: Leave blank
   - **Valid redirect URIs**: Leave blank (not needed for service accounts)
   - **Valid post logout redirect URIs**: Leave blank
   - **Web origins**: Leave blank
   - Click **Save**

## Step 4: Get Client Secret

1. After saving, click on the **Credentials** tab
2. You'll see the **Client Secret**
3. Click the copy icon to copy the secret
4. Save this secret securely - you'll need it for Exim4 configuration

**Important**: Keep this secret secure! It's like a password for your mail server.

## Step 5: Configure Service Account Roles (Optional)

If you need specific permissions for your mail service:

1. Click on the **Service account roles** tab
2. Click **Assign role**
3. Select appropriate roles based on your needs
4. Click **Assign**

**Note**: For basic email sending via external SMTP, default service account permissions are usually sufficient.

## Step 6: Configure Token Settings (Optional)

To adjust token lifetimes:

1. Click on the **Advanced** tab
2. Scroll to **Advanced Settings**
3. Adjust token lifetimes if needed:
   - **Access Token Lifespan**: Default is 5 minutes (300 seconds)
   - Recommendation: 15-60 minutes for mail server use
4. Click **Save**

## Step 7: Test Token Endpoint

Test that your client can get tokens:

```bash
# Replace with your values
KEYCLOAK_URL="https://keycloak.example.com"
REALM="master"
CLIENT_ID="exim4-client"
CLIENT_SECRET="your-client-secret"

# Request token
curl -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET"
```

You should receive a JSON response with `access_token`.

## Step 8: Configure Exim4

Update `/etc/exim4/keycloak.conf` with your values:

```bash
KEYCLOAK_URL="https://keycloak.example.com"
KEYCLOAK_REALM="master"  # or your custom realm
KEYCLOAK_CLIENT_ID="exim4-client"
KEYCLOAK_CLIENT_SECRET="your-client-secret-from-step-4"
SMTP_USERNAME="mailserver@example.com"
```

## Step 9: Test the Integration

Test token fetching with the script:

```bash
sudo -u Debian-exim /usr/local/bin/keycloak_token.sh test
```

Expected output:
```
========================================
Keycloak Token Fetcher - Test Mode
========================================

Configuration:
  Keycloak URL: https://keycloak.example.com
  Realm: master
  Client ID: exim4-client
  Client Secret: abcd****
  SMTP Username: mailserver@example.com
  Cache Directory: /var/spool/exim4/keycloak

✓ Configuration valid
✓ Cache directory ready
✓ Access token acquired
  Token (first 50 chars): eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6...
  Token length: 1234
✓ XOAUTH2 formatted
  Encoded length: 1648
  Encoded (first 80 chars): dXNlcj1tYWlsc2VydmVyQGV4YW1wbGUuY29tAWF1dGg9QmVhcmVyIGV5SmhiR2NpT2lKU...

✓ Token cached
  Expires at: 2026-08-08 21:25:30

========================================
Test completed successfully!
========================================
```

## Troubleshooting

### Problem: "Client not found" error

**Solution**: Verify the Client ID is correct and matches exactly (case-sensitive).

### Problem: "Invalid client credentials"

**Solution**: 
- Regenerate the client secret in Keycloak
- Ensure you copied the full secret without extra spaces
- Check that "Client authentication" is enabled

### Problem: "Service account not enabled"

**Solution**: 
- Edit your client in Keycloak
- Enable "Service accounts roles" in Capability Config
- Save and try again

### Problem: "SSL certificate verification failed"

**Solution**: 
- Use valid SSL certificates for Keycloak in production
- For testing only: Update the token script to skip verification (not recommended)

### Problem: Token expires too quickly

**Solution**:
- Increase "Access Token Lifespan" in client settings
- The token script caches tokens and refreshes automatically

## Security Best Practices

1. **Use HTTPS**: Always use HTTPS for Keycloak in production
2. **Dedicated Realm**: Create a dedicated realm for mail services
3. **Rotate Secrets**: Rotate client secrets regularly
4. **Minimal Permissions**: Assign only necessary roles
5. **Secure Storage**: Store secrets in vault systems (HashiCorp Vault, AWS Secrets Manager)
6. **Monitor Access**: Enable and monitor audit logs in Keycloak
7. **Network Security**: Restrict Keycloak access via firewall rules
8. **Token Lifetime**: Use appropriate token lifetimes (not too long)

## Advanced Configuration

### Using Client Credentials with User Impersonation

If you need user-specific tokens:

1. Create a dedicated service account user in Keycloak
2. Assign appropriate roles to this user
3. Use Resource Owner Password Credentials Grant instead
4. Update the token script to use username/password flow

### Integration with External Identity Providers

Keycloak can federate with:
- LDAP/Active Directory
- SAML providers
- Social login providers
- Custom identity providers

Configure identity providers in Keycloak and they'll work automatically with your mail server.

### High Availability Setup

For production:
1. Run multiple Keycloak instances
2. Use a load balancer in front of Keycloak
3. Configure database replication for PostgreSQL
4. Use shared cache (Infinispan) across Keycloak instances

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OAuth 2.0 Client Credentials Grant](https://oauth.net/2/grant-types/client-credentials/)
- [RFC 7628 - SASL OAuth](https://datatracker.ietf.org/doc/html/rfc7628)
- [Keycloak Admin REST API](https://www.keycloak.org/docs-api/latest/rest-api/index.html)

## Next Steps

After configuring Keycloak:
1. Configure your external SMTP server to accept OAuth2 authentication
2. Test sending emails through Exim4
3. Monitor logs for any authentication issues
4. Set up monitoring and alerting for token failures
5. Document your configuration for your team

## Support

For Keycloak-specific issues:
- [Keycloak Discourse](https://keycloak.discourse.group/)
- [Keycloak GitHub](https://github.com/keycloak/keycloak)

For Exim4 configuration:
- See the main README.md in this project
