# The "Why?"
I was frustrated with the various deployment methods for web applications written in different languages and wanted a simple, consistent way to deploy my web apps. I found Nix to be helpful in managing different versions of the same language and its extensions, while maintaining consistency in deployment. It's a straightforward way to deploy any web application without using many resources. I plan to make it more robust and add more features in the future, such as automatic re-deployment of web apps and a web-based UI to control deployment states. But for now, you can host any application "manually only" using Nix configurations to build its environment.
### Feel free report any bugs or issues with the code and best practices. OR send a pull request if you want to add more features or improve the existing ones.

# Nix Webserver Template
A complete, production-ready web server configuration using Nginx + Nix and Home Manager for deploying multiple websites with automatic SSL certificate management.

## Features

- **Declarative Configuration**: Everything defined in Nix flakes
- **Automatic SSL**: Let's Encrypt certificate generation and renewal
- **Multi-Site Support**: Host multiple domains on a single server
- **Nginx Reverse Proxy**: High-performance web server with SSL termination
- **Systemd Integration**: Proper service management and logging
- **Template Examples**: Ready-to-use templates for different application types
- **Zero-Downtime Deployments**: Atomic configuration updates

## Project Structure

```
nix-webserver/
├── flake.nix              # Main flake with inputs and site orchestration
├── home.nix               # Home Manager configuration
├── web.nix                # Nginx and SSL certificate management
├── sites/                 # Site-specific configurations
│   ├── example-static/    # Static site template
│   ├── example-php/       # PHP application template
│   └── example-nodejs/    # Node.js application template
└── README.md              # This file
```

## Quick Start

### Fresh Server Installation

For a completely fresh Ubuntu/Debian server, you can install everything with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/vivekrwt365/nix-webserver/main/bootstrap.sh | bash
```

**Features of the Interactive Installer:**
- 🔍 **Smart Detection**: Automatically detects existing Nix, Home Manager, and webserver installations
- 👤 **Any User**: Works with any user account (not just 'ubuntu')
- 🛡️ **Safe Updates**: Backs up existing configurations before updating
- 📋 **Compatibility Checks**: Verifies system requirements and sudo access
- 🎯 **User-Friendly**: Interactive prompts with clear installation plans
- 📁 **Clean Structure**: Installs to `~/nix-webserver` and uses `~/web` for websites

**What it does:**
- Installs Nix package manager (if not present)
- Enables Nix flakes (if not enabled)
- Installs Home Manager (if not available)
- Sets up webserver configuration with SSL certificates
- Configures firewall rules (UFW)
- Creates directory structure and default files

For detailed installation instructions and troubleshooting, see [INSTALL.md](INSTALL.md).

### Manual Setup (if Nix is already installed)

#### Prerequisites

- NixOS or Nix package manager installed
- Home Manager installed
- Domain names pointing to your server
- Ports 80 and 443 open in firewall

#### 1. Clone and Setup

```bash
# Clone this repository
git clone <your-repo-url> ~/nix-webserver
cd ~/nix-webserver

# Create web directories
mkdir -p ~/web/sites
mkdir -p ~/web/acme-challenge
mkdir -p ~/logs
```

#### 2. Configure Your Sites

Copy one of the example templates and customize it:

```bash
# For a static site
cp -r sites/example-static sites/mysite.com
# Edit sites/mysite.com/flake.nix and change the domain

# For a PHP application
cp -r sites/example-php sites/myapp.com
# Edit sites/myapp.com/flake.nix and change the domain

# For a Node.js application
cp -r sites/example-nodejs sites/myapi.com
# Edit sites/myapi.com/flake.nix and change the domain
```

#### 3. Add Sites to Main Configuration

Edit `flake.nix` and add your site as an input:

```nix
inputs = {
  # ... existing inputs ...
  mysite = {
    url = "path:~/nix-webserver/sites/mysite.com";
    flake = false;
  };
};
```

Then add it to the sites list in the outputs:

```nix
sites = [
  # ... existing sites ...
  (import inputs.mysite).siteConfig
];
```

#### 4. Deploy

```bash
# Update flake inputs
nix flake update

# Deploy the configuration
nix run home-manager/master -- switch --flake .

# Check services
systemctl --user status nginx.service
systemctl --user status certbot-renewal.timer
```

## 📋 Site Templates

### Static Site Template

**Location**: `sites/example-static/`

- Serves static HTML, CSS, JS files
- Nginx configuration with gzip compression
- Automatic SSL certificate management
- Perfect for documentation, landing pages, SPAs

**Usage**:
1. Copy the template
2. Update domain in `flake.nix`
3. Add your static files to `public/`
4. Deploy

### PHP Application Template

**Location**: `sites/example-php/`

- PHP-FPM with Unix socket
- Nginx FastCGI configuration
- Process management and logging
- Environment variable support

**Features**:
- PHP 8.2 runtime
- Custom PHP-FPM pool configuration
- Error and access logging
- Security headers

### Node.js Application Template

**Location**: `sites/example-nodejs/`

- Express.js web framework
- Nginx reverse proxy
- Process management with systemd
- API endpoints and static file serving

**Features**:
- Node.js 20 runtime
- Security middleware (Helmet, CORS)
- JSON API endpoints
- Graceful shutdown handling
- Health check endpoint

## 🔧 Configuration

### Adding a New Site

1. **Create site directory**:
   ```bash
   mkdir -p sites/yoursite.com
   ```

2. **Create flake.nix**:
   ```nix
   {
     description = "Your Site";
     inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
     outputs = { self, nixpkgs }:
       let
         domain = "yoursite.com";
       in {
         siteConfig = {
           inherit domain;
           nginxServerBlock = ''/* your nginx config */'';
           systemdService = {/* your services */};
         };
       };
   }
   ```

3. **Add to main flake.nix**:
   - Add as input
   - Include in sites list

4. **Deploy**:
   ```bash
   nix flake update && nix run home-manager/master -- switch --flake .
   ```

### SSL Certificate Management

Certificates are automatically:
- Generated on first deployment
- Renewed every 12 hours via systemd timer
- Stored in `~/.config/letsencrypt/`

### Nginx Configuration

The system automatically generates:
- HTTP server for ACME challenges and HTTPS redirects
- HTTPS servers for each site
- SSL configuration with modern ciphers
- Security headers

## 📊 Monitoring and Logs

### Service Status
```bash
# Check all services
systemctl --user status nginx.service
systemctl --user status certbot-renewal.timer
systemctl --user list-units --type=service

# Check specific site service
systemctl --user status myapp-service
```

### Logs
```bash
# Nginx logs
journalctl --user -u nginx.service -f

# Application logs
tail -f ~/logs/myapp.log

# Certificate renewal logs
journalctl --user -u certbot-renewal.service -f
```

### Useful Aliases

The configuration includes helpful aliases:
- `hm-switch`: Deploy configuration changes
- `nginx-reload`: Reload Nginx configuration
- `nginx-test`: Test Nginx configuration
- `cert-renew`: Manually renew certificates

## 🔒 Security

- **SSL/TLS**: Modern cipher suites and protocols
- **Headers**: Security headers (HSTS, CSP, etc.)
- Isolation: Each service runs as the current user
- **Firewall**: Only ports 80 and 443 exposed
- **Updates**: Regular Nix package updates

## 🚀 Deployment Workflow

1. **Development**: Test changes locally
2. **Staging**: Deploy to staging environment
3. **Production**: Deploy with `hm-switch`
4. **Monitoring**: Check logs and service status
5. **Rollback**: Use Nix generations if needed

### Rollback
```bash
# List generations
home-manager generations

# Rollback to previous generation
home-manager switch --flake . --rollback
```

## 📚 Advanced Usage

### Custom Nginx Configuration

Add custom Nginx directives in your site's `nginxServerBlock`:

```nix
nginxServerBlock = ''
  server {
    listen 443 ssl;
    server_name example.com;
    
    # Custom rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    
    location /api/ {
      limit_req zone=api burst=20 nodelay;
      proxy_pass http://127.0.0.1:3000;
    }
  }
'';
```

### Environment Variables

Pass environment variables to your services:

```nix
systemdService = {
  "myapp" = {
    Service = {
      Environment = [
        "NODE_ENV=production"
        "DATABASE_URL=postgresql://..."
        "API_KEY_FILE=/run/secrets/api-key"
      ];
    };
  };
};
```

### Database Integration

For applications requiring databases, consider:
- Using external managed databases
- Adding PostgreSQL/MySQL services to systemd
- Using Docker containers for complex setups

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Troubleshooting

### Common Issues

**Certificate generation fails**:
- Check domain DNS points to server
- Verify ports 80/443 are open
- Check `/home/ubuntu/logs/certbot.log`

**Nginx fails to start**:
- Test configuration: `nginx-test`
- Check for port conflicts
- Verify certificate paths exist

**Service won't start**:
- Check systemd logs: `journalctl --user -u service-name`
- Verify file permissions
- Check working directory exists

**Site not accessible**:
- Verify DNS configuration
- Check firewall rules
- Test with `curl -v https://yoursite.com`

### Getting Help

- Check the logs first
- Review the example templates
- Test with minimal configuration
- Ask in Nix community forums

---

**Happy deploying! 🎉**