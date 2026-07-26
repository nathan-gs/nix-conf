{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    pkgs.nixpkgs-unstable.esphome
    claude-code
    grok-build
    gemini-cli
  ];
}
