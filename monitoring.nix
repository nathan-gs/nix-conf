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
  
  networking.firewall.allowedTCPPorts = [ config.services.prometheus.port ];
}
