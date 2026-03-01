{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    secrets = {
      url = "git+file:///etc/nixos/secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    photoprism-slideshow = {
      url = "github:nathan-gs/photoprism-slideshow";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };
    nixos-vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, secrets, photoprism-slideshow, nixos-hardware, nixos-vscode-server, ... }:
    let
      overlay = final: prev: { nixpkgs-unstable = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}; };
      overlayModule = ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay ]; });
      platformModule = { nixpkgs.hostPlatform = "x86_64-linux"; };

    in
    {

      nixosConfigurations = {
        nhtpc = nixpkgs.lib.nixosSystem {
          modules = [
            # Point this to your original configuration.
            ./computers/nhtpc.nix
            secrets.nixosModules.secrets
            photoprism-slideshow.nixosModules.photoprism-slideshow
            nixos-vscode-server.nixosModules.default
            overlayModule
            platformModule
          ];

          specialArgs.channels = { inherit nixpkgs nixpkgs-unstable; };
        };

        ngo = nixpkgs.lib.nixosSystem {
          modules = [
            # Point this to your original configuration.
            ./computers/ngo.nix
            secrets.nixosModules.secrets
            nixos-hardware.nixosModules.microsoft-surface-go
            overlayModule
            platformModule
          ];

          specialArgs.channels = { inherit nixpkgs nixpkgs-unstable; };
        };

        nnas = nixpkgs.lib.nixosSystem {
          modules = [
            # Point this to your original configuration.
            ./computers/nnas.nix
            secrets.nixosModules.secrets
            overlayModule
            platformModule
          ];
        };
      };
    };
}