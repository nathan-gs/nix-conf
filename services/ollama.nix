{ config, pkgs, lib, ... }:

{

  services.nextjs-ollama-llm-ui = {
    enable = true;
    ollamaUrl = "http://127.0.0.1:${toString config.services.ollama.port}";
    port = 11435;
  };

  services.ollama = {
    enable = true;
    loadModels = [ "phi4" "llama3.2:1b" ];
    environmentVariables.OLLAMA_ORIGINS = "*";
  };

}
