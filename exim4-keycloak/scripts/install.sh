#!/bin/bash
#
# Exim4 with Keycloak OAuth2 - Installation Script
#
# This script installs and configures Exim4 with Keycloak OAuth2 authentication support.
#
# Usage: sudo ./install.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
EXIM_USER="Debian-exim"
EXIM_GROUP="Debian-exim"
TOKEN_SCRIPT_PATH="/usr/local/bin/keycloak_token.sh"
CONFIG_PATH="/etc/exim4/keycloak.conf"
EXIM_CONF_PATH="/etc/exim4/exim4.conf"
CACHE_DIR="/var/spool/exim4/keycloak"
LOG_DIR="/var/log/exim4"

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

print_header() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ==============================================================================
# DEPENDENCY CHECKS
# ==============================================================================

check_dependencies() {
    print_header "Checking Dependencies"
    
    local missing_deps=()
    
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi
    
    if ! command_exists jq; then
        missing_deps+=("jq")
    fi
    
    if ! command_exists base64; then
        missing_deps+=("coreutils")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warn "Missing dependencies: ${missing_deps[*]}"
        print_info "Installing dependencies..."
        
        if command_exists apt-get; then
            apt-get update
            apt-get install -y "${missing_deps[@]}"
        elif command_exists yum; then
            yum install -y "${missing_deps[@]}"
        elif command_exists dnf; then
            dnf install -y "${missing_deps[@]}"
        else
            print_error "Could not detect package manager. Please install manually: ${missing_deps[*]}"
            exit 1
        fi
    fi
    
    print_success "All dependencies satisfied"
}

# ==============================================================================
# EXIM4 INSTALLATION
# ==============================================================================

install_exim4() {
    print_header "Installing Exim4"
    
    if command_exists exim4; then
        print_info "Exim4 is already installed"
        exim4 -bV | head -n1
        return 0
    fi
    
    print_info "Installing Exim4..."
    
    if command_exists apt-get; then
        # Debian/Ubuntu
        DEBIAN_FRONTEND=noninteractive apt-get install -y exim4-daemon-heavy exim4-base
    elif command_exists yum; then
        # CentOS/RHEL 7
        yum install -y exim
    elif command_exists dnf; then
        # CentOS/RHEL 8+
        dnf install -y exim
    else
        print_error "Could not detect package manager. Please install Exim4 manually"
        exit 1
    fi
    
    print_success "Exim4 installed successfully"
}

# ==============================================================================
# DIRECTORY SETUP
# ==============================================================================

setup_directories() {
    print_header "Setting Up Directories"
    
    # Create cache directory
    if [[ ! -d "$CACHE_DIR" ]]; then
        print_info "Creating cache directory: $CACHE_DIR"
        mkdir -p "$CACHE_DIR"
    fi
    chown -R "$EXIM_USER:$EXIM_GROUP" "$CACHE_DIR"
    chmod 700 "$CACHE_DIR"
    print_success "Cache directory configured: $CACHE_DIR"
    
    # Ensure log directory exists
    if [[ ! -d "$LOG_DIR" ]]; then
        print_info "Creating log directory: $LOG_DIR"
        mkdir -p "$LOG_DIR"
    fi
    chown -R "$EXIM_USER:$EXIM_GROUP" "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    print_success "Log directory configured: $LOG_DIR"
}

# ==============================================================================
# FILE INSTALLATION
# ==============================================================================

install_token_script() {
    print_header "Installing Token Script"
    
    local source_script="$PROJECT_ROOT/scripts/keycloak_token.sh"
    
    if [[ ! -f "$source_script" ]]; then
        print_error "Source script not found: $source_script"
        exit 1
    fi
    
    print_info "Copying token script to $TOKEN_SCRIPT_PATH"
    cp "$source_script" "$TOKEN_SCRIPT_PATH"
    
    print_info "Setting permissions..."
    chmod 755 "$TOKEN_SCRIPT_PATH"
    chown root:root "$TOKEN_SCRIPT_PATH"
    
    print_success "Token script installed: $TOKEN_SCRIPT_PATH"
}

install_config_files() {
    print_header "Installing Configuration Files"
    
    # Install Keycloak config
    local source_keycloak_conf="$PROJECT_ROOT/config/keycloak.conf"
    
    if [[ ! -f "$source_keycloak_conf" ]]; then
        print_error "Source config not found: $source_keycloak_conf"
        exit 1
    fi
    
    if [[ -f "$CONFIG_PATH" ]]; then
        print_warn "Configuration file already exists: $CONFIG_PATH"
        print_info "Creating backup: ${CONFIG_PATH}.backup"
        cp "$CONFIG_PATH" "${CONFIG_PATH}.backup"
    fi
    
    print_info "Installing Keycloak configuration: $CONFIG_PATH"
    cp "$source_keycloak_conf" "$CONFIG_PATH"
    chown "$EXIM_USER:$EXIM_GROUP" "$CONFIG_PATH"
    chmod 600 "$CONFIG_PATH"
    print_success "Keycloak config installed: $CONFIG_PATH"
    
    # Install Exim4 config
    local source_exim_conf="$PROJECT_ROOT/config/exim4.conf"
    
    if [[ ! -f "$source_exim_conf" ]]; then
        print_error "Source Exim4 config not found: $source_exim_conf"
        exit 1
    fi
    
    if [[ -f "$EXIM_CONF_PATH" ]]; then
        print_warn "Exim4 configuration file already exists: $EXIM_CONF_PATH"
        print_info "Creating backup: ${EXIM_CONF_PATH}.backup"
        cp "$EXIM_CONF_PATH" "${EXIM_CONF_PATH}.backup"
    fi
    
    print_info "Installing Exim4 configuration: $EXIM_CONF_PATH"
    cp "$source_exim_conf" "$EXIM_CONF_PATH"
    chown root:root "$EXIM_CONF_PATH"
    chmod 644 "$EXIM_CONF_PATH"
    print_success "Exim4 config installed: $EXIM_CONF_PATH"
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

configure_keycloak() {
    print_header "Configuring Keycloak Settings"
    
    print_warn "You need to edit $CONFIG_PATH with your Keycloak credentials"
    echo
    echo "Required settings:"
    echo "  - KEYCLOAK_URL: Your Keycloak server URL"
    echo "  - KEYCLOAK_REALM: Your Keycloak realm name"
    echo "  - KEYCLOAK_CLIENT_ID: OAuth2 client ID"
    echo "  - KEYCLOAK_CLIENT_SECRET: OAuth2 client secret"
    echo "  - SMTP_USERNAME: Email address for authentication"
    echo
    
    read -p "Do you want to edit the configuration now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} "$CONFIG_PATH"
    else
        print_warn "Remember to edit $CONFIG_PATH before using Exim4!"
    fi
}

# ==============================================================================
# VALIDATION
# ==============================================================================

validate_installation() {
    print_header "Validating Installation"
    
    local errors=0
    
    # Check token script
    if [[ -f "$TOKEN_SCRIPT_PATH" ]] && [[ -x "$TOKEN_SCRIPT_PATH" ]]; then
        print_success "Token script installed and executable"
    else
        print_error "Token script not found or not executable: $TOKEN_SCRIPT_PATH"
        ((errors++))
    fi
    
    # Check config file
    if [[ -f "$CONFIG_PATH" ]]; then
        print_success "Keycloak config file exists"
    else
        print_error "Keycloak config file not found: $CONFIG_PATH"
        ((errors++))
    fi
    
    # Check Exim4 config
    if [[ -f "$EXIM_CONF_PATH" ]]; then
        print_success "Exim4 config file exists"
    else
        print_error "Exim4 config file not found: $EXIM_CONF_PATH"
        ((errors++))
    fi
    
    # Check directories
    if [[ -d "$CACHE_DIR" ]]; then
        print_success "Cache directory exists"
    else
        print_error "Cache directory not found: $CACHE_DIR"
        ((errors++))
    fi
    
    # Test Exim4 config syntax
    print_info "Testing Exim4 configuration syntax..."
    if exim4 -bV >/dev/null 2>&1; then
        print_success "Exim4 configuration syntax valid"
    else
        print_error "Exim4 configuration has syntax errors"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_success "All validation checks passed"
        return 0
    else
        print_error "Validation failed with $errors error(s)"
        return 1
    fi
}

# ==============================================================================
# POST-INSTALLATION
# ==============================================================================

post_install() {
    print_header "Post-Installation Steps"
    
    echo "Installation completed! Next steps:"
    echo
    echo "1. Configure Keycloak credentials:"
    echo "   sudo nano $CONFIG_PATH"
    echo
    echo "2. Test token fetching:"
    echo "   sudo -u $EXIM_USER $TOKEN_SCRIPT_PATH test"
    echo
    echo "3. Update Exim4 configuration for your environment:"
    echo "   sudo nano $EXIM_CONF_PATH"
    echo "   - Update primary_hostname"
    echo "   - Update local_domains"
    echo "   - Update TLS certificates"
    echo "   - Update smarthost settings"
    echo
    echo "4. Restart Exim4:"
    echo "   sudo systemctl restart exim4"
    echo
    echo "5. Monitor logs:"
    echo "   sudo tail -f /var/log/exim4/mainlog"
    echo "   sudo tail -f /var/log/exim4/keycloak_auth.log"
    echo
    echo "6. Send a test email:"
    echo "   echo 'Test message' | mail -s 'Test' user@example.com"
    echo
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    print_header "Exim4 with Keycloak OAuth2 - Installation"
    
    check_root
    check_dependencies
    install_exim4
    setup_directories
    install_token_script
    install_config_files
    configure_keycloak
    validate_installation
    post_install
    
    print_success "Installation complete!"
}

main "$@"
