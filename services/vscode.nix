{ config, pkgs, channels, nixpkgs-unstable, lib, ... }:
{

  #imports = [
  #  "${channels.nixpkgs-unstable}/nixos/modules/services/web-apps/openvscode-server.nix"
  #];
  #disabledModules = [
  #  "services/web-apps/openvscode-server.nix"
  #];

  services.openvscode-server = {
    enable = true;
    user = "nathan";
        userDataDir = "/home/nathan/.vscode_server";
    #host = "127.0.0.1";
    host = "0.0.0.0";
    #package = pkgs.nixpkgs-unstable.openvscode-server;
    extraPackages = [ pkgs.sqlite pkgs.nodejs pkgs.nixpkgs-fmt pkgs.nixd pkgs.git ];
    withoutConnectionToken = true;
    extraEnvironment = {
      SSH_AUTH_SOCK = "/home/nathan/.ssh/ssh_auth_sock";
    };
    extraArguments = [
      "--log=info"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 3000 4000 ];

  services.vscode-server.enable = true;

  environment.systemPackages = with pkgs; [
    nixpkgs-fmt
  ];
}
