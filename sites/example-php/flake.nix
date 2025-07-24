{
  description = "Example PHP Application Template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      php = pkgs.php82;
      domain = "example-php.com"; # CHANGE THIS TO YOUR DOMAIN
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
            root /home/ubuntu/web/sites/example-php/public;
            index index.php index.html;

            # Handle ACME challenges for Let's Encrypt
            location /.well-known/acme-challenge/ {
              root /home/ubuntu/web/acme-challenge;
            }

            # PHP processing
            location ~ \.php$ {
              include ${pkgs.nginx}/conf/fastcgi_params;

              # FastCGI parameters
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              fastcgi_param QUERY_STRING $query_string;
              fastcgi_param REQUEST_METHOD $request_method;
              fastcgi_param CONTENT_TYPE $content_type;
              fastcgi_param CONTENT_LENGTH $content_length;
              fastcgi_param SCRIPT_NAME $fastcgi_script_name;
              fastcgi_param REQUEST_URI $request_uri;
              fastcgi_param DOCUMENT_URI $document_uri;
              fastcgi_param DOCUMENT_ROOT $document_root;
              fastcgi_param SERVER_PROTOCOL $server_protocol;
              fastcgi_param REMOTE_ADDR $remote_addr;
              fastcgi_param REMOTE_PORT $remote_port;
              fastcgi_param SERVER_ADDR $server_addr;
              fastcgi_param SERVER_PORT $server_port;
              fastcgi_param SERVER_NAME $server_name;
              fastcgi_param HTTPS 'on';

              fastcgi_pass unix:/tmp/php-example.sock;
            }

            # Static files
            location / {
              try_files $uri $uri/ /index.php?$query_string;
            }
          }
        '';

        systemdService = {
          "php-example-app" = {
            Unit = { Description = "PHP FPM Service for Example App"; };
            Service = {
              # Create logs directory if it doesn't exist
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/ubuntu/logs";
              # Start PHP-FPM with custom config
              ExecStart = "${php}/bin/php-fpm --fpm-config ${./php-fpm.conf}";
              Restart = "always";
            };
            Install = { WantedBy = [ "default.target" ]; };
          };
        };
      };
    };
}