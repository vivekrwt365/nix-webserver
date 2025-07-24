{
  description = "Example Node.js Application Template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      nodejs = pkgs.nodejs_20;
      domain = "example-nodejs.com"; # CHANGE THIS TO YOUR DOMAIN
      port = "3000"; # Internal port for the Node.js app
    in
    {
      siteConfig = {
        inherit domain;
        nginxServerBlock = ''
          server {
            listen 443 ssl;
            server_name ${domain};
            ssl_certificate /home/ubuntu/.config/letsencrypt/live/${domain}/fullchain.pem;
            ssl_certificate_key /home/ubuntu/.config/letsencrypt/live/${domain}/privkey.pem;

            # Handle ACME challenges for Let's Encrypt
            location /.well-known/acme-challenge/ {
              root /home/ubuntu/web/acme-challenge;
            }

            # Proxy to Node.js application
            location / {
              proxy_pass http://127.0.0.1:${port};
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection 'upgrade';
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_cache_bypass $http_upgrade;
              proxy_read_timeout 86400;
            }
          }
        '';

        systemdService = {
          "nodejs-example-app" = {
            Unit = {
              Description = "Node.js Example Application";
              After = [ "network.target" ];
            };
            Service = {
              Type = "simple";
              User = "ubuntu";
              WorkingDirectory = "/home/ubuntu/web/sites/example-nodejs";
              Environment = [
                "NODE_ENV=production"
                "PORT=${port}"
                "HOST=127.0.0.1"
              ];
              # Install dependencies and start the app
              ExecStartPre = [
                "${pkgs.coreutils}/bin/mkdir -p /home/ubuntu/logs"
                "${nodejs}/bin/npm install"
              ];
              ExecStart = "${nodejs}/bin/node server.js";
              Restart = "always";
              RestartSec = "10";
              StandardOutput = "append:/home/ubuntu/logs/nodejs-example.log";
              StandardError = "append:/home/ubuntu/logs/nodejs-example-error.log";
            };
            Install = { WantedBy = [ "default.target" ]; };
          };
        };
      };
    };
}