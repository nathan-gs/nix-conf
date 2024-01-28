{ config, pkgs, lib, fetchgit, ... }:

{

  imports = [
    ./software.nix    
    ./hosts.nix
    ./services/ssh.nix
    ./services/fail2ban.nix
    ./services/mail.nix
    ./services/wireguard.nix
  ];

  # Install the flakes edition
  nix.package = pkgs.nixFlakes;
  # Enable the nix 2.0 CLI and flakes support feature-flags
  nix.extraOptions = ''
    experimental-features = nix-command flakes 
  '';

  time.timeZone = "Europe/Brussels";

  services.timesyncd.enable = true;

  # Cron
  services.cron.enable = false;

  # Prometheus
  services.prometheus.exporters.node = {
    enable = true;
    openFirewall = true; 
    enabledCollectors = [ "systemd" "textfile" ];
    extraFlags = [ 
      "--collector.textfile.directory=/var/lib/prometheus-node-exporter/text-files" 
      "--no-collector.rapl" # BUG: https://github.com/prometheus/node_exporter/issues/1892
    ];
  };

  # Promtail (Loki)
  services.promtail = {
    enable = false;
    configuration = {
      server = {
        http_listen_port = 3101;
        http_listen_address = "0.0.0.0";
        grpc_listen_port = 9096;
      };
      scrape_configs = 
        [
          {
            job_name = "journal";
            journal = {
              max_age = "1h";
              labels = { 
                job = "systemd-journal";
                host = "${config.networking.hostName}";
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      clients = [
        { url = config.secrets.grafanaCloud.promtail.url; }        
      ];
    };
  };

  
  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  nix.gc = {
    automatic = true;
    dates = "weekly";
  };


}
