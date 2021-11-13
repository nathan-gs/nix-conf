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
 
  users.groups.users.members = ["plex" "photoprism" ];


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
    keyFile = true;
  };

  fileSystems."/var/lib/photoprism/originals/fn-fotos" = {
    device = "/media/documents/nathan/onedrive_nathan_personal/fn-fotos";
    options = [ "bind" ];
  };


  networking.firewall.allowedTCPPorts = [ 2342 ];
 
}
