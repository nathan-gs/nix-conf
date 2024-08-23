{ config, pkgs, lib, fetchFromGithub, ... }:

{

  imports = [
    ./home-assistant-dev-service.nix
  ];

  services.home-assistant-dev = {
    enable  = true;
    openFirewall = true;
    configWritable = false;
    package = pkgs.home-assistant.overrideAttrs (prev: {
      patches = prev.patches ++ [./home-assistant-duckdb.patch];      
      withoutCheckDeps = true;
      doCheck = false;
      doInstallCheck = false;
      dontCheck = true;
      pytestCheckPhase = false;
    });
    extraPackages = p: with p; [
      # recorder postgresql support
      #duckdb-engine
      (p.callPackage ./home-assistant-duckdb-engine.nix {})
    ];
    configDir = "/var/lib/hass-dev";    
    lovelaceConfigWritable = false;
    config = {
      http.server_port = 8124;
      default_config = {};
      backup = {};
      homeassistant = {
        name = "SXW";
        latitude = config.secrets.home-assistant.latitude;
        longitude = config.secrets.home-assistant.longitude;
        unit_system = "metric";            
        time_zone = "Europe/Brussels";
        country = "BE";
      };     
      recorder = {
        db_url = "duckdb:///var/lib/hass-dev/home-assistant.duckdb";
        auto_purge = true;
        auto_repack = true;
      };
    };

    
  };



}