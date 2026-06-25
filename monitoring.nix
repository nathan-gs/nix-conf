{ config, pkgs, ... }:
{
  services.vmagent = {
    enable = false;
    remoteWrite.url = "https://${config.secrets.grafanaCloud.api.username}:${config.secrets.grafanaCloud.api.key}@prometheus-prod-01-eu-west-0.grafana.net/api/prom/push";
    prometheusConfig = {
      scrape_configs = [
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
          metric_relabel_configs = [
            {
              source_labels = ["__name__"];
              regex = "ha_state_change_created|ha_state_change_total|ha_last_updated_time_seconds";
              action = "drop";
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

}
