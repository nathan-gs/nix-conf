{
  inputs = {
    tuya-cloud-bash.url = "github:nathan-gs/tuya-cloud-bash";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    secrets.url = "git+file:///etc/nixos/secrets";
  };
  

  outputs = { nixpkgs, tuya-cloud-bash, secrets, ... }: {
    nixosConfigurations.nhtpc = nixpkgs.lib.nixosSystem {
      modules = [
        # Point this to your original configuration.
        ./computers/nhtpc.nix
        tuya-cloud-bash.nixosModules.tuya-prometheus
        secrets.nixosModules.secrets
#        photoprism.nixosModules.photoprism
      ];

      
      # Select the target system here.
      system = "x86_64-linux";
    };
  

    nixosConfigurations.nnas = nixpkgs.lib.nixosSystem {
      modules = [
        # Point this to your original configuration.
        ./computers/nnas.nix
        tuya-cloud-bash.nixosModules.tuya-prometheus
        secrets.nixosModules.secrets
      ];

      
      # Select the target system here.
      system = "x86_64-linux";
    };
  };

}
