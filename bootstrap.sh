#!/usr/bin/env bash

# Nix Webserver Bootstrap Script
# This script downloads and installs the Nix webserver configuration
# Works with any user account on Ubuntu/Debian systems

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/vivekrwt365/nix-webserver.git"  # Update this with your actual repo
REPO_BRANCH="main"  # Change if using a different branch
CURRENT_USER="$(whoami)"
USER_HOME="$(eval echo ~$CURRENT_USER)"
TEMP_DIR="$USER_HOME/.tmp-nix-webserver-install"
INSTALL_DIR="$USER_HOME/nix-webserver"

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

check_user_suitability() {
    log_info "Checking user account suitability..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root."
        log_info "For security reasons, please create a regular user account and run this script from there."
        echo
        log_info "To create a new user account:"
        echo "  1. Create user: sudo adduser <username>"
        echo "  2. Add to sudo group: sudo usermod -aG sudo <username>"
        echo "  3. Switch to user: su - <username>"
        echo "  4. Run this script again"
        exit 1
    fi
    
    # Check if user is admin/administrator (common admin usernames)
    if [[ "$CURRENT_USER" =~ ^(admin|administrator|root)$ ]]; then
        log_warning "Running as admin/administrator user: $CURRENT_USER"
        log_info "For better security, consider creating a dedicated user account for the webserver."
        echo
        read -p "Do you want to continue with this user account? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled. Please create a dedicated user account."
            echo
            log_info "To create a new user account:"
            echo "  1. Create user: sudo adduser <username>"
            echo "  2. Add to sudo group: sudo usermod -aG sudo <username>"
            echo "  3. Switch to user: su - <username>"
            echo "  4. Run this script again"
            exit 0
        fi
    fi
    
    log_success "User account: $CURRENT_USER (suitable for installation)"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo access for system package installation."
        log_info "You may be prompted for your password."
    fi
    
    # Check Ubuntu/Debian
    if ! grep -qE "Ubuntu|Debian" /etc/os-release 2>/dev/null; then
        log_warning "This script is designed for Ubuntu/Debian. Other distributions may not work correctly."
    fi
    
    log_success "Prerequisites check passed"
}

install_git() {
    log_info "Ensuring git is installed..."
    
    if ! command -v git &> /dev/null; then
        log_info "Installing git..."
        sudo apt update
        sudo apt install -y git
    fi
    
    log_success "Git is available"
}

check_existing_installation() {
    if [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/flake.nix" ]]; then
        log_warning "Nix webserver appears to already be installed at: $INSTALL_DIR"
        echo "This will update the existing installation."
        echo
        read -p "Continue with update? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled by user."
            exit 0
        fi
    fi
}

download_config() {
    log_info "Downloading Nix webserver configuration..."
    
    # Remove existing temp directory if it exists
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Clone the repository
    if ! git clone -b "$REPO_BRANCH" "$REPO_URL" "$TEMP_DIR" 2>/dev/null; then
        log_error "Failed to download configuration from: $REPO_URL"
        log_info "Please check:"
        log_info "  - Internet connection"
        log_info "  - Repository URL is correct"
        log_info "  - Repository is publicly accessible"
        exit 1
    fi
    
    log_success "Configuration downloaded successfully"
}

run_installer() {
    log_info "Starting interactive installer..."
    
    cd "$TEMP_DIR"
    
    # Make the install script executable
    if [[ -f "install.sh" ]]; then
        chmod +x install.sh
        
        # Run the interactive installer
        ./install.sh
    else
        log_error "install.sh not found in the downloaded configuration."
        log_info "Please check that the repository contains the installer script."
        exit 1
    fi
}

cleanup() {
    log_info "Cleaning up temporary files..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    log_success "Cleanup completed"
}

show_banner() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "                   Nix Webserver Bootstrap                      "
    echo "                                                                "
    echo "    This script will install Nix and set up a complete          "
    echo "    webserver configuration with automatic SSL certificates.    "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
}

confirm_installation() {
    echo "This script will:"
    echo "  • Install system dependencies (requires sudo)"
    echo "  • Install the Nix package manager"
    echo "  • Set up webserver configuration in: $INSTALL_DIR"
    echo "  • Run interactive configuration setup"
    echo "  • Configure firewall rules"
    echo "  • Set up automatic SSL certificates"
    echo
    echo "Current user: $CURRENT_USER"
    echo "Install directory: $INSTALL_DIR"
    echo
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled."
        exit 0
    fi
}

show_bootstrap_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "               Nix Webserver Bootstrap Installer                "
    echo "                                                                "
    echo "   This script will download and install a complete             "
    echo "   webserver configuration using Nix package manager.           "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Main bootstrap process
main() {
    show_bootstrap_banner
    
    log_info "Current user: ${MAGENTA}$CURRENT_USER${NC}"
    log_info "Installation target: ${MAGENTA}$INSTALL_DIR${NC}"
    echo
    
    # Pre-flight checks
    check_user_suitability
    check_prerequisites
    check_existing_installation
    confirm_installation
    
    # Bootstrap steps
    install_git
    download_config
    run_installer
    cleanup
    
    echo
    log_success "Bootstrap completed successfully!"
    log_info "Your Nix webserver installation is complete."
    log_info "Configuration directory: ${CYAN}$INSTALL_DIR${NC}"
    echo
    log_info "To manage your webserver, use:"
    echo -e "  ${CYAN}cd $INSTALL_DIR${NC}"
    echo -e "  ${CYAN}./deploy.sh help${NC}"
}

# Error handling
trap 'log_error "An error occurred during installation. Check the output above for details."; cleanup; exit 1' ERR

# Run main function
main "$@"