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
  #nix.package = pkgs.nixFlakes;
  # Enable the nix 2.0 CLI and flakes support feature-flags
  nix.extraOptions = ''
    experimental-features = nix-command flakes 
    extra-substituters = https://devenv.cachix.org
    extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=

    trusted-users = root nathan
  '';

  # Set your time zone.
  time.timeZone = "Europe/Brussels";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

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

  
  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };


}
