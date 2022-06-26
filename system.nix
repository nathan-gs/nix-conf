{ config, pkgs, lib, fetchgit, ... }:

{

  imports = [
    ./users.nix
    ./software.nix
    ./smb.nix
  ];

  # Install the flakes edition
  nix.package = pkgs.nixFlakes;
  # Enable the nix 2.0 CLI and flakes support feature-flags
  nix.extraOptions = ''
    experimental-features = nix-command flakes 
  '';

  time.timeZone = "Europe/Brussels";

  services.timesyncd.enable = true;


  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.openssh.permitRootLogin = "without-password";
  services.openssh.ports = [22 443];


  # Fail 2 Ban  
  services.fail2ban.enable = true;
  services.fail2ban.jails.sshd = "enabled = true";

  # Hosts
  networking.hosts = {
    "172.16.8.1" = [ "nhtpc.wg" ];
    "172.16.8.2" = [ "nnas.wg" ];
  };

  # Wireguard
   networking.firewall = {
    allowedUDPPorts = [ 51820 ]; # Clients and peers can use the same port, see listenport
  }; 
  
  systemd.services.wireguard-reresolve-dns = {
    description = "reresolve-dns"; 
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.wireguard-tools pkgs.bash pkgs.gawk ];
    script = ''
      SERVICE_NAME="$(systemctl list-units --type service --plain wg-quick* | grep wg-quick | awk '{print $1}' | head -n 1)"
      CONFIG_FILE="$(cat $(systemctl cat $SERVICE_NAME | grep ExecStart | sed 's/ExecStart=//') | grep 'wg-quick up' | sed 's/wg-quick up //')"
      bash ${pkgs.fetchgit {
              url = git://github.com/WireGuard/wireguard-tools;
              rev = "d8230ea0dcb02d716125b2b3c076f2de40ebed99";
              sha256 = "0d1m32ahdr22mm04zvp96w2s42z8i2awh6c6bmldly91l3fgdjph";
            }}/contrib/reresolve-dns/reresolve-dns.sh $CONFIG_FILE
      
    '';
    startAt = "*-*-* *:12:00";
  };

  # Cron
  services.cron.enable = false;

  # Email
  programs.msmtp = {
    enable = true;
    extraConfig = ''
      defaults
      
      account sendgrid
      aliases /etc/aliases
      auth on
      auto_from on
      user ${config.secrets.sendgrid.api.user}
      host ${config.secrets.sendgrid.host}
      maildomain nathan.gs
      password ${config.secrets.sendgrid.api.key}
      port ${toString config.secrets.sendgrid.port}
      syslog on
      tls on

      account default : sendgrid
    '';
    setSendmail = true;
  };

  environment.etc.aliases.text = ''
    default: ${config.secrets.email}
  '';
  
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
    enable = true;
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

  services.openssh.extraConfig = ''

  Match Group mediaonly
    ChrootDirectory /media/media
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
  '';

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };


}
