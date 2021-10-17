{
  inputs = {
  };
  

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.nhtpc = nixpkgs.lib.nixosSystem {
      modules = [
        # Point this to your original configuration.
        ./computers/nhtpc.nix
      ];
      # Select the target system here.
      system = "x86_64-linux";
    };
  };
}
