{
  description = "Nix Webserver - A modular VPS orchestrator for web applications";

  # --- SINGLE POINT OF CONTROL FOR ALL SITES ---
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";

    #--- TO ADD SITES, ADD YOUR SITE FLAKE PATHS HERE ---
    
    # Example Website 1 (Static Site)
    # exampleStatic = {
    #   url = "path:./sites/example-static";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    
    # Example Website 2 (PHP Application)
    # examplePhp = {
    #   url = "path:./sites/example-php";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    
    #----
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # --- Create a list of all site flakes ---
      # Add new sites to this list when you uncomment them above
      sites = [
        # inputs.exampleStatic
        # inputs.examplePhp
      ];
    in
    {
      homeConfigurations."ubuntu" = home-manager.lib.homeManagerConfiguration { # This will be updated by install script
        inherit pkgs;
        extraSpecialArgs = { inherit sites; };
        modules = [ ./home.nix ];
      };
    };
}