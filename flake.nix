{
  inputs = {
    tuya-cloud-bash.url = "github:nathan-gs/tuya-cloud-bash";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
  };
  

  outputs = { nixpkgs, tuya-cloud-bash, ... }: {
    nixosConfigurations.nhtpc = nixpkgs.lib.nixosSystem {
      modules = [
        # Point this to your original configuration.
        ./computers/nhtpc.nix
        tuya-cloud-bash.nixosModules.tuya-prometheus
#        photoprism.nixosModules.photoprism
      ];

      
      # Select the target system here.
      system = "x86_64-linux";
    };
  };
}
