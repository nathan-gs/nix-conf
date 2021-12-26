{
  inputs = {
    tuya-cloud-bash.url = "github:nathan-gs/tuya-cloud-bash";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    secrets.url = "path:/etc/nixos/secrets/";
  };
  

  outputs = { nixpkgs, tuya-cloud-bash, secrets, ... }: {
    nixosConfigurations.nhtpc = nixpkgs.lib.nixosSystem {
      modules = [
        # Point this to your original configuration.
        ./computers/nhtpc.nix
        ./computers/nnas.nix
        tuya-cloud-bash.nixosModules.tuya-prometheus
        secrets.nixosModules.secrets
#        photoprism.nixosModules.photoprism
      ];

      
      # Select the target system here.
      system = "x86_64-linux";
    };
  };
}
