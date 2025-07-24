#!/usr/bin/env bash

# Nix Webserver Verification Script
# This script verifies that the installation is working correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/home/ubuntu/nix-webserver"
WEB_DIR="/home/ubuntu/web"
LOGS_DIR="/home/ubuntu/logs"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓ PASS]${NC} $1"
    ((PASSED++))
}

log_warning() {
    echo -e "${YELLOW}[⚠ WARN]${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[✗ FAIL]${NC} $1"
    ((FAILED++))
}

check_user() {
    log_info "Checking user environment..."
    
    if [[ "$(whoami)" == "ubuntu" ]]; then
        log_success "Running as ubuntu user"
    else
        log_error "Not running as ubuntu user (current: $(whoami))"
    fi
}

check_nix() {
    log_info "Checking Nix installation..."
    
    if command -v nix &> /dev/null; then
        log_success "Nix is installed"
        
        # Check Nix version
        NIX_VERSION=$(nix --version | head -n1)
        log_info "Nix version: $NIX_VERSION"
        
        # Check if flakes are enabled
        if nix flake --help &> /dev/null; then
            log_success "Nix flakes are enabled"
        else
            log_error "Nix flakes are not enabled"
        fi
    else
        log_error "Nix is not installed or not in PATH"
    fi
}

check_home_manager() {
    log_info "Checking Home Manager..."
    
    if nix run home-manager/master -- --help &> /dev/null; then
        log_success "Home Manager is available"
    else
        log_error "Home Manager is not available"
    fi
}

check_directories() {
    log_info "Checking directory structure..."
    
    local dirs=(
        "$INSTALL_DIR"
        "$WEB_DIR"
        "$WEB_DIR/sites"
        "$WEB_DIR/acme-challenge"
        "$WEB_DIR/.well-known/acme-challenge"
        "$LOGS_DIR"
        "$HOME/.config/nginx"
        "$HOME/.config/letsencrypt"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Directory exists: $dir"
        else
            log_error "Directory missing: $dir"
        fi
    done
}

check_config_files() {
    log_info "Checking configuration files..."
    
    local files=(
        "$INSTALL_DIR/flake.nix"
        "$INSTALL_DIR/home.nix"
        "$INSTALL_DIR/web.nix"
        "$INSTALL_DIR/deploy.sh"
        "$HOME/.config/nginx/nginx.conf"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "File exists: $file"
        else
            log_error "File missing: $file"
        fi
    done
}

check_services() {
    log_info "Checking systemd services..."
    
    # Check if nginx service exists
    if systemctl --user list-unit-files | grep -q "nginx.service"; then
        log_success "Nginx service is configured"
        
        # Check if nginx is running
        if systemctl --user is-active --quiet nginx.service; then
            log_success "Nginx service is running"
        else
            log_warning "Nginx service is not running"
            log_info "Status: $(systemctl --user is-active nginx.service || echo 'inactive')"
        fi
    else
        log_error "Nginx service is not configured"
    fi
    
    # Check certbot timer
    if systemctl --user list-unit-files | grep -q "certbot-renewal.timer"; then
        log_success "Certbot renewal timer is configured"
        
        if systemctl --user is-active --quiet certbot-renewal.timer; then
            log_success "Certbot renewal timer is active"
        else
            log_warning "Certbot renewal timer is not active"
        fi
    else
        log_error "Certbot renewal timer is not configured"
    fi
}

check_nginx_config() {
    log_info "Checking Nginx configuration..."
    
    if [[ -f "$HOME/.config/nginx/nginx.conf" ]]; then
        if nginx -t -c "$HOME/.config/nginx/nginx.conf" 2>/dev/null; then
            log_success "Nginx configuration is valid"
        else
            log_error "Nginx configuration has errors"
            log_info "Run 'nginx -t -c ~/.config/nginx/nginx.conf' for details"
        fi
    else
        log_error "Nginx configuration file not found"
    fi
}

check_network() {
    log_info "Checking network connectivity..."
    
    # Check if ports are listening
    if ss -tlnp | grep -q ":80 "; then
        log_success "Port 80 is listening"
    else
        log_warning "Port 80 is not listening"
    fi
    
    if ss -tlnp | grep -q ":443 "; then
        log_success "Port 443 is listening"
    else
        log_warning "Port 443 is not listening"
    fi
    
    # Test local HTTP connection
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302\|404"; then
        log_success "Local HTTP connection works"
    else
        log_warning "Local HTTP connection failed"
    fi
}

check_firewall() {
    log_info "Checking firewall configuration..."
    
    if command -v ufw &> /dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            log_success "UFW firewall is active"
            
            # Check if required ports are open
            if sudo ufw status | grep -q "80/tcp"; then
                log_success "Port 80 is allowed in firewall"
            else
                log_warning "Port 80 is not explicitly allowed in firewall"
            fi
            
            if sudo ufw status | grep -q "443/tcp"; then
                log_success "Port 443 is allowed in firewall"
            else
                log_warning "Port 443 is not explicitly allowed in firewall"
            fi
        else
            log_warning "UFW firewall is not active"
        fi
    else
        log_warning "UFW firewall is not installed"
    fi
}

check_sites() {
    log_info "Checking configured sites..."
    
    if [[ -d "$INSTALL_DIR/sites" ]]; then
        local site_count=0
        for site in "$INSTALL_DIR/sites"/*/; do
            if [[ -f "$site/flake.nix" ]]; then
                site_name=$(basename "$site")
                domain=$(grep -o 'domain = "[^"]*"' "$site/flake.nix" | cut -d'"' -f2 2>/dev/null || echo "unknown")
                log_info "Found site: $site_name (domain: $domain)"
                ((site_count++))
            fi
        done
        
        if [[ $site_count -gt 0 ]]; then
            log_success "Found $site_count configured site(s)"
        else
            log_warning "No sites are configured yet"
        fi
    else
        log_error "Sites directory not found"
    fi
}

show_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "                        VERIFICATION SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${GREEN}Passed:${NC}   $PASSED"
    echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
    echo -e "${RED}Failed:${NC}   $FAILED"
    echo "═══════════════════════════════════════════════════════════════"
    
    if [[ $FAILED -eq 0 ]]; then
        if [[ $WARNINGS -eq 0 ]]; then
            echo -e "${GREEN}🎉 All checks passed! Your Nix webserver is ready to use.${NC}"
        else
            echo -e "${YELLOW}⚠️  Installation is mostly working, but there are some warnings to address.${NC}"
        fi
    else
        echo -e "${RED}❌ There are issues that need to be fixed before the webserver will work properly.${NC}"
        echo
        echo "Common fixes:"
        echo "  • Run './deploy.sh deploy' to redeploy configuration"
        echo "  • Check service logs with './deploy.sh logs <service-name>'"
        echo "  • Ensure all required directories exist"
        echo "  • Verify Nix and Home Manager are properly installed"
    fi
    
    echo
}

show_next_steps() {
    if [[ $FAILED -eq 0 ]]; then
        echo "Next steps:"
        echo "  1. Add your sites: cp -r sites/example-static sites/yoursite.com"
        echo "  2. Configure domains in site flake.nix files"
        echo "  3. Add sites to main flake.nix"
        echo "  4. Deploy: ./deploy.sh deploy"
        echo "  5. Test: ./deploy.sh test-sites"
        echo
    fi
}

# Main verification process
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 Nix Webserver Verification                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    
    # Run all checks
    check_user
    check_nix
    check_home_manager
    check_directories
    check_config_files
    check_services
    check_nginx_config
    check_network
    check_firewall
    check_sites
    
    # Show results
    show_summary
    show_next_steps
}

# Run main function
main "$@"