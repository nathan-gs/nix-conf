{ config, pkgs, lib, ... }:

{

  nixpkgs.config.allowUnfree = true;

  services.plex = {
    enable = true;
    openFirewall = true;
  };

  users.groups.media.members = [ "plex" ];


  systemd.services.plex = {
    unitConfig = {
      RequiresMountsFor = "/media/media";
    };
    serviceConfig.ExecStart = lib.mkOverride 0 "${config.services.plex.package}/bin/plexmediaserver > /dev/null";
  };

  # Plex Monitoring
  services.tautulli.enable = false;

}
