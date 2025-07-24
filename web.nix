# Nix Webserver - Web Configuration Module
# This module handles Nginx, SSL certificates, and systemd services
{ config, pkgs, lib, sites, ... }:

let
  # --- Assemble all the pieces from the sites ---
  allDomains = lib.map (site: site.siteConfig.domain) sites;
  allNginxServerBlocks = lib.concatStringsSep "\n" (
    lib.map (site: site.siteConfig.nginxServerBlock) sites
  );
  allSystemdServices = lib.foldl' lib.recursiveUpdate {} (
    lib.map (site: site.siteConfig.systemdService) sites
  );

  # Email for Let's Encrypt registration
  email = "your-email@example.com"; # CHANGE THIS TO YOUR EMAIL
in
{
  # --- NGINX CONFIGURATION ---
  home.file.".config/nginx/nginx.conf".text = ''
    worker_processes  1;
    error_log ${config.home.homeDirectory}/.config/nginx/error.log;
    pid ${config.home.homeDirectory}/.config/nginx/nginx.pid;
    events { worker_connections  1024; }
    http {
      access_log ${config.home.homeDirectory}/.config/nginx/access.log;
      include       ${pkgs.nginx}/conf/mime.types;

      # --- HTTP server for ACME challenges and redirects ---
      server {
        listen 80;
        server_name ${lib.concatStringsSep " " allDomains};
        
        # Handle ACME challenges for Let's Encrypt
        location /.well-known/acme-challenge/ {
          root ${config.home.homeDirectory}/web;
          try_files $uri =404;
        }
        
        # Redirect all other HTTP traffic to HTTPS
        location / {
          return 301 https://$server_name$request_uri;
        }
      }

      # --- Default HTTPS server to catch all un-matched requests ---
      server {
        listen 443 ssl default_server;

        # A self-signed certificate just to make the SSL part work
        ssl_certificate ${config.home.homeDirectory}/.config/nginx/dummy.pem;
        ssl_certificate_key ${config.home.homeDirectory}/.config/nginx/dummy.key;

        server_name _; # A placeholder that doesn't match anything real
        return 444; # A special Nginx code that just closes the connection
      }

      # All the server blocks from your sites are inserted here
      ${allNginxServerBlocks}
    }
  '';

  # --- CREATE DUMMY SSL CERTIFICATES FOR DEFAULT SERVER ---
  home.file.".config/nginx/dummy.pem".text = ''
    -----BEGIN CERTIFICATE-----
    MIICljCCAX4CCQDAOxKQdVzuuTANBgkqhkiG9w0BAQsFADCBjTELMAkGA1UEBhMC
    VVMxEDAOBgNVBAgMB1N0YXRlMREwDwYDVQQHDAhDaXR5MRUwEwYDVQQKDAxPcmdh
    bml6YXRpb24xDjAMBgNVBAsMBVVuaXQxDjAMBgNVBAMMBWR1bW15MR4wHAYJKoZI
    hvcNAQkBFg9kdW1teUBleGFtcGxlLmNvbTAeFw0yNTA3MjIyMzIzMTFaFw0yNjA3
    MjIyMzIzMTFaMIGNMQswCQYDVQQGEwJVUzEQMA4GA1UECAwHU3RhdGUxETAPBgNV
    BAcMCENpdHkxFTATBgNVBAoMDE9yZ2FuaXphdGlvbjEOMAwGA1UECwwFVW5pdDEO
    MAwGA1UEAwwFZHVtbXkxHjAcBgkqhkiG9w0BCQEWD2R1bW15QGV4YW1wbGUuY29t
    MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC7vbqajDw4o6gJy8UtqfeY/OQz
    -----END CERTIFICATE-----
  '';

  home.file.".config/nginx/dummy.key".text = ''
    -----BEGIN PRIVATE KEY-----
    MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBALu9upqMPDijqAnL
    xS2p95j85DOVm9Q3CB7L4AjubTeP7lkDByq5C4e6HVxaFNy5O+el+L4/epDrVBHT
    -----END PRIVATE KEY-----
  '';

  # --- SYSTEMD USER SERVICES ---
  systemd.user.services = allSystemdServices // {
    "nginx" = {
      Unit = { Description = "Nginx Proxy"; After = [ "network-online.target" ]; };
      Service = {
        ExecStart = "${pkgs.nginx}/bin/nginx -c %h/.config/nginx/nginx.conf -g 'daemon off;'";
        ExecReload = "${pkgs.nginx}/bin/nginx -s reload";
        Restart = "always";
      };
      Install = { WantedBy = [ "default.target" ]; };
    };
    
    "certbot-renew" = {
      Unit = { Description = "Renew Let's Encrypt certificates"; };
      Service = {
        Type = "oneshot";
        # This command uses the webroot method and reloads nginx on success
        ExecStart = ''
          ${pkgs.certbot}/bin/certbot renew \
            --config-dir %h/.config/letsencrypt \
            --work-dir %h/.config/letsencrypt/work \
            --logs-dir %h/.config/letsencrypt/logs \
            --webroot -w ${config.home.homeDirectory}/web \
            --deploy-hook "systemctl --user reload nginx.service"
        '';
      };
    };
    
    "certbot-initial" = {
      Unit = {
        Description = "Initial Let's Encrypt certificate generation";
        After = [ "network-online.target" "nginx.service" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "certbot-initial" ''
          set -e
          
          # Ensure acme-challenge directory exists and has proper permissions
          mkdir -p ${config.home.homeDirectory}/web/acme-challenge
          mkdir -p ${config.home.homeDirectory}/web/.well-known/acme-challenge
          
          # Generate certificates for all domains using webroot method
          ${lib.concatStringsSep "\n" (lib.map (domain: ''
            echo "Getting certificate for ${domain}"
            ${pkgs.certbot}/bin/certbot certonly --webroot \
              --webroot-path ${config.home.homeDirectory}/web \
              --config-dir ${config.home.homeDirectory}/.config/letsencrypt \
              --work-dir ${config.home.homeDirectory}/.config/letsencrypt/work \
              --logs-dir ${config.home.homeDirectory}/.config/letsencrypt/logs \
              --email ${email} \
              --agree-tos \
              --no-eff-email \
              --force-renewal \
              --domains ${domain} || echo "Failed to get certificate for ${domain}"
          '') allDomains)}
          
          # Reload nginx to use new certificates
          echo "Reloading nginx service..."
          ${pkgs.systemd}/bin/systemctl --user reload nginx.service || true
        '';
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
  
  # --- SYSTEMD TIMER FOR CERTIFICATE RENEWAL ---
  systemd.user.timers."certbot-renew" = {
    Unit = { Description = "Timer for Certbot renewal"; };
    Timer = {
      OnCalendar = "0/12:00:00";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
    Install = { WantedBy = [ "timers.target" ]; };
  };

  # --- CREATE NECESSARY DIRECTORIES ---
  home.file.".config/nginx/.keep".text = "";
  home.file."web/.well-known/acme-challenge/.keep".text = "";
  home.file."web/acme-challenge/.keep".text = "";
}