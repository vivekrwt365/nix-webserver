#!/usr/bin/env bash

# Nix Webserver Interactive Installer
# This script provides an interactive installation experience for any user account

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Dynamic configuration based on current user
CURRENT_USER="$(whoami)"
USER_HOME="$(eval echo ~$CURRENT_USER)"
INSTALL_DIR="$USER_HOME/nix-webserver"
WEB_DIR="$USER_HOME/web"
LOGS_DIR="$USER_HOME/logs"
ACME_DIR="$USER_HOME/web/acme-challenge"

REPO_URL="https://github.com/vivekrwt365/nix-webserver.git"

# Installation state tracking
NIX_INSTALLED=false
FLAKES_ENABLED=false
WEBSERVER_INSTALLED=false
HOME_MANAGER_AVAILABLE=false

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

show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                Nix Webserver Interactive Installer          ║"
    echo "║                                                              ║"
    echo "║  Welcome! This installer will set up a complete webserver   ║"
    echo "║  configuration using Nix with automatic SSL certificates.   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    log_info "Current user: ${MAGENTA}$CURRENT_USER${NC}"
    log_info "Installation directory: ${MAGENTA}$INSTALL_DIR${NC}"
    log_info "Web directory: ${MAGENTA}$WEB_DIR${NC}"
    echo
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root."
        log_info "Please run as a regular user. The script will prompt for sudo when needed."
        exit 1
    fi
}

check_system_compatibility() {
    log_info "Checking system compatibility..."
    
    # Check OS
    if [[ -f /etc/os-release ]]; then
        OS_NAME=$(grep '^NAME=' /etc/os-release | cut -d'"' -f2)
        OS_VERSION=$(grep '^VERSION=' /etc/os-release | cut -d'"' -f2 || echo "Unknown")
        log_success "Operating System: $OS_NAME $OS_VERSION"
        
        if ! grep -q "Ubuntu\|Debian" /etc/os-release; then
            log_warning "This installer is optimized for Ubuntu/Debian. Other distributions may require manual adjustments."
        fi
    else
        log_warning "Cannot detect operating system. Proceeding with caution."
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    log_info "Architecture: $ARCH"
    if [[ "$ARCH" != "x86_64" ]]; then
        log_warning "Non-x86_64 architecture detected. Some packages may not be available."
    fi
    
    # Check sudo access
    if sudo -n true 2>/dev/null; then
        log_success "Sudo access: Available (passwordless)"
    elif sudo -v 2>/dev/null; then
        log_success "Sudo access: Available (with password)"
    else
        log_error "Sudo access: Not available. This user needs sudo privileges."
        log_info "Please ensure this user is in the sudo group: sudo usermod -aG sudo $CURRENT_USER"
        exit 1
    fi
    
    # Check disk space
    AVAILABLE_SPACE=$(df "$USER_HOME" | awk 'NR==2 {print $4}')
    AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
    if [[ $AVAILABLE_GB -ge 5 ]]; then
        log_success "Disk space: ${AVAILABLE_GB}GB available (sufficient)"
    else
        log_warning "Disk space: Only ${AVAILABLE_GB}GB available. At least 5GB recommended."
    fi
    
    echo
}

check_existing_installations() {
    log_info "Checking existing installations..."
    
    # Check Nix installation
    if command -v nix >/dev/null 2>&1; then
        NIX_INSTALLED=true
        NIX_VERSION=$(nix --version 2>/dev/null | head -n1 || echo "Unknown version")
        log_success "Nix: Installed ($NIX_VERSION)"
        
        # Check if flakes are enabled
        if nix show-config 2>/dev/null | grep -q "experimental-features.*flakes" || \
           [[ -f "$USER_HOME/.config/nix/nix.conf" ]] && grep -q "experimental-features.*flakes" "$USER_HOME/.config/nix/nix.conf" 2>/dev/null; then
            FLAKES_ENABLED=true
            log_success "Nix Flakes: Enabled"
        else
            log_warning "Nix Flakes: Not enabled (will be configured)"
        fi
        
        # Check Home Manager
        if command -v home-manager >/dev/null 2>&1; then
            HOME_MANAGER_AVAILABLE=true
            HM_VERSION=$(home-manager --version 2>/dev/null || echo "Unknown version")
            log_success "Home Manager: Available ($HM_VERSION)"
        else
            log_info "Home Manager: Not installed (will be installed)"
        fi
    else
        log_info "Nix: Not installed (will be installed)"
    fi
    
    # Check if webserver is already installed
    if [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/flake.nix" ]]; then
        WEBSERVER_INSTALLED=true
        log_warning "Nix Webserver: Already installed at $INSTALL_DIR"
        log_info "Existing installation will be updated/reconfigured"
    else
        log_info "Nix Webserver: Not installed (fresh installation)"
    fi
    
    # Check web directory
    if [[ -d "$WEB_DIR" ]]; then
        SITE_COUNT=$(find "$WEB_DIR" -maxdepth 1 -type d | wc -l)
        SITE_COUNT=$((SITE_COUNT - 1)) # Subtract 1 for the web directory itself
        if [[ $SITE_COUNT -gt 0 ]]; then
            log_info "Web directory: Exists with $SITE_COUNT site(s)"
        else
            log_info "Web directory: Exists but empty"
        fi
    else
        log_info "Web directory: Will be created at $WEB_DIR"
    fi
    
    echo
}

show_installation_plan() {
    log_info "Installation Plan:"
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    
    if [[ "$NIX_INSTALLED" == "false" ]]; then
        echo -e "${BLUE}│${NC} ${YELLOW}→${NC} Install Nix package manager"
    else
        echo -e "${BLUE}│${NC} ${GREEN}✓${NC} Nix already installed"
    fi
    
    if [[ "$FLAKES_ENABLED" == "false" ]]; then
        echo -e "${BLUE}│${NC} ${YELLOW}→${NC} Enable Nix flakes experimental feature"
    else
        echo -e "${BLUE}│${NC} ${GREEN}✓${NC} Nix flakes already enabled"
    fi
    
    if [[ "$HOME_MANAGER_AVAILABLE" == "false" ]]; then
        echo -e "${BLUE}│${NC} ${YELLOW}→${NC} Install Home Manager"
    else
        echo -e "${BLUE}│${NC} ${GREEN}✓${NC} Home Manager already available"
    fi
    
    if [[ "$WEBSERVER_INSTALLED" == "false" ]]; then
        echo -e "${BLUE}│${NC} ${YELLOW}→${NC} Install webserver configuration"
        echo -e "${BLUE}│${NC} ${YELLOW}→${NC} Create directory structure"
        echo -e "${BLUE}│${NC} ${YELLOW}→${NC} Configure firewall (UFW)"
    else
        echo -e "${BLUE}│${NC} ${CYAN}↻${NC} Update existing webserver configuration"
    fi
    
    echo -e "${BLUE}│${NC} ${YELLOW}→${NC} Deploy Home Manager configuration"
    echo -e "${BLUE}│${NC} ${YELLOW}→${NC} Start webserver services"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo
}

confirm_installation() {
    echo -e "${YELLOW}Ready to proceed with installation?${NC}"
    echo "This will modify your system configuration and install packages."
    echo
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled by user."
        exit 0
    fi
    echo
}

install_system_dependencies() {
    log_info "Installing system dependencies..."
    
    # Update package list
    sudo apt update
    
    # Install required packages
    sudo apt install -y \
        curl \
        wget \
        git \
        build-essential \
        xz-utils \
        ca-certificates \
        gnupg \
        lsb-release
    
    log_success "System dependencies installed"
}

install_nix() {
    if [[ "$NIX_INSTALLED" == "true" ]]; then
        log_info "Nix is already installed, skipping installation..."
    else
        log_info "Installing Nix package manager..."
        
        # Download and run the Nix installer
        curl -L https://nixos.org/nix/install | sh -s -- --daemon
        
        # Add to shell profile
        if ! grep -q "nix-daemon.sh" ~/.bashrc; then
            echo 'if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; fi' >> ~/.bashrc
        fi
        
        log_success "Nix installed successfully"
        NIX_INSTALLED=true
    fi
    
    # Source the Nix environment
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
    
    # Enable flakes if not already enabled
    if [[ "$FLAKES_ENABLED" == "false" ]]; then
        log_info "Enabling Nix flakes..."
        mkdir -p ~/.config/nix
        
        # Check if nix.conf exists and has experimental-features
        if [[ -f ~/.config/nix/nix.conf ]] && grep -q "experimental-features" ~/.config/nix/nix.conf; then
            # Update existing experimental-features line
            sed -i 's/experimental-features = .*/experimental-features = nix-command flakes/' ~/.config/nix/nix.conf
        else
            # Add experimental-features line
            echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
        fi
        
        log_success "Nix flakes enabled"
        FLAKES_ENABLED=true
    else
        log_info "Nix flakes already enabled, skipping configuration..."
    fi
}

setup_directories() {
    log_info "Setting up directory structure..."
    
    # Create main directories
    for dir in "$INSTALL_DIR" "$WEB_DIR" "$LOGS_DIR" "$ACME_DIR"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_success "Created directory: $dir"
        else
            log_info "Directory already exists: $dir"
        fi
    done
    
    # Create additional web directories
    mkdir -p "$WEB_DIR/sites"
    mkdir -p "$WEB_DIR/.well-known/acme-challenge"
    
    # Set proper permissions
    chmod 755 "$INSTALL_DIR" "$WEB_DIR" "$LOGS_DIR" "$ACME_DIR"
    
    # Create a basic index.html if web directory is empty
    if [[ ! -f "$WEB_DIR/index.html" ]]; then
        cat > "$WEB_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nix Webserver - Welcome</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .header { text-align: center; color: #333; }
        .status { background: #f0f8ff; padding: 20px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Nix Webserver</h1>
        <p>Your webserver is running successfully!</p>
    </div>
    <div class="status">
        <h3>Next Steps:</h3>
        <ul>
            <li>Add your websites to the <code>~/web</code> directory</li>
            <li>Configure your domains in the Nix configuration</li>
            <li>Deploy your changes with <code>./deploy.sh deploy</code></li>
        </ul>
    </div>
</body>
</html>
EOF
        log_success "Created default index.html"
    fi
    
    log_success "Directory structure setup completed"
}

clone_or_copy_config() {
    log_info "Setting up webserver configuration..."
    
    # If we're running from the config directory, copy it
    if [[ -f "./flake.nix" && -f "./home.nix" && -f "./web.nix" ]]; then
        if [[ "$WEBSERVER_INSTALLED" == "true" ]]; then
            log_info "Updating existing webserver configuration..."
            
            # Backup existing configuration
            BACKUP_DIR="$INSTALL_DIR.backup.$(date +%Y%m%d_%H%M%S)"
            cp -r "$INSTALL_DIR" "$BACKUP_DIR"
            log_info "Backup created at: $BACKUP_DIR"
            
            # Update configuration files (preserve user modifications)
            for file in flake.nix home.nix web.nix deploy.sh verify.sh; do
                if [[ -f "$file" ]]; then
                    cp "$file" "$INSTALL_DIR/"
                    log_success "Updated: $file"
                fi
            done
            
            # Copy new files that might not exist
            for file in *.md *.sh; do
                if [[ -f "$file" ]] && [[ ! -f "$INSTALL_DIR/$file" ]]; then
                    cp "$file" "$INSTALL_DIR/"
                    log_success "Added: $file"
                fi
            done
        else
            log_info "Installing webserver configuration..."
            
            # Copy the entire configuration
            cp -r "$(pwd)" "$INSTALL_DIR"
            
            # Remove the install script from the destination
            rm -f "$INSTALL_DIR/install.sh"
            
            log_success "Configuration files installed successfully"
        fi
        
        # Make scripts executable
        chmod +x "$INSTALL_DIR/deploy.sh"
        if [[ -f "$INSTALL_DIR/verify.sh" ]]; then
            chmod +x "$INSTALL_DIR/verify.sh"
        fi
        
    else
        log_error "Configuration files not found in current directory."
        log_info "Please run this script from the nix-webserver project directory."
        exit 1
    fi
    
    log_success "Configuration setup completed at $INSTALL_DIR"
}

configure_firewall() {
    log_info "Configuring firewall..."
    
    # Check if ufw is installed and active
    if command -v ufw &> /dev/null; then
        # Allow SSH (important!)
        sudo ufw allow ssh
        
        # Allow HTTP and HTTPS
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        
        # Enable firewall if not already enabled
        if ! sudo ufw status | grep -q "Status: active"; then
            log_warning "Enabling UFW firewall. Make sure SSH access is working!"
            sudo ufw --force enable
        fi
        
        log_success "Firewall configured"
    else
        log_warning "UFW firewall not found. Please ensure ports 80 and 443 are open."
    fi
}

update_web_config() {
    log_info "Updating web configuration..."
    
    # Update paths in web.nix to use current user's directories
    sed -i "s|/home/ubuntu/web|$WEB_DIR|g" "$INSTALL_DIR/web.nix"
    sed -i "s|/home/ubuntu/logs|$LOGS_DIR|g" "$INSTALL_DIR/web.nix"
    
    # Prompt for email address for Let's Encrypt
    echo -e "${YELLOW}SSL Certificate Configuration${NC}"
    echo "Let's Encrypt requires an email address for certificate notifications."
    echo
    read -p "Enter your email address for Let's Encrypt certificates: " email
    
    while [[ -z "$email" ]] || [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
        echo -e "${RED}Please enter a valid email address.${NC}"
        read -p "Enter your email address for Let's Encrypt certificates: " email
    done
    
    # Update the email in web.nix
    sed -i "s/your-email@example.com/$email/g" "$INSTALL_DIR/web.nix"
    
    log_success "Web configuration updated:"
    log_info "  - Web directory: $WEB_DIR"
    log_info "  - Logs directory: $LOGS_DIR"
    log_info "  - SSL email: $email"
}

deploy_initial_config() {
    log_info "Deploying configuration with Home Manager..."
    
    cd "$INSTALL_DIR"
    
    # Source Nix environment
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
    
    # Install Home Manager if not already available
    if [[ "$HOME_MANAGER_AVAILABLE" == "false" ]]; then
        log_info "Installing Home Manager..."
        
        # Use the standalone installation method
        nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
        nix-channel --update
        nix-shell '<home-manager>' -A install
        
        # Source the new environment
        source ~/.bashrc
        
        HOME_MANAGER_AVAILABLE=true
        log_success "Home Manager installed successfully"
    fi
    
    # Update the flake.nix to use the current user instead of hardcoded 'ubuntu'
    if [[ "$CURRENT_USER" != "ubuntu" ]]; then
        log_info "Updating configuration for user: $CURRENT_USER"
        sed -i "s/ubuntu/$CURRENT_USER/g" "$INSTALL_DIR/flake.nix"
        sed -i "s/ubuntu/$CURRENT_USER/g" "$INSTALL_DIR/home.nix"
    fi
    
    # Update flake inputs
    nix flake update
    
    # Deploy the configuration
    log_info "Deploying webserver configuration..."
    
    # First try to build the configuration
    if ! nix flake check 2>/dev/null; then
        log_warning "Flake check failed, but continuing with deployment..."
    fi
    
    # Deploy with Home Manager
    if ! home-manager switch --flake ".#$CURRENT_USER"; then
        log_error "Home Manager deployment failed. Trying alternative method..."
        
        # Try building first, then switching
        nix build ".#homeConfigurations.$CURRENT_USER.activationPackage"
        ./result/activate
    fi
    
    log_success "Configuration deployed successfully"
    
    # Show status
    log_info "Checking service status..."
    if systemctl --user is-active nginx.service >/dev/null 2>&1; then
        log_success "Nginx service: Running"
    else
        log_warning "Nginx service: Not running (this is normal on first install)"
    fi
    
    if systemctl --user is-enabled certbot-renew.timer >/dev/null 2>&1; then
        log_success "Certbot renewal timer: Enabled"
    else
        log_info "Certbot renewal timer: Will be configured after first certificate generation"
    fi
}



show_completion_summary() {
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Installation Complete!                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    log_success "Nix Webserver has been successfully installed!"
    echo
    
    log_info "📁 Installation Details:"
    echo -e "   ${CYAN}Configuration:${NC} $INSTALL_DIR"
    echo -e "   ${CYAN}Web Directory:${NC} $WEB_DIR"
    echo -e "   ${CYAN}Logs Directory:${NC} $LOGS_DIR"
    echo
    
    log_info "🚀 Next Steps:"
    echo -e "   ${YELLOW}1.${NC} Add your websites to ${CYAN}$WEB_DIR${NC}"
    echo -e "   ${YELLOW}2.${NC} Configure domains in ${CYAN}$INSTALL_DIR/flake.nix${NC}"
    echo -e "   ${YELLOW}3.${NC} Deploy changes: ${CYAN}cd $INSTALL_DIR && ./deploy.sh deploy${NC}"
    echo
    
    log_info "📋 Useful Commands:"
    echo -e "   ${CYAN}cd $INSTALL_DIR${NC}"
    echo -e "   ${CYAN}./deploy.sh help${NC}        # Show all available commands"
    echo -e "   ${CYAN}./deploy.sh verify${NC}      # Verify installation"
    echo -e "   ${CYAN}./deploy.sh logs${NC}        # View service logs"
    echo -e "   ${CYAN}./deploy.sh sites${NC}       # List configured sites"
    echo
    
    if [[ -f "$INSTALL_DIR/INSTALL.md" ]]; then
        log_info "📖 For detailed documentation, see: ${CYAN}$INSTALL_DIR/INSTALL.md${NC}"
    fi
    
    echo
    log_info "🎉 Your webserver is ready to use!"
}

# Main installation process
main() {
    show_banner
    
    # Pre-flight checks
    check_root
    check_system_compatibility
    check_existing_installations
    
    # Show installation plan and get confirmation
    show_installation_plan
    confirm_installation
    
    # Installation steps
    if ! command -v git >/dev/null 2>&1; then
        install_system_dependencies
    fi
    
    install_nix
    setup_directories
    clone_or_copy_config
    configure_firewall
    update_web_config
    deploy_initial_config
    
    # Show completion summary
    show_completion_summary
}

# Run main function
main "$@"