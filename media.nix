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


  virtualisation.docker.enable = true;

  systemd.services.photoprism-docker = {
    # Make sure docker is started. 
    after = [ "docker.service" "network-online.target" ];
    # To avoid race conditions
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
        # Pulling an image might take a lot of time. 0 turns of the timeouts
        TimeoutStartSec = "0";
        # Restart policy, other relevant options are: 
        # - no
        # - on-failure 
        # Look at the man page:
        # man systemd.service
        Restart = "always";
    };

    # Let's stop the running container , remove the image.
    # The "|| true" is used because systemd expects that a everything succeeds, 
    # while failure is sometimes expected (eg. container was not running).  
    # Pull the image, ideally a version would be specified.     
    preStart = ''
${pkgs.docker}/bin/docker stop photoprism || true;
${pkgs.docker}/bin/docker rm photoprism || true;
${pkgs.docker}/bin/docker pull photoprism/photoprism
    '';

    # Start the container.
    script = ''
${pkgs.docker}/bin/docker run \
  --name photoprism \
  --user 2000:100 \
  -p 2342:2342 \
  --log-driver none \
  -v /var/lib/photoprism:/photoprism/storage \
  -v /var/lib/photoprism/sqlite3:/var/lib/photoprism/sqlite3 \
  -v '/media/documents/nathan/onedrive_nathan_personal/fn-fotos-sidecar':/photoprism/sidecar \
  -v '/media/documents/nathan/onedrive_nathan_personal/fn-fotos':/photoprism/originals \
  -v '/media/documents/nathan/onedrive_nathan_personal/Camera Roll':/photoprism/import/femke-camera-roll \
  -v '/media/documents/nathan/onedrive_nathan_personal/Pictures/Camera Roll':/photoprism/import/nathan-camera-roll \
  --env-file /var/lib/photoprism/env \
  -e PHOTOPRISM_WORKERS=8 \
  -e PHOTOPRISM_SIDECAR_PATH=/photoprism/sidecar \
  -e PHOTOPRISM_ORIGINALS_LIMIT=8000 \
  -e PHOTOPRISM_BACKUP_PATH=/photoprism/storage/backup \
  -e PHOTOPRISM_STORAGE_PATH=/photoprism/storage \
  -e PHOTOPRISM_FACE_SCORE=8 \
  photoprism/photoprism
    '';

     # When the systemd service stops, stop the docker container.
    preStop = ''
${pkgs.docker}/bin/docker kill photoprism
    '';
  };

  networking.firewall.allowedTCPPorts = [ 2342 ];
 
}
