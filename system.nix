{ config, pkgs, lib, fetchgit, ... }:

{

  imports = [
    ./users.nix
    ./software.nix
  ];

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
    path = [ pkgs.wireguard pkgs.bash pkgs.gawk ];
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
  services.ssmtp = {
    enable = true;
    domain = "nathan.gs";
    hostName = "smtp.sendgrid.net:587";
    useSTARTTLS = true;
    authUser = "apikey";
    settings = {
      AuthPass = builtins.readFile ./secrets/sendgrid.api.key;
      FromLineOverride = "${config.networking.hostName}@nathan.gs";
    };
    root = "nathan@nathan.gs";
   };

  # Prometheus
  services.prometheus.exporters.node = {
    enable = true;
    openFirewall = true;
    enabledCollectors = [ "systemd" "textfile" ];
    extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter/text-files" ];
  };

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };


}
