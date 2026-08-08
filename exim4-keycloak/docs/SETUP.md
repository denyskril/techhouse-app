# Setup Guide - Exim4 with Keycloak OAuth2

This guide provides step-by-step instructions for setting up Exim4 with Keycloak OAuth2 authentication.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Methods](#installation-methods)
3. [Configuration](#configuration)
4. [Testing](#testing)
5. [Troubleshooting](#troubleshooting)
6. [Production Deployment](#production-deployment)

## Prerequisites

### System Requirements

- Linux server (Debian, Ubuntu, CentOS, or RHEL)
- Root or sudo access
- Internet connectivity
- At least 2GB RAM
- 10GB free disk space

### Software Requirements

- Exim4 (will be installed if not present)
- curl
- jq (JSON processor)
- base64 (usually included in coreutils)

### Keycloak Requirements

- Running Keycloak instance (version 20+)
- Admin access to Keycloak
- OAuth2 client configured (see [KEYCLOAK_CONFIG.md](KEYCLOAK_CONFIG.md))

## Installation Methods

### Method 1: Docker Compose (Recommended for Testing)

This method sets up a complete stack with Keycloak and Exim4.

```bash
# Clone or download the project
cd exim4-keycloak

# Create .env file with your settings
cat > .env << EOF
KEYCLOAK_CLIENT_SECRET=your-client-secret
DEBUG=1
EOF

# Start the stack
docker-compose up -d

# Check logs
docker-compose logs -f exim4
```

**Access**:
- Keycloak Admin: http://localhost:8080 (admin/admin)
- Mailhog UI: http://localhost:8025
- Exim4 SMTP: localhost:587

### Method 2: Automated Installation (Recommended for Production)

Use the installation script on your server:

```bash
# Clone the project
git clone <repository-url>
cd exim4-keycloak

# Make install script executable
chmod +x scripts/install.sh

# Run installation
sudo ./scripts/install.sh
```

The script will:
1. Check and install dependencies
2. Install Exim4 if not present
3. Create necessary directories
4. Install token script and configuration files
5. Set proper permissions
6. Validate installation

### Method 3: Manual Installation

#### Step 1: Install Dependencies

**Debian/Ubuntu**:
```bash
sudo apt-get update
sudo apt-get install -y exim4-daemon-heavy curl jq
```

**CentOS/RHEL**:
```bash
sudo yum install -y exim curl jq
# or
sudo dnf install -y exim curl jq
```

#### Step 2: Create Directories

```bash
sudo mkdir -p /var/spool/exim4/keycloak
sudo mkdir -p /var/log/exim4
sudo chown -R Debian-exim:Debian-exim /var/spool/exim4/keycloak
sudo chown -R Debian-exim:Debian-exim /var/log/exim4
sudo chmod 700 /var/spool/exim4/keycloak
```

#### Step 3: Install Token Script

```bash
sudo cp scripts/keycloak_token.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/keycloak_token.sh
```

#### Step 4: Install Configuration Files

```bash
# Install Keycloak config
sudo cp config/keycloak.conf /etc/exim4/
sudo chown Debian-exim:Debian-exim /etc/exim4/keycloak.conf
sudo chmod 600 /etc/exim4/keycloak.conf

# Backup existing Exim4 config
sudo cp /etc/exim4/exim4.conf /etc/exim4/exim4.conf.backup

# Install new Exim4 config
sudo cp config/exim4.conf /etc/exim4/
sudo chmod 644 /etc/exim4/exim4.conf
```

## Configuration

### Step 1: Configure Keycloak Connection

Edit `/etc/exim4/keycloak.conf`:

```bash
sudo nano /etc/exim4/keycloak.conf
```

Update these values:

```bash
KEYCLOAK_URL="https://your-keycloak-server.com"
KEYCLOAK_REALM="your-realm"
KEYCLOAK_CLIENT_ID="exim4-client"
KEYCLOAK_CLIENT_SECRET="your-client-secret"
SMTP_USERNAME="mailserver@yourdomain.com"
```

### Step 2: Configure Exim4 Settings

Edit `/etc/exim4/exim4.conf`:

```bash
sudo nano /etc/exim4/exim4.conf
```

Update these sections:

#### Primary Hostname

```
primary_hostname = mail.yourdomain.com
```

#### Local Domains

```
domainlist local_domains = @ : localhost : yourdomain.com
```

#### TLS Certificates

```
tls_certificate = /etc/ssl/certs/your-cert.pem
tls_privatekey = /etc/ssl/private/your-key.pem
```

#### Smarthost Configuration

Update the router section:

```
keycloak_oauth2_relay:
  driver = manualroute
  domains = ! +local_domains
  transport = keycloak_smtp_transport
  route_list = * your-smtp-server.com::587 byname
```

And update the transport:

```
keycloak_smtp_transport:
  driver = smtp
  port = 587
  hosts_require_tls = *
  hosts_require_auth = *
```

### Step 3: Update Authenticator Hosts

Edit the authenticator to match your SMTP hosts:

```
keycloak_oauth2_client:
  driver = plaintext
  public_name = XOAUTH2
  client_send = ${run{/usr/local/bin/keycloak_token.sh}{$value}fail}
  client_condition = ${if or{{eq{$host}{your-smtp-server.com}}{eq{$host}{smtp.gmail.com}}}}
```

### Step 4: Verify Permissions

```bash
# Check ownership
sudo ls -la /etc/exim4/keycloak.conf
# Should show: -rw------- 1 Debian-exim Debian-exim

sudo ls -la /var/spool/exim4/keycloak
# Should show: drwx------ 2 Debian-exim Debian-exim

# Fix if needed
sudo chown Debian-exim:Debian-exim /etc/exim4/keycloak.conf
sudo chmod 600 /etc/exim4/keycloak.conf
sudo chown -R Debian-exim:Debian-exim /var/spool/exim4/keycloak
sudo chmod 700 /var/spool/exim4/keycloak
```

## Testing

### Test 1: Validate Exim4 Configuration

```bash
# Test configuration syntax
sudo exim4 -bV

# Test routing
sudo exim4 -bt user@example.com
```

### Test 2: Test Token Script

```bash
# Run test mode
sudo -u Debian-exim /usr/local/bin/keycloak_token.sh test
```

Expected output should show successful token retrieval.

### Test 3: Test Token Retrieval

```bash
# Get actual token
sudo -u Debian-exim /usr/local/bin/keycloak_token.sh
```

Should output a long base64-encoded string.

### Test 4: Restart Exim4

```bash
# Restart service
sudo systemctl restart exim4

# Check status
sudo systemctl status exim4

# Check logs
sudo tail -f /var/log/exim4/mainlog
```

### Test 5: Send Test Email

```bash
# Simple test
echo "Test message body" | mail -s "Test Subject" recipient@example.com

# Or using mail command
mail -s "Test from Exim4" recipient@example.com << EOF
This is a test email from Exim4 with Keycloak OAuth2 authentication.
EOF

# Check queue
sudo exim4 -bp

# Watch logs in real-time
sudo tail -f /var/log/exim4/mainlog
```

### Test 6: Manual SMTP Test

```bash
# Connect to Exim4
telnet localhost 587

# Then type:
EHLO localhost
QUIT
```

Should show `XOAUTH2` in the AUTH capabilities.

## Troubleshooting

### Issue: Token Script Fails

**Symptoms**: Script returns error or empty output

**Debug**:
```bash
# Enable debug mode
sudo nano /etc/exim4/keycloak.conf
# Set: KEYCLOAK_DEBUG="1"

# Run test again
sudo -u Debian-exim /usr/local/bin/keycloak_token.sh test

# Check logs
sudo tail -f /var/log/exim4/keycloak_auth.log
```

**Common Causes**:
- Wrong Keycloak URL
- Invalid client credentials
- Network connectivity issues
- Keycloak server not accessible

### Issue: Exim4 Won't Start

**Debug**:
```bash
# Check configuration
sudo exim4 -bV

# Check for syntax errors
sudo exim4 -C /etc/exim4/exim4.conf -bV

# Check service status
sudo systemctl status exim4

# Check system logs
sudo journalctl -u exim4 -n 50
```

### Issue: Authentication Fails

**Debug**:
```bash
# Enable debugging
sudo exim4 -d -bt user@example.com

# Test authentication manually
sudo exim4 -d+auth -bt user@example.com

# Check mainlog
sudo tail -f /var/log/exim4/mainlog | grep -i auth
```

### Issue: Permission Denied

**Fix**:
```bash
# Reset all permissions
sudo chown -R Debian-exim:Debian-exim /var/spool/exim4/keycloak
sudo chmod 700 /var/spool/exim4/keycloak
sudo chown Debian-exim:Debian-exim /etc/exim4/keycloak.conf
sudo chmod 600 /etc/exim4/keycloak.conf
sudo chown -R Debian-exim:Debian-exim /var/log/exim4
```

### Issue: Certificate Errors

**For Development** (disable verification):
```bash
# In token script, add to curl:
--insecure
```

**For Production** (fix certificates):
```bash
# Update CA certificates
sudo update-ca-certificates

# Or specify CA bundle in token script
--cacert /path/to/ca-bundle.crt
```

## Production Deployment

### 1. Security Hardening

#### Use External Secret Management

```bash
# Example with HashiCorp Vault
vault kv put secret/exim4/keycloak \
  client_id="exim4-client" \
  client_secret="your-secret"

# Update token script to fetch from Vault
```

#### Restrict File Permissions

```bash
sudo chmod 600 /etc/exim4/keycloak.conf
sudo chmod 700 /var/spool/exim4/keycloak
sudo chmod 755 /usr/local/bin/keycloak_token.sh
```

#### Enable Firewall

```bash
# Allow only necessary ports
sudo ufw allow 25/tcp   # SMTP
sudo ufw allow 587/tcp  # Submission
sudo ufw enable
```

### 2. TLS Configuration

Use valid certificates from Let's Encrypt or your CA:

```bash
# Install certbot
sudo apt-get install certbot

# Get certificate
sudo certbot certonly --standalone -d mail.yourdomain.com

# Update exim4.conf
tls_certificate = /etc/letsencrypt/live/mail.yourdomain.com/fullchain.pem
tls_privatekey = /etc/letsencrypt/live/mail.yourdomain.com/privkey.pem
```

### 3. Monitoring Setup

#### Log Rotation

```bash
# Create logrotate config
sudo nano /etc/logrotate.d/exim4-keycloak

# Add:
/var/log/exim4/keycloak_auth.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 Debian-exim Debian-exim
    sharedscripts
    postrotate
        systemctl reload exim4 > /dev/null
    endscript
}
```

#### Monitoring Script

```bash
# Create monitoring script
sudo nano /usr/local/bin/check_exim4_oauth.sh

#!/bin/bash
if ! sudo -u Debian-exim /usr/local/bin/keycloak_token.sh > /dev/null 2>&1; then
    echo "CRITICAL: Keycloak OAuth2 token fetch failed"
    exit 2
fi
echo "OK: Keycloak OAuth2 working"
exit 0
```

### 4. Backup Configuration

```bash
# Backup script
#!/bin/bash
BACKUP_DIR=/var/backups/exim4
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/exim4-config-$(date +%Y%m%d).tar.gz \
    /etc/exim4/ \
    /usr/local/bin/keycloak_token.sh
```

### 5. High Availability

For HA deployments:
- Use multiple Exim4 servers behind a load balancer
- Share configuration via configuration management (Ansible, Puppet)
- Use shared Keycloak with database replication
- Implement health checks in load balancer

## Next Steps

1. Configure DNS records (MX, SPF, DKIM)
2. Set up monitoring and alerting
3. Implement backup strategy
4. Configure log aggregation
5. Set up email queue monitoring
6. Implement rate limiting
7. Configure spam filtering (SpamAssassin)
8. Set up DMARC reporting

## Additional Resources

- [Main README](../README.md)
- [Keycloak Configuration Guide](KEYCLOAK_CONFIG.md)
- [Exim4 Official Documentation](https://exim.org/docs.html)
- [Keycloak Documentation](https://www.keycloak.org/documentation)

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review logs in `/var/log/exim4/`
3. Enable debug mode for more details
4. Consult Exim4 and Keycloak documentation
