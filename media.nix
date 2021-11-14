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

  systemd.services.photoprism.serviceConfig.RestrictAddressFamilies = lib.mkForce "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
  systemd.services.photoprism.serviceConfig.SystemCallFilter = lib.mkForce [ "@system-service" "@network-io" "~@privileged" "~@resources" ];
  systemd.services.photoprism.path = lib.mkForce [ pkgs.darktable pkgs.ffmpeg pkgs.exiftool ];
  systemd.services.photoprism.environment.LD_LIBRARY_PATH=
    (pkgs.libtensorflow-bin.overrideAttrs (oA: {
       # 21.05 does not have libtensorflow-bin 1.x anymore & photoprism isn't compatible with tensorflow 2.x yet
       # https://github.com/photoprism/photoprism/issues/222
       src = pkgs.fetchurl {
         url = "https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-1.15.2.tar.gz";
         sha256 = "04bi3ijq4sbb8c5vk964zlv0j9mrjnzzxd9q9knq3h273nc1a36k";
       };
       version = "1.15.2";
     }));

  
  systemd.services.photoprism.confinement.enable = lib.mkForce false;

  fileSystems."/var/lib/photoprism/originals" = {
    device = "/media/documents/nathan/onedrive_nathan_personal/fn-fotos";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/photoprism/import/femke-cameraroll" = {
    device = "/media/documents/nathan/onedrive_nathan_personal/Camera Roll";
    options = [ "bind" ];
  };

  fileSystems."/var/lib/photoprism/import/nathan-cameraroll" = {
    device = "/media/documents/nathan/onedrive_nathan_personal/Pictures/Camera Roll";
    options = [ "bind" ];
  };

  networking.firewall.allowedTCPPorts = [ 2342 ];
 
}
