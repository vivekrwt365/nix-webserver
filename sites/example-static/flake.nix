{
  description = "Example Static Site Template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      domain = "example-static.com"; # CHANGE THIS TO YOUR DOMAIN
    in
    {
      # This is the "interface" our site provides to the orchestrator.
      siteConfig = {
        # 1. The domain name for SSL and Nginx
        inherit domain;

        # 2. The Nginx server block for a static site
        nginxServerBlock = ''
          # Static site server block
          server {
            listen 443 ssl;
            server_name ${domain};
            ssl_certificate /home/ubuntu/.config/letsencrypt/live/${domain}/fullchain.pem;
            ssl_certificate_key /home/ubuntu/.config/letsencrypt/live/${domain}/privkey.pem;

            # The directory where your static files are
            root /home/ubuntu/web/sites/example-static/public;

            # Default file hierarchy to look for
            index index.html index.htm;

            # Handle ACME challenges for Let's Encrypt
            location /.well-known/acme-challenge/ {
              root /home/ubuntu/web/acme-challenge;
            }

            # Handle 404s cleanly for a static site
            location / {
              try_files $uri $uri/ =404;
            }

            # Optional: Enable gzip compression
            gzip on;
            gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
          }
        '';

        # 3. The systemd service to run the application
        # Since this is a static site, there is no app to run.
        systemdService = {};
      };
    };
}