{ config, pkgs, ... }:
{
  services.prometheus.exporters = {
    node.enable = true;
  };

  services.vmagent = {
    enable = true;
    remoteWriteUrl = "https://${config.secrets.grafanaCloud.api.username}:${config.secrets.grafanaCloud.api.key}@prometheus-prod-01-eu-west-0.grafana.net/api/prom/push";
    prometheusConfig = {
      scrape_configs = [
        {
          job_name = "node";
          scrape_timeout = "40s"; # Deal with slow network of nnas
          static_configs = [
            { targets = 
              [ 
                "nhtpc.wg:${toString config.services.prometheus.exporters.node.port}" 
                # "nhtpc.wg:${toString config.services.prometheus.exporters.smokeping.port}"
                "nnas.wg:${toString config.services.prometheus.exporters.node.port}"
                "ndesk:4445"
              ];
            }
          ];
        }
        {
          job_name = "homeassistant";
          scrape_timeout = "10s";
          metrics_path = "/api/prometheus";
          authorization.credentials = config.secrets.home-assistant.llat.prometheus;
          static_configs = [
            { targets = 
              [ 
                "nhtpc.wg:${toString config.services.home-assistant.config.http.server_port}"
              ];
            }
          ];
        }
      ];
    };
  };

  services.grafana = {
    enable = false;
    settings.server = {
      domain = "nathan.gs";
      http_addr = "0.0.0.0";
    };
    
    provision.enable = true;
    provision.datasources = [
      {
        name = "prometheus";
        type = "prometheus";
        url = "http://localhost:${toString config.services.prometheus.port}";
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 
    config.services.prometheus.port 
    config.services.grafana.settings.server.http_port 
  ];

  services.tuya-prometheus = {
    enable = false;
    clientId = config.secrets.tuya.clientId;
    secret = config.secrets.tuya.secret;
    startAt = "*:0/5";
  };


}
