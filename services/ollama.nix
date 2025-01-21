{ config, pkgs, lib, ... }:

{

  services.nextjs-ollama-llm-ui = {
    enable = true;
    ollamaUrl = "https://llm.nathan.gs";
    port = 11435;
  };

  services.ollama = {
    enable = true;
    loadModels = [ "phi4" "llama3.2:1b" ];
    environmentVariables.OLLAMA_ORIGINS = "*";
  };

  services.nginx.virtualHosts."llm.nathan.gs" = {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      proxy_buffering off;
    '';
    basicAuth = config.secrets.nginx.basicAuth;
    locations."/" = {

      proxyPass = "http://127.0.0.1:${toString config.services.nextjs-ollama-llm-ui.port}";
      proxyWebsockets = false; # needed if you need to use WebSocket
      extraConfig = ''
        # required when the target is also TLS server with multiple hosts
        proxy_ssl_server_name on;
        # required when the server wants to use HTTP Authentication
        proxy_pass_header Authorization;

        proxy_set_header X-Real-IP          $remote_addr;
        proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto  $scheme;

        location /api {
          proxy_pass http://127.0.0.1:${toString config.services.ollama.port};
          proxy_set_header Host localhost:11434;
        }
        
      '';      
    };
  };

}
