{ config, pkgs, lib, ... }:
{
  services.vscode-server.enable = true;
  programs.nix-ld.enable = true;
}
