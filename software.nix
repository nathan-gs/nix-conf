{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    pkgs.nixpkgs-unstable.esphome
    pkgs.nixpkgs-unstable.claude-code
    pkgs.nixpkgs-unstable.grok-build
    gemini-cli
    github-cli
  ];
}
