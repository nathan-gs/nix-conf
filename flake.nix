{
  inputs = {
    photoprism.url = "github:GTrunSec/photoprism2nix";
  };
  

  outputs = { nixpkgs, photoprism, ... }: {
    nixosConfigurations.nhtpc = nixpkgs.lib.nixosSystem {
      modules = [
        # Point this to your original configuration.
        ./computers/nhtpc.nix
        photoprism.nixosModules.photoprism
      ];

      
      # Select the target system here.
      system = "x86_64-linux";
    };
  };
}
