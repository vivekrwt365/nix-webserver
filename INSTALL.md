# Nix Webserver Installation Guide

This guide provides detailed instructions for installing the Nix webserver configuration on Ubuntu/Debian servers using any user account.

## 🚀 Quick Start (Recommended)

### Interactive One-Line Installation

For the fastest setup, use our interactive bootstrap script:

```bash
# Run as any user with sudo privileges (NOT as root)
curl -sSL https://raw.githubusercontent.com/vivekrwt365/nix-webserver/main/bootstrap.sh | bash
```

**Features of the Interactive Installer:**
- 🔍 **Smart Detection**: Checks for existing Nix, Home Manager, and webserver installations
- 👤 **Flexible User Support**: Works with any user account, not just 'ubuntu'
- 🛡️ **Safe Updates**: Creates backups before updating existing installations
- 📋 **System Validation**: Verifies OS compatibility, sudo access, and disk space
- 🎯 **Clear Communication**: Shows installation plan and asks for confirmation
- 📁 **Organized Structure**: Uses `~/nix-webserver` for config and `~/web` for websites

**Note**: Replace `yourusername/nix-webserver` with your actual repository URL.

### Method 2: Manual Download and Install

```bash
# Download the bootstrap script
wget https://raw.githubusercontent.com/yourusername/nix-webserver/main/bootstrap.sh

# Make it executable and run
chmod +x bootstrap.sh
./bootstrap.sh
```

## 📋 Prerequisites

Before installing, ensure you have:

### System Requirements
- **Operating System**: Ubuntu 18.04+ or Debian 10+ (other distributions may work but are untested)
- **User Account**: Any regular user account with sudo privileges (NOT root)
- **Sudo Access**: The user must be able to run `sudo` commands
- **Internet Connection**: Required for downloading packages and Nix store
- **Disk Space**: At least 5GB free space (Nix store can grow large)
- **Memory**: Minimum 1GB RAM (2GB recommended for building)

### User Account Setup
The installer works with any user account. If you need to create a dedicated user:

```bash
# Create a new user (optional)
sudo useradd -m -s /bin/bash webserver
sudo usermod -aG sudo webserver

# Switch to the user
sudo su - webserver
```

### Network Requirements
- **Ports 80 and 443**: Must be available for HTTP/HTTPS traffic
- **Domain names**: You'll need domain names pointing to your server's IP address
- **Email Address**: Required for Let's Encrypt SSL certificate registration

## 🛠️ Manual Installation

If you prefer to install manually or the bootstrap script doesn't work:

### Step 1: Prepare the System

```bash
# Update system packages (requires sudo)
sudo apt update && sudo apt upgrade -y

# Install required dependencies
sudo apt install -y curl git xz-utils build-essential ca-certificates
```

### Step 2: Install Nix (if not already installed)

```bash
# Install Nix package manager
curl -L https://nixos.org/nix/install | sh -s -- --daemon

# Source the Nix environment
source ~/.bashrc

# Enable flakes (if not already enabled)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Step 3: Download Configuration

```bash
# Clone the repository to your home directory
git clone https://github.com/vivekrwt365/nix-webserver.git ~/nix-webserver
cd ~/nix-webserver
```

### Step 4: Run the Interactive Installer

```bash
# Make the installer executable
chmod +x install.sh

# Run the interactive installer
./install.sh
```

The installer will:
- Detect your current user and set up paths accordingly
- Check for existing installations and offer to update them
- Guide you through SSL certificate email configuration
- Set up the directory structure in your home directory
- Deploy the Home Manager configuration

## 🔧 What the Installation Does

The installation script will:

1. **System Compatibility Check**
   - Verifies operating system (Ubuntu/Debian preferred)
   - Checks user permissions and sudo access
   - Validates available disk space and system resources
   - Detects existing Nix, Home Manager, and webserver installations

2. **Install System Dependencies** (if needed)
   - Updates package lists
   - Installs git, curl, build tools, and other required packages

3. **Install/Configure Nix Package Manager**
   - Downloads and installs Nix (if not present)
   - Configures Nix daemon for multi-user installation
   - Enables experimental features (flakes and nix-command)
   - Sources Nix environment in shell profile

4. **Set Up Directory Structure**
   - Creates `~/nix-webserver` for configuration files
   - Creates `~/web` for website files and content
   - Creates `~/logs` for service logs
   - Sets up SSL certificate directories (`~/web/.well-known/acme-challenge`)
   - Creates default welcome page

5. **Configure Webserver**
   - Copies/updates configuration files with dynamic user paths
   - Updates flake.nix and home.nix to use current username
   - Prompts for Let's Encrypt email configuration
   - Sets up Nginx with SSL support and automatic redirects
   - Configures automatic certificate renewal with Certbot

6. **Install/Configure Home Manager**
   - Installs Home Manager (if not available)
   - Updates flake inputs to latest versions
   - Deploys the webserver configuration for current user
   - Starts necessary systemd user services

7. **Configure Firewall**
   - Enables UFW (Uncomplicated Firewall)
   - Opens ports 22 (SSH), 80 (HTTP), and 443 (HTTPS)
   - Configures basic security rules

## 📁 Post-Installation Structure

After installation, your home directory will have the following structure:

```
~/                          # Your home directory
├── nix-webserver/          # Main configuration directory
│   ├── flake.nix           # Main Nix flake configuration
│   ├── home.nix            # Home Manager configuration  
│   ├── web.nix             # Web server configuration
│   ├── deploy.sh           # Deployment and management script
│   ├── verify.sh           # Installation verification script
│   ├── INSTALL.md          # Installation documentation
│   ├── DEPLOYMENT.md       # Deployment guide
│   └── sites/              # Site templates and examples
│       ├── example-static/ # Static site example
│       └── example-nodejs/ # Node.js app example
├── web/                    # Website files directory
│   ├── index.html          # Default welcome page
│   ├── .well-known/        # ACME challenge directory
│   └── sites/              # Individual site directories (created as needed)
└── logs/                   # Service logs directory
```

**Key Directories:**
- **`~/nix-webserver/`**: Contains all configuration files and management scripts
- **`~/web/`**: Your web root directory where you place website files
- **`~/logs/`**: Contains service logs for debugging and monitoring

## 🌐 Adding Your First Website

### Step 1: Create Your Website Content

```bash
# Create a directory for your website in ~/web
mkdir -p ~/web/mysite.com
cd ~/web/mysite.com

# Add your website files
echo "<h1>Welcome to My Website!</h1>" > index.html
```

### Step 2: Choose and Configure a Template

```bash
cd ~/nix-webserver

# For a static website
cp -r sites/example-static sites/mysite.com

# For a PHP application
cp -r sites/example-php sites/myapp.com

# For a Node.js application
cp -r sites/example-nodejs sites/myapi.com
```

### Step 3: Configure Your Site

```bash
# Edit the site configuration
nano sites/mysite.com/flake.nix

# Change the domain name:
# domain = "mysite.com";  # Change this to your actual domain
```

### Step 4: Add Site to Main Configuration

```bash
# Edit the main flake.nix
nano flake.nix
```

Add your site as an input:

```nix
inputs = {
  # ... existing inputs ...
  mysite = {
    url = "path:./sites/mysite.com";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

And add it to the sites list:

```nix
sites = [
  inputs.mysite
  # ... other sites ...
];
```

### Step 5: Deploy Your Site

```bash
# Deploy the changes
./deploy.sh deploy

# Check that everything is working
./deploy.sh check
```

**Note**: Make sure your domain's DNS A record points to your server's IP address before deploying.

## 🔍 Troubleshooting

### Quick Verification

First, run the built-in verification script:

```bash
cd ~/nix-webserver
./verify.sh
```

This will check your installation and highlight any issues.

### Common Issues

**1. Nix installation fails**
```bash
# Check if running as current user (not root)
whoami

# Check if Nix is properly installed
command -v nix

# Check if flakes are enabled
nix show-config | grep experimental-features

# Reload Nix environment
source ~/.bashrc
```

**2. Home Manager issues**
```bash
# Check Home Manager installation
command -v home-manager

# Try rebuilding the configuration
cd ~/nix-webserver
home-manager switch --flake ".#$(whoami)"
```

**3. SSL certificates fail to generate**
```bash
# Check DNS configuration
nslookup yourdomain.com

# Check firewall
sudo ufw status

# Check ACME challenge directory
ls -la ~/web/.well-known/acme-challenge/

# Check logs
journalctl --user -u certbot-initial.service
```

**4. Nginx fails to start**
```bash
# Test configuration
nginx -t -c ~/.config/nginx/nginx.conf

# Check service status
systemctl --user status nginx.service

# View logs
journalctl --user -u nginx.service

# Restart service
systemctl --user restart nginx.service
```

**5. Site not accessible**
```bash
# Test locally
curl -v http://localhost

# Check if domain points to server
dig yourdomain.com

# Test SSL
curl -v https://yourdomain.com

# Check if ports are listening
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

### Useful Commands

```bash
# Check all services
./deploy.sh check

# View logs
./deploy.sh logs nginx.service

# List configured sites
./deploy.sh sites

# Test site connectivity
./deploy.sh test-sites

# Restart a service
systemctl --user restart nginx.service

# Reload Nginx configuration
systemctl --user reload nginx.service
```

## 🔒 Security Considerations

- **Firewall**: Only ports 22 (SSH), 80 (HTTP), and 443 (HTTPS) should be open
- **SSL**: All sites automatically get Let's Encrypt certificates
- **Updates**: Regularly update the system and Nix packages
- **Monitoring**: Check logs regularly for any issues

## 📚 Next Steps

1. **Add your websites** using the site templates
2. **Configure DNS** to point your domains to the server
3. **Set up monitoring** for your applications
4. **Configure backups** for your data
5. **Set up CI/CD** for automated deployments

## 🔧 Management Commands

After installation, you can manage your webserver:

```bash
# Navigate to your installation directory
cd ~/nix-webserver

# Deploy changes
./deploy.sh deploy

# Check status
./deploy.sh status

# View logs
./deploy.sh logs

# Restart services
./deploy.sh restart

# Verify installation
./verify.sh
```

## 🔒 Security Notes

- The installation works with any regular user account (no special user creation required)
- SSL certificates are automatically managed by Let's Encrypt
- Nginx is configured with security headers
- The firewall is configured to allow only necessary ports (22, 80, 443)
- All services run in user space (no root privileges required for operation)
- Installation directories are contained within the user's home directory

## 📁 Directory Structure Summary

After installation, your directories will be organized as:

```
~/
├── nix-webserver/          # Main configuration and scripts
│   ├── flake.nix           # Nix flake configuration
│   ├── home.nix            # Home Manager configuration
│   ├── web.nix             # Webserver configuration
│   ├── deploy.sh           # Deployment script
│   ├── verify.sh           # Verification script
│   └── sites/              # Website templates
├── web/                    # Your website files
│   └── index.html          # Default welcome page
└── logs/                   # Nginx and system logs
    ├── nginx/              # Nginx access and error logs
    └── acme/               # SSL certificate logs
```

## 📋 Next Steps

1. **Configure your domain's DNS** to point to your server's IP address
2. **Add your first website** using the templates in the `~/nix-webserver/sites/` directory
3. **Customize the configuration** in `web.nix` for your specific needs
4. **Set up monitoring** by checking the logs regularly with `./deploy.sh logs`
5. **Keep the system updated** by running `./deploy.sh deploy` periodically
6. **Verify your setup** anytime with `./verify.sh`

For more detailed configuration options, see the main [README.md](README.md).

## 🆘 Getting Help

- Check the main [README.md](README.md) for detailed usage instructions
- Review the [CONTEXT.md](CONTEXT.md) for technical architecture details
- Check logs with `./deploy.sh logs <service-name>`
- Test configuration with `./deploy.sh test`

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Happy hosting! 🎉**