#!/usr/bin/env bash

# Nix Webserver Deployment Script
# This script automates common deployment tasks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Dynamic configuration based on current user
CURRENT_USER="$(whoami)"
USER_HOME="$(eval echo ~$CURRENT_USER)"
WEB_DIR="$USER_HOME/web"
LOGS_DIR="$USER_HOME/logs"
ACME_DIR="$USER_HOME/web/acme-challenge"
CONFIG_DIR="$USER_HOME/nix-webserver"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "flake.nix" ]]; then
        log_error "flake.nix not found. Please run this script from the nix-webserver directory."
        exit 1
    fi
    
    # Check if Nix is installed
    if ! command -v nix &> /dev/null; then
        log_error "Nix is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Home Manager is available
    if ! nix run home-manager/master -- --help &> /dev/null; then
        log_error "Home Manager is not available"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

setup_directories() {
    log_info "Setting up required directories..."
    
    mkdir -p "$WEB_DIR/sites"
    mkdir -p "$LOGS_DIR"
    mkdir -p "$ACME_DIR"
    
    # Set proper permissions
    chmod 755 "$WEB_DIR" "$LOGS_DIR" "$ACME_DIR"
    
    log_success "Directories created and configured"
}

update_flake() {
    log_info "Updating flake inputs..."
    
    if nix flake update; then
        log_success "Flake inputs updated successfully"
    else
        log_error "Failed to update flake inputs"
        exit 1
    fi
}

deploy_config() {
    log_info "Deploying configuration..."
    
    if nix run home-manager/master -- switch --flake .; then
        log_success "Configuration deployed successfully"
    else
        log_error "Failed to deploy configuration"
        exit 1
    fi
}

check_services() {
    log_info "Checking service status..."
    
    # Check Nginx
    if systemctl --user is-active --quiet nginx.service; then
        log_success "Nginx service is running"
    else
        log_warning "Nginx service is not running"
        systemctl --user status nginx.service || true
    fi
    
    # Check Certbot timer
    if systemctl --user is-active --quiet certbot-renewal.timer; then
        log_success "Certbot renewal timer is active"
    else
        log_warning "Certbot renewal timer is not active"
        systemctl --user status certbot-renewal.timer || true
    fi
    
    # List all user services
    log_info "All user services:"
    systemctl --user list-units --type=service --state=running | grep -E "(nginx|certbot|php|nodejs)" || log_info "No additional services found"
}

test_nginx() {
    log_info "Testing Nginx configuration..."
    
    if nginx -t -c "$HOME/.config/nginx/nginx.conf" 2>/dev/null; then
        log_success "Nginx configuration is valid"
    else
        log_error "Nginx configuration test failed"
        nginx -t -c "$HOME/.config/nginx/nginx.conf" || true
        exit 1
    fi
}

show_logs() {
    local service="$1"
    log_info "Showing logs for $service..."
    
    if systemctl --user is-active --quiet "$service"; then
        journalctl --user -u "$service" -n 20 --no-pager
    else
        log_warning "Service $service is not running"
    fi
}

list_sites() {
    log_info "Configured sites:"
    
    if [[ -d "sites" ]]; then
        for site in sites/*/; do
            if [[ -f "$site/flake.nix" ]]; then
                site_name=$(basename "$site")
                domain=$(grep -o 'domain = "[^"]*"' "$site/flake.nix" | cut -d'"' -f2 || echo "unknown")
                echo "  - $site_name (domain: $domain)"
            fi
        done
    else
        log_warning "No sites directory found"
    fi
}

test_sites() {
    log_info "Testing site connectivity..."
    
    if [[ -d "sites" ]]; then
        for site in sites/*/; do
            if [[ -f "$site/flake.nix" ]]; then
                domain=$(grep -o 'domain = "[^"]*"' "$site/flake.nix" | cut -d'"' -f2 || echo "")
                if [[ -n "$domain" && "$domain" != "unknown" ]]; then
                    log_info "Testing $domain..."
                    if curl -s -o /dev/null -w "%{http_code}" "https://$domain" | grep -q "200\|301\|302"; then
                        log_success "$domain is responding"
                    else
                        log_warning "$domain is not responding properly"
                    fi
                fi
            fi
        done
    fi
}

run_verify() {
    log_info "Running system verification..."
    
    if [[ -f "./verify.sh" ]]; then
        ./verify.sh
    else
        log_error "verify.sh script not found"
        exit 1
    fi
}

show_help() {
    cat << EOF
Nix Webserver Deployment Script

Usage: $0 [COMMAND]

Commands:
  deploy          Full deployment (update + deploy + check)
  update          Update flake inputs only
  switch          Deploy configuration only
  check           Check service status
  test            Test Nginx configuration
  verify          Run comprehensive system verification
  logs [SERVICE]  Show logs for a service
  sites           List configured sites
  test-sites      Test site connectivity
  setup           Setup required directories
  help            Show this help message

Examples:
  $0 deploy                    # Full deployment
  $0 verify                    # Verify installation
  $0 logs nginx.service        # Show Nginx logs
  $0 test                      # Test Nginx config
  $0 sites                     # List all sites

For more information, see README.md and INSTALL.md
EOF
}

# Main script logic
case "${1:-help}" in
    "deploy")
        check_prerequisites
        setup_directories
        update_flake
        deploy_config
        test_nginx
        check_services
        log_success "Deployment completed successfully!"
        ;;
    "update")
        check_prerequisites
        update_flake
        ;;
    "switch")
        check_prerequisites
        deploy_config
        ;;
    "check")
        check_services
        ;;
    "test")
        test_nginx
        ;;
    "verify")
        run_verify
        ;;
    "logs")
        if [[ -n "${2:-}" ]]; then
            show_logs "$2"
        else
            log_error "Please specify a service name"
            echo "Usage: $0 logs [SERVICE]"
            exit 1
        fi
        ;;
    "sites")
        list_sites
        ;;
    "test-sites")
        test_sites
        ;;
    "setup")
        setup_directories
        ;;
    "help")
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac