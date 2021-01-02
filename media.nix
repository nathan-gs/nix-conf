{ config, pkgs, lib, ... }:

{

  imports = [
    ./apps/theEconomist.nix
  ];
#  services.calibre-server.enable = true;

  nixpkgs.config.allowUnfree = true;

  services.plex = {
    #dataDir = "/media/apps/plex";
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

  
}
