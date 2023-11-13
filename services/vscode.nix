{ config, pkgs, lib, ... }:

{

  networking.firewall.allowedTCPPorts = [ 3001 ];

  services.openvscode-server = {
    enable = true;
    user = "nathan";
    userDataDir = "/home/nathan/.vscode_server";
    host = "127.0.0.1";
    extraPackages = [ pkgs.sqlite pkgs.nodejs pkgs.nixpkgs-fmt pkgs.nixpkgs-unstable.nixd ];
    withoutConnectionToken = true;
    extraEnvironment = {
      SSH_AUTH_SOCK = "/home/nathan/.ssh/ssh_auth_sock";
    };
  };

  # TODO remove
  nixpkgs.config.permittedInsecurePackages = [
    "nodejs-16.20.2"
  ];

  services.nginx.virtualHosts."vscode.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3000";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig = ''
        # required when the target is also TLS server with multiple hosts
        proxy_ssl_server_name on;
        # required when the server wants to use HTTP Authentication
        proxy_pass_header Authorization;
        # PAM Auth
        auth_pam "Password Required";
        auth_pam_service_name nginx;
      '';
    };
  };
}
