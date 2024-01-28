{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    secrets.url = "git+file:///etc/nixos/secrets";
    photoprism-slideshow.url = "github:nathan-gs/photoprism-slideshow";
  };


  outputs = { self, nixpkgs, nixpkgs-unstable, secrets, photoprism-slideshow, ... }:
    let
      overlay = final: prev: { nixpkgs-unstable = nixpkgs-unstable.legacyPackages.${prev.system}; };
      overlayModule = ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay ]; });

    in
    {

      nixosConfigurations = {
        nhtpc = nixpkgs.lib.nixosSystem {
          modules = [
            # Point this to your original configuration.
            ./computers/nhtpc.nix
            secrets.nixosModules.secrets
            photoprism-slideshow.nixosModules.photoprism-slideshow
            overlayModule
          ];

          specialArgs.channels = { inherit nixpkgs nixpkgs-unstable; };

          # Select the target system here.
          system = "x86_64-linux";
        };

        ngo = nixpkgs.lib.nixosSystem {
          modules = [
            # Point this to your original configuration.
            ./computers/ngo.nix
            secrets.nixosModules.secrets
            overlayModule
          ];

          specialArgs.channels = { inherit nixpkgs nixpkgs-unstable; };

          # Select the target system here.
          system = "x86_64-linux";
        };


        nnas = nixpkgs.lib.nixosSystem {
          modules = [
            # Point this to your original configuration.
            ./computers/nnas.nix
            secrets.nixosModules.secrets
          ];


          # Select the target system here.
          system = "x86_64-linux";
        };
      };
    };
}


