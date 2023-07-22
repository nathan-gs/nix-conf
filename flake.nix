{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    secrets.url = "git+file:///etc/nixos/secrets";
  };
  

  outputs = { self, nixpkgs, nixpkgs-unstable, secrets, ... }:
    let 
      unstableOverlay = final: prev: { nixpkgs-unstable = nixpkgs-unstable.legacyPackages.${prev.system}; };
      unstableModule = ({ config, pkgs, ...}: { nixpkgs.overlays = [ unstableOverlay ]; });

    in 
      {  
    
        nixosConfigurations.nhtpc = nixpkgs.lib.nixosSystem {
          modules = [
            # Point this to your original configuration.
            ./computers/nhtpc.nix
            secrets.nixosModules.secrets
            unstableModule
          ];

      
          # Select the target system here.
          system = "x86_64-linux";
        };
  

        nixosConfigurations.nnas = nixpkgs.lib.nixosSystem {
          modules = [
            # Point this to your original configuration.
            ./computers/nnas.nix
            secrets.nixosModules.secrets
          ];

      
          # Select the target system here.
          system = "x86_64-linux";
       };
    };
  }


