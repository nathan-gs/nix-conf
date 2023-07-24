{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    secrets.url = "git+file:///etc/nixos/secrets";
    photoprism-slideshow.url = "github:nathan-gs/photoprism-slideshow";
  };
  

  outputs = { self, nixpkgs, nixpkgs-unstable, secrets, photoprism-slideshow, ... }:
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
            photoprism-slideshow.nixosModules.photoprism-slideshow
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


