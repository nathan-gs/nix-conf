{ config, pkgs, lib, ... }:

{

  networking.firewall.allowedTCPPorts = [ 3000 3001 ];

  services.openvscode-server = {
    enable = true;
    user = "nathan";
    userDataDir = "/home/nathan/.vscode_server";
    host = "0.0.0.0";
    extraPackages = [ pkgs.sqlite pkgs.nodejs pkgs.nixpkgs-fmt pkgs.nixpkgs-unstable.nixd ];
    withoutConnectionToken = true;


  };

  # TODO remove
  nixpkgs.config.permittedInsecurePackages = [
    "nodejs-16.20.2"
  ];

}
