{ config, pkgs, lib, ... }:
let
    # https://blog.developer.atlassian.com/docker-systemd-socket-activation/
    # https://dataswamp.org/~solene/2022-08-20-on-demand-minecraft-with-systemd.html
    port = 2342;
    dockerPort = 23420;

    # wait 60s for a TCP socket to be available
    # to wait in the proxifier
    # idea found in https://blog.developer.atlassian.com/docker-systemd-socket-activation/
    wait-tcp = pkgs.writeShellScriptBin "wait-tcp" ''
        for i in `seq 60`; do
        if ${pkgs.libressl.nc}/bin/nc -z 127.0.0.1 ${toString dockerPort} > /dev/null ; then
            exit 0
        fi
        ${pkgs.busybox.out}/bin/sleep 1
        done
        exit 1
    '';

  photoprismDockerOptions = ''
  ${pkgs.docker}/bin/docker run
    --name photoprism \
    --user 2000:100 \
    -p ${toString dockerPort}:2342 \
    --log-driver none \
    -v /var/lib/photoprism:/photoprism/storage \
    -v /var/lib/photoprism/sqlite3:/var/lib/photoprism/sqlite3 \
    -v '/var/lib/photoprism/sidecar:/photoprism/sidecar' \
    -v '/media/documents/nathan/onedrive_nathan_personal/fn-fotos':/photoprism/originals \
    -v '/media/documents/nathan/onedrive_nathan_personal/Camera Roll':/photoprism/import/femke-camera-roll \
    -v '/media/documents/nathan/onedrive_nathan_personal/Pictures/Camera Roll':/photoprism/import/nathan-camera-roll \
    --env-file /var/lib/photoprism/env \
    -e PHOTOPRISM_WORKERS=8 \
    -e PHOTOPRISM_SIDECAR_PATH=/photoprism/sidecar \
    -e PHOTOPRISM_ORIGINALS_LIMIT=8000 \
    -e PHOTOPRISM_BACKUP_PATH=/photoprism/storage/backup \
    -e PHOTOPRISM_STORAGE_PATH=/photoprism/storage \
    -e PHOTOPRISM_FACE_SCORE=5 \
    -e PHOTOPRISM_WAKEUP_INTERVAL=86400 \
    -e PHOTOPRISM_DISABLE_CLASSIFICATION=true \
  '';

in
{
    virtualisation.docker.enable = true;

    systemd.sockets.photoprism = {
        socketConfig.ListenStream = port;
        wantedBy = ["sockets.target"];
    };

    systemd.services.photoprism = {
        path = with pkgs; [ systemd ];
        requires = ["photoprism-docker.service"];
        after = ["photoprism-docker.service"];
        serviceConfig.ExecStart = "${pkgs.systemd.out}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString dockerPort}";
    };

  systemd.services.photoprism-docker = {
    # Make sure docker is started. 
    after = [ "docker.service" "network-online.target" ];
    # To avoid race conditions
    requires = [ "docker.service" "network-online.target" ];



    # Start the container.
    script = ''
      ${pkgs.docker}/bin/docker rm photoprism || true

      ${photoprismDockerOptions} photoprism/photoprism
    '';

    postStart = "${wait-tcp.out}/bin/wait-tcp";

     # When the systemd service stops, stop the docker container.
    preStop = ''    
    ${pkgs.docker}/bin/docker kill photoprism
    '';
  };

  systemd.services.photoprism-docker-stop-and-upgrade = {
    after = [ "docker.service" ];
    # To avoid race conditions
    requires = [ "docker.service" ];
    # Stop photoprism-docker
    conflicts = [ "photoprism-docker.service"];    
    script = ''
      # only run if the process has run before
      if ${pkgs.docker}/bin/docker rm photoprism; then

        ${photoprismDockerOptions} photoprism/photoprism \
          photoprism optimize

        ${pkgs.docker}/bin/docker rm photoprism || true
        
        ${photoprismDockerOptions} photoprism/photoprism \
          photoprism faces audit --fix

        ${pkgs.docker}/bin/docker rm photoprism || true

        ${pkgs.docker}/bin/docker pull photoprism/photoprism || true
      fi
    '';
    startAt = "23:10";
  };

  systemd.services.photoprism-backup = {
    description = "Photoprism Backup";
    path = [ pkgs.gnutar pkgs.gzip ];
    unitConfig = {
      RequiresMountsFor = "/media/documents";
    };
    serviceConfig = {
      User = "nathan";
    };
    script = ''
       mkdir -pm 0775 /media/documents/nathan/onedrive_nathan_personal/backup/
       target='/media/documents/nathan/onedrive_nathan_personal/backup/photoprism-fn-fotos.tar.gz'
       tar \
         --exclude "import" \
         --exclude "backup" \
         --exclude "cache" \
         --exclude "originals" \
         -czf \
         /tmp/photoprism-fn-fotos.tar.gz \
         -C /var/lib \
         photoprism

       mv /tmp/photoprism-fn-fotos.tar.gz $target
      '';
    startAt = "*-*-* 01:00:00";
  };

  networking.firewall.allowedTCPPorts = [ 2342 ];
}