{ config, pkgs, lib, ... }:

{

  imports = [
    ./apps/calibre-economist.nix
    ./apps/media-scraper.nix
  ];
#  services.calibre-server.enable = true;

  nixpkgs.config.allowUnfree = true;

  services.plex = {
    enable = true;
    openFirewall = true;
    managePlugins = false;
  };
 
  users.groups.users.members = ["plex"];


  systemd.services.plex = {
    unitConfig = {
      RequiresMountsFor = "/media/media";
    };
    serviceConfig.ExecStart = lib.mkOverride 0 "${config.services.plex.package}/bin/plexmediaserver > /dev/null";
  };
  
  # Plex Monitoring
  services.tautulli.enable = false;

  services.photoprism = {
    enable = true;
    host = "0.0.0.0";
  };

  networking.firewall.allowedTCPPorts = [ 2342 ];
 
}
