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
    ebusd
  ];

  programs.bash.enableCompletion = true;

}
