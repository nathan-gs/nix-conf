{ config, pkgs, lib, ... }:

{

  services.ollama = {
    enable = true;
    writablePaths = [ "/var/lib/ollama" ];
    models = "/var/lib/ollama/models";
  };

  services.nginx.virtualHosts."ollama.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      proxy_buffering off;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:11434";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig = ''
        # required when the target is also TLS server with multiple hosts
        proxy_ssl_server_name on;
        # required when the server wants to use HTTP Authentication
        proxy_pass_header Authorization;

        # PAM Auth
        auth_pam "Password Required";
        auth_pam_service_name nginx;

        proxy_set_header X-Real-IP          $remote_addr;
        proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto  $scheme;
      '';
    };
  };

}
