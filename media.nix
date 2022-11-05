{ config, pkgs, lib, ... }:

{

  imports = [
    ./apps/calibre-economist.nix
    #./apps/media-scraper.nix
    ./apps/photoprism.nix
  ];
#  services.calibre-server.enable = true;

  nixpkgs.config.allowUnfree = true;

  services.plex = {
    enable = true;
    openFirewall = true;
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
 
}
