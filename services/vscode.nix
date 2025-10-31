{ config, pkgs, channels, nixpkgs-unstable, lib, ... }:
{

  imports = [
    "${channels.nixpkgs-unstable}/nixos/modules/services/web-apps/openvscode-server.nix"
  ];
  disabledModules = [
    "services/web-apps/openvscode-server.nix"
  ];

  services.openvscode-server = {
    enable = true;
    user = "nathan";
        userDataDir = "/home/nathan/.vscode_server";
    #host = "127.0.0.1";
    host = "0.0.0.0";
    package = pkgs.nixpkgs-unstable.openvscode-server;
    extraPackages = [ pkgs.sqlite pkgs.nodejs pkgs.nixpkgs-fmt pkgs.nixd pkgs.git ];
    withoutConnectionToken = true;
    extraEnvironment = {
      SSH_AUTH_SOCK = "/home/nathan/.ssh/ssh_auth_sock";
    };
    extraArguments = [
      "--log=info"
    ];
  };

  services.nginx.virtualHosts."vscode.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      proxy_buffering off;
    '';
    basicAuth = config.secrets.nginx.basicAuth;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3000";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig = ''
        # required when the target is also TLS server with multiple hosts
        proxy_ssl_server_name on;
        # required when the server wants to use HTTP Authentication
        proxy_pass_header Authorization;

        proxy_set_header X-Real-IP          $remote_addr;
        proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto  $scheme;
      '';
    };
  };

  services.nginx.virtualHosts."dev.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      proxy_buffering off;
    '';
    basicAuth = config.secrets.nginx.basicAuth;
    locations."/" = {
      proxyPass = "http://127.0.0.1:4000";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig = ''
        # required when the target is also TLS server with multiple hosts
        proxy_ssl_server_name on;
        # required when the server wants to use HTTP Authentication
        proxy_pass_header Authorization;

        proxy_set_header X-Real-IP          $remote_addr;
        proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto  $scheme;
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 3000 4000 ];
}
