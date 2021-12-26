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
              "nhtpc.wg:${toString config.services.prometheus.exporters.smokeping.port}"
              "nnas.wg:${toString config.services.prometheus.exporters.node.port}"
            ];
          }
        ];
      }
    ];
    exporters = {
      smokeping = {
        enable = true;
        hosts = ["192.168.1.1" "1.1.1.1" "8.8.8.8" "195.238.2.21" "nnas.wg"];
        
      };
    };

    remoteWrite.grafanaCloud = {
      url = "https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push";
      basic_auth = {
        username = config.secrets.grafanaCloud.api.username;
        password = config.secrets.grafanaCloud.api.key;
      };

    };
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
      {
        name = "loki";
        type = "loki";
        url = "http://localhost:3100";
      }
    ];
    smtp = {
      enable = true;
      host = config.services.ssmtp.hostName;
      user = config.services.ssmtp.authUser;
      password = config.services.ssmtp.settings.AuthPass;
      fromAddress = config.secrets.email;
    };
  };

  services.loki = {
    enable = true;
    extraFlags = [];
    
    configuration = {
      auth_enabled = false;

      server = {
        http_listen_port = 3100;
        http_listen_address = "0.0.0.0";
        grpc_listen_port = 9095;
      };
      ingester = {
        lifecycler = {
          address = "0.0.0.0";
          ring = {
            kvstore.store = "inmemory";
            replication_factor = 1;
          };
        };
      };
      
      schema_config = {
        configs = [
          {
            from = "2021-01-01";
            store = "boltdb";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
            };
          }
        ];
      };
      
      storage_config = {
        boltdb.directory = "/var/lib/loki/boltdb";
        filesystem.directory = "/var/lib/loki/chunks";
      };
    };
    
  };
  
  networking.firewall.allowedTCPPorts = [ 
   config.services.prometheus.port 
   config.services.grafana.port 
   config.services.loki.configuration.server.http_listen_port
  ];

  services.tuya-prometheus = {
    enable = true;
    clientId = config.secrets.tuya.clientId;
    secret = config.secrets.tuya.secret;
    startAt = "*:0/5";
  };


}
