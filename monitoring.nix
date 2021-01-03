{ config, pkgs, ... }:

{
  services.prometheus = {
    enable = true;
    scrapeConfigs = [
      {
        job_name = "node";
        scrape_timeout = "40s"; # Deal with slow network of nnas
        static_configs = [
	  { targets = 
            [ 
              "nhtpc.wg:${toString config.services.prometheus.exporters.node.port}" 
              "nnas.wg:${toString config.services.prometheus.exporters.node.port}"
            ];
          }
        ];
      }
    ];
  };

  services.grafana = {
    enable = true;
    domain = "nathan.gs";
    addr = "0.0.0.0";
    provision.enable = true;
    provision.datasources = [
      {
        name = "prometheus";
        type = "prometheus";
        url = "http://localhost:${toString config.services.prometheus.port}";
      }
    ];
    smtp = {
      enable = true;
      host = config.services.ssmtp.hostName;
      user = config.services.ssmtp.authUser;
      password = config.services.ssmtp.settings.AuthPass;
      fromAddress = "nathan+grafana@nathan.gs";
    };
  };
  
  networking.firewall.allowedTCPPorts = [ 
   config.services.prometheus.port 
   config.services.grafana.port 
  ];

}
