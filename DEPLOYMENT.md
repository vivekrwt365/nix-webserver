# Nix Webserver Deployment Guide

This document provides a complete guide for deploying the Nix webserver configuration on production servers.

## 🚀 Quick Deployment

### For Fresh Ubuntu Server

```bash
# 1. SSH into your server (as any user with sudo privileges)
ssh your-user@your-server-ip

# 2. Run the bootstrap script (works with any user account)
curl -sSL https://raw.githubusercontent.com/yourusername/nix-webserver/main/bootstrap.sh | bash

# 3. Follow the interactive prompts:
#    - User validation and security checks
#    - Email configuration for SSL certificates
#    - Installation plan confirmation

# 4. Verify the installation
cd ~/nix-webserver
./verify.sh
```

## 📋 Pre-Deployment Checklist

### Server Requirements
- [ ] Fresh Ubuntu 20.04 LTS or newer
- [ ] At least 2GB RAM (4GB recommended)
- [ ] 20GB+ disk space
- [ ] Regular user account with sudo privileges (NOT root)
- [ ] Internet connectivity
- [ ] Ports 22, 80, 443 accessible

### DNS Configuration
- [ ] Domain names point to server IP
- [ ] A records configured for all domains
- [ ] TTL set to reasonable value (300-3600 seconds)

### Network Configuration
- [ ] Ports 22 (SSH), 80 (HTTP), 443 (HTTPS) open
- [ ] Firewall configured properly
- [ ] No conflicting services on ports 80/443

## 🛠️ Deployment Process

### Step 1: Server Preparation

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Create a dedicated user if needed (optional)
sudo adduser webserver
sudo usermod -aG sudo webserver

# Switch to your user account (any user with sudo)
sudo su - your-username
```

### Step 2: Download and Install

```bash
# Method 1: Bootstrap script (recommended)
curl -sSL https://raw.githubusercontent.com/yourusername/nix-webserver/main/bootstrap.sh | bash

# Method 2: Manual installation
git clone https://github.com/yourusername/nix-webserver.git
cd nix-webserver
./install.sh
```

### Step 3: Configure Your Sites

```bash
cd ~/nix-webserver

# Copy a site template
cp -r sites/example-static sites/mysite.com

# Edit the domain configuration
nano sites/mysite.com/flake.nix
# Change: domain = "mysite.com";

# Add your site files
mkdir -p ~/web/sites/mysite.com/public
echo "<h1>Hello World!</h1>" > ~/web/sites/mysite.com/public/index.html
```

### Step 4: Update Main Configuration

```bash
# Edit main flake.nix
nano flake.nix
```

Add your site:

```nix
inputs = {
  # ... existing inputs ...
  mysite = {
    url = "path:./sites/mysite.com";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

# In the outputs section:
sites = [
  inputs.mysite
  # ... other sites ...
];
```

### Step 5: Deploy

```bash
# Deploy the configuration
./deploy.sh deploy

# Verify everything is working
./verify.sh

# Check service status
./deploy.sh check
```

## 🔍 Post-Deployment Verification

### Automated Verification

```bash
# Run comprehensive verification
./verify.sh

# Check specific services
./deploy.sh check

# Test site connectivity
./deploy.sh test-sites
```

### Manual Verification

```bash
# Test HTTP redirect
curl -I http://yourdomain.com
# Should return 301 redirect to HTTPS

# Test HTTPS
curl -I https://yourdomain.com
# Should return 200 OK

# Check SSL certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com

# Verify certificate auto-renewal
systemctl --user status certbot-renewal.timer
```

## 📊 Monitoring and Maintenance

### Service Monitoring

```bash
# Check all services
systemctl --user list-units --type=service --state=running

# Monitor logs in real-time
journalctl --user -f

# Check specific service logs
./deploy.sh logs nginx.service
./deploy.sh logs certbot-renewal.service
```

### Certificate Management

```bash
# Check certificate status
certbot certificates --config-dir ~/.config/letsencrypt

# Manual certificate renewal (if needed)
systemctl --user start certbot-renewal.service

# Check renewal timer
systemctl --user status certbot-renewal.timer
```

### System Updates

```bash
# Update Nix packages
cd /home/ubuntu/nix-webserver
nix flake update
./deploy.sh deploy

# Update system packages
sudo apt update && sudo apt upgrade -y
```

## 🔧 Configuration Management

### Adding New Sites

1. **Copy Template**
   ```bash
   cp -r sites/example-static sites/newsite.com
   ```

2. **Configure Domain**
   ```bash
   nano sites/newsite.com/flake.nix
   # Update domain = "newsite.com";
   ```

3. **Add to Main Config**
   ```bash
   nano flake.nix
   # Add input and to sites list
   ```

4. **Deploy**
   ```bash
   ./deploy.sh deploy
   ```

### Updating Existing Sites

1. **Update Site Files**
   ```bash
   # Update files in ~/web/sites/yoursite.com/
   ```

2. **Update Configuration (if needed)**
   ```bash
   nano sites/yoursite.com/flake.nix
   ```

3. **Redeploy**
   ```bash
   ./deploy.sh deploy
   ```

### Removing Sites

1. **Remove from Main Config**
   ```bash
   nano flake.nix
   # Remove from inputs and sites list
   ```

2. **Deploy Changes**
   ```bash
   ./deploy.sh deploy
   ```

3. **Clean Up Files**
   ```bash
   rm -rf sites/oldsite.com
   rm -rf ~/web/sites/oldsite.com
   ```

## 🚨 Troubleshooting

### Common Issues

**SSL Certificate Generation Fails**
```bash
# Check DNS
nslookup yourdomain.com

# Check ACME challenge directory
ls -la /home/ubuntu/web/.well-known/acme-challenge/

# Check certbot logs
journalctl --user -u certbot-initial.service

# Manual certificate generation
certbot certonly --webroot -w /home/ubuntu/web --email your@email.com -d yourdomain.com
```

**Nginx Configuration Errors**
```bash
# Test configuration
nginx -t -c ~/.config/nginx/nginx.conf

# Check for syntax errors
./deploy.sh test

# Reload configuration
systemctl --user reload nginx.service
```

**Service Won't Start**
```bash
# Check service status
systemctl --user status service-name

# View detailed logs
journalctl --user -u service-name --no-pager

# Restart service
systemctl --user restart service-name
```

**Port Conflicts**
```bash
# Check what's using ports 80/443
sudo ss -tlnp | grep ':80\|:443'

# Stop conflicting services
sudo systemctl stop apache2  # if Apache is running
sudo systemctl disable apache2
```

### Recovery Procedures

**Rollback Configuration**
```bash
# List Home Manager generations
home-manager generations

# Rollback to previous generation
home-manager switch --rollback
```

**Reset to Clean State**
```bash
# Stop all services
systemctl --user stop nginx.service
systemctl --user stop certbot-renewal.timer

# Remove configuration
rm -rf ~/.config/nginx
rm -rf ~/.config/letsencrypt

# Redeploy
./deploy.sh deploy
```

## 📈 Performance Optimization

### Nginx Tuning

```bash
# Edit web.nix for performance settings
nano web.nix
```

Add to nginx.conf:
```nginx
worker_processes auto;
worker_connections 2048;
keepalive_timeout 65;
gzip on;
gzip_comp_level 6;
```

### System Monitoring

```bash
# Monitor system resources
htop

# Check disk usage
df -h

# Monitor network connections
ss -tuln
```

## 🔒 Security Hardening

### Firewall Configuration

```bash
# Check current rules
sudo ufw status verbose

# Limit SSH connections
sudo ufw limit ssh

# Enable logging
sudo ufw logging on
```

### SSL Security

```bash
# Test SSL configuration
ssl-labs.com  # Online SSL test

# Check certificate expiry
openssl x509 -in ~/.config/letsencrypt/live/yourdomain.com/cert.pem -text -noout | grep "Not After"
```

### System Security

```bash
# Update system regularly
sudo apt update && sudo apt upgrade -y

# Check for security updates
sudo unattended-upgrades --dry-run

# Monitor auth logs
sudo tail -f /var/log/auth.log
```

## 📚 Additional Resources

- [README.md](README.md) - User documentation
- [INSTALL.md](INSTALL.md) - Installation guide
- [CONTEXT.md](CONTEXT.md) - Technical architecture
- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

---

**Happy deploying! 🚀**