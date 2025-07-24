{ config, pkgs, sites, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage.
  home.username = "ubuntu";
  home.homeDirectory = "/home/ubuntu";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "23.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Import the web configuration module
  imports = [
    ./web.nix
  ];

  # Basic packages that might be useful for web server management
  home.packages = with pkgs; [
    curl
    wget
    htop
    tree
    git
    vim
    nano
    openssl
    certbot
  ];

  # Basic shell configuration
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      # Useful aliases for web server management
      alias nginx-status="systemctl --user status nginx.service"
      alias nginx-restart="systemctl --user restart nginx.service"
      alias nginx-reload="systemctl --user reload nginx.service"
      alias nginx-logs="journalctl --user -u nginx.service -f"
      alias cert-status="systemctl --user status certbot-initial.service"
      alias cert-logs="journalctl --user -u certbot-initial.service"
      alias hm-switch="nix run home-manager/master -- switch --flake ."
      
      # Show current configuration status
      echo "Nix Webserver Environment Loaded"
      echo "Available commands: nginx-status, nginx-restart, nginx-reload, nginx-logs"
      echo "Certificate commands: cert-status, cert-logs"
      echo "Deploy command: hm-switch"
    '';
  };
}