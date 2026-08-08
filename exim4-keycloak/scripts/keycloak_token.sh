#!/bin/bash
#
# Keycloak OAuth2 Token Fetcher for Exim4
# 
# This script fetches OAuth2 access tokens from Keycloak using the Client Credentials Grant flow
# and returns them in XOAUTH2 format for Exim4 SMTP authentication.
#
# Usage: keycloak_token.sh [test]
#   Without arguments: Returns base64-encoded XOAUTH2 string for Exim4
#   With 'test' argument: Outputs human-readable token info for testing
#
# Requirements:
#   - curl: HTTP client
#   - jq: JSON processor
#   - base64: Encoding utility
#
# Configuration via environment variables or config file

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Load from config file if exists
CONFIG_FILE="${KEYCLOAK_CONFIG_FILE:-/etc/exim4/keycloak.conf}"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Keycloak Configuration (override via environment variables)
KEYCLOAK_URL="${KEYCLOAK_URL:-https://keycloak.example.com}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-master}"
CLIENT_ID="${KEYCLOAK_CLIENT_ID:-exim4-client}"
CLIENT_SECRET="${KEYCLOAK_CLIENT_SECRET:-}"
SCOPE="${KEYCLOAK_SCOPE:-openid email profile}"

# Email Configuration
SMTP_USERNAME="${SMTP_USERNAME:-mailserver@example.com}"

# Token Cache Configuration
CACHE_DIR="${KEYCLOAK_CACHE_DIR:-/var/spool/exim4/keycloak}"
ACCESS_TOKEN_FILE="$CACHE_DIR/access_token.json"
LOCK_FILE="$CACHE_DIR/.token.lock"

# Timing Configuration (in seconds)
TOKEN_EXPIRY_BUFFER=300  # Refresh token 5 minutes before actual expiry

# Logging
LOG_FILE="${KEYCLOAK_LOG_FILE:-/var/log/exim4/keycloak_auth.log}"
DEBUG="${KEYCLOAK_DEBUG:-0}"

# ==============================================================================
# LOGGING FUNCTIONS
# ==============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file if writable
    if [[ -w "$(dirname "$LOG_FILE")" ]] || [[ -w "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    # Debug messages to stderr in debug mode
    if [[ "$DEBUG" == "1" ]] && [[ "$level" == "DEBUG" ]]; then
        echo "[$timestamp] [$level] $message" >&2
    fi
    
    # Errors always to stderr
    if [[ "$level" == "ERROR" ]]; then
        echo "[$timestamp] [$level] $message" >&2
    fi
}

debug() {
    log "DEBUG" "$@"
}

info() {
    log "INFO" "$@"
}

error() {
    log "ERROR" "$@"
}

# ==============================================================================
# VALIDATION
# ==============================================================================

validate_config() {
    local errors=0
    
    if [[ -z "$KEYCLOAK_URL" ]]; then
        error "KEYCLOAK_URL is not set"
        ((errors++))
    fi
    
    if [[ -z "$KEYCLOAK_REALM" ]]; then
        error "KEYCLOAK_REALM is not set"
        ((errors++))
    fi
    
    if [[ -z "$CLIENT_ID" ]]; then
        error "CLIENT_ID is not set"
        ((errors++))
    fi
    
    if [[ -z "$CLIENT_SECRET" ]]; then
        error "CLIENT_SECRET is not set"
        ((errors++))
    fi
    
    if [[ -z "$SMTP_USERNAME" ]]; then
        error "SMTP_USERNAME is not set"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        error "Configuration validation failed with $errors error(s)"
        return 1
    fi
    
    return 0
}

# ==============================================================================
# TOKEN CACHE MANAGEMENT
# ==============================================================================

init_cache_dir() {
    if [[ ! -d "$CACHE_DIR" ]]; then
        debug "Creating cache directory: $CACHE_DIR"
        mkdir -p "$CACHE_DIR"
        chmod 700 "$CACHE_DIR"
    fi
}

get_cached_token() {
    if [[ ! -f "$ACCESS_TOKEN_FILE" ]]; then
        debug "No cached token found"
        return 1
    fi
    
    local cached_token
    cached_token=$(cat "$ACCESS_TOKEN_FILE")
    
    if ! echo "$cached_token" | jq -e . >/dev/null 2>&1; then
        debug "Cached token is not valid JSON"
        return 1
    fi
    
    local expiry
    expiry=$(echo "$cached_token" | jq -r '.expiry // 0')
    local current_time
    current_time=$(date +%s)
    
    if [[ $((expiry - TOKEN_EXPIRY_BUFFER)) -lt $current_time ]]; then
        debug "Cached token expired or expiring soon (expiry: $expiry, now: $current_time)"
        return 1
    fi
    
    debug "Valid cached token found (expires at $expiry)"
    echo "$cached_token" | jq -r '.access_token'
    return 0
}

cache_token() {
    local access_token="$1"
    local expires_in="$2"
    local current_time
    current_time=$(date +%s)
    local expiry=$((current_time + expires_in))
    
    local cache_data
    cache_data=$(jq -n \
        --arg token "$access_token" \
        --arg expiry "$expiry" \
        --arg fetched "$current_time" \
        '{access_token: $token, expiry: ($expiry | tonumber), fetched_at: ($fetched | tonumber)}')
    
    echo "$cache_data" > "$ACCESS_TOKEN_FILE"
    chmod 600 "$ACCESS_TOKEN_FILE"
    
    debug "Token cached (expires at $expiry)"
}

# ==============================================================================
# KEYCLOAK TOKEN FETCHING
# ==============================================================================

acquire_lock() {
    local timeout=10
    local waited=0
    
    while [[ -f "$LOCK_FILE" ]] && [[ $waited -lt $timeout ]]; do
        debug "Waiting for lock... ($waited/$timeout)"
        sleep 1
        ((waited++))
    done
    
    if [[ -f "$LOCK_FILE" ]]; then
        error "Failed to acquire lock after $timeout seconds"
        return 1
    fi
    
    echo $$ > "$LOCK_FILE"
    debug "Lock acquired"
    return 0
}

release_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        debug "Lock released"
    fi
}

fetch_token_from_keycloak() {
    local token_endpoint="$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/token"
    
    debug "Fetching token from Keycloak: $token_endpoint"
    
    local response
    local http_code
    
    response=$(curl -s -w "\n%{http_code}" -X POST "$token_endpoint" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -d "client_id=$CLIENT_ID" \
        -d "client_secret=$CLIENT_SECRET" \
        -d "scope=$SCOPE" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')
    
    if [[ "$http_code" != "200" ]]; then
        error "Keycloak token request failed with HTTP $http_code"
        error "Response: $body"
        return 1
    fi
    
    if ! echo "$body" | jq -e . >/dev/null 2>&1; then
        error "Invalid JSON response from Keycloak"
        return 1
    fi
    
    local access_token
    access_token=$(echo "$body" | jq -r '.access_token')
    
    if [[ -z "$access_token" ]] || [[ "$access_token" == "null" ]]; then
        error "No access_token in response"
        return 1
    fi
    
    local expires_in
    expires_in=$(echo "$body" | jq -r '.expires_in // 3600')
    
    info "Successfully fetched new access token (expires in ${expires_in}s)"
    
    # Cache the token
    cache_token "$access_token" "$expires_in"
    
    echo "$access_token"
    return 0
}

get_access_token() {
    # Try cached token first
    local token
    if token=$(get_cached_token); then
        echo "$token"
        return 0
    fi
    
    # Need to fetch new token - use lock to prevent concurrent requests
    if ! acquire_lock; then
        # If lock failed, try cached token again (might have been refreshed)
        if token=$(get_cached_token); then
            echo "$token"
            return 0
        fi
        error "Failed to acquire lock and no cached token available"
        return 1
    fi
    
    # Fetch new token
    if token=$(fetch_token_from_keycloak); then
        release_lock
        echo "$token"
        return 0
    else
        release_lock
        error "Failed to fetch token from Keycloak"
        return 1
    fi
}

# ==============================================================================
# XOAUTH2 FORMATTING
# ==============================================================================

format_xoauth2() {
    local access_token="$1"
    local username="$SMTP_USERNAME"
    
    # XOAUTH2 format: user=USERNAME\001auth=Bearer TOKEN\001\001
    # \001 is ASCII character 1 (^A / Ctrl-A)
    local xoauth2_string
    xoauth2_string=$(printf "user=%s\001auth=Bearer %s\001\001" "$username" "$access_token")
    
    # Base64 encode (no line wrapping)
    echo -n "$xoauth2_string" | base64 -w0
}

# ==============================================================================
# TEST MODE
# ==============================================================================

test_mode() {
    echo "========================================"
    echo "Keycloak Token Fetcher - Test Mode"
    echo "========================================"
    echo
    
    echo "Configuration:"
    echo "  Keycloak URL: $KEYCLOAK_URL"
    echo "  Realm: $KEYCLOAK_REALM"
    echo "  Client ID: $CLIENT_ID"
    echo "  Client Secret: ${CLIENT_SECRET:0:4}****"
    echo "  SMTP Username: $SMTP_USERNAME"
    echo "  Cache Directory: $CACHE_DIR"
    echo
    
    echo "Validating configuration..."
    if ! validate_config; then
        echo "ERROR: Configuration validation failed"
        exit 1
    fi
    echo "✓ Configuration valid"
    echo
    
    echo "Initializing cache directory..."
    init_cache_dir
    echo "✓ Cache directory ready"
    echo
    
    echo "Fetching access token..."
    local access_token
    if ! access_token=$(get_access_token); then
        echo "ERROR: Failed to fetch access token"
        exit 1
    fi
    echo "✓ Access token acquired"
    echo "  Token (first 50 chars): ${access_token:0:50}..."
    echo "  Token length: ${#access_token}"
    echo
    
    echo "Formatting XOAUTH2 string..."
    local xoauth2
    xoauth2=$(format_xoauth2 "$access_token")
    echo "✓ XOAUTH2 formatted"
    echo "  Encoded length: ${#xoauth2}"
    echo "  Encoded (first 80 chars): ${xoauth2:0:80}..."
    echo
    
    echo "Checking token cache..."
    if [[ -f "$ACCESS_TOKEN_FILE" ]]; then
        echo "✓ Token cached"
        local cached_data
        cached_data=$(cat "$ACCESS_TOKEN_FILE")
        local expiry
        expiry=$(echo "$cached_data" | jq -r '.expiry')
        local expiry_date
        expiry_date=$(date -d "@$expiry" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")
        echo "  Expires at: $expiry_date"
    fi
    echo
    
    echo "========================================"
    echo "Test completed successfully!"
    echo "========================================"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    # Test mode
    if [[ "${1:-}" == "test" ]]; then
        test_mode
        exit 0
    fi
    
    # Production mode - output only XOAUTH2 string
    if ! validate_config; then
        exit 1
    fi
    
    init_cache_dir
    
    local access_token
    if ! access_token=$(get_access_token); then
        exit 1
    fi
    
    format_xoauth2 "$access_token"
}

# Run main function
main "$@"
