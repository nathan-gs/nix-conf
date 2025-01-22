{ config, pkgs, ... }:

{

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    gitMinimal
    iotop
    htop
    powertop
    tmux
    tree
    jq     
    (pkgs.python312Packages.callPackage ./pkgs/python/autogen-studio.nix {})
    (pkgs.callPackage ./pkgs/sos2mqtt.nix {})
    devenv
    (pkgs.callPackage ./pkgs/onedrive-2.4.nix {})
  ];

  programs.bash.completion.enable = true;

}
