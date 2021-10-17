{config, pkgs, lib, ...}:

{
  systemd.services.media-scraper = {
      description = "Media Scraper";
      after = [ "network-online.target" ];
      environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";

      environment.VRT_USERNAME=builtins.readFile /etc/secrets/media-scraper.vrt.username;
      environment.VRT_PASSWORD=builtins.readFile /etc/secrets/media-scraper.vrt.password;
      path = [ pkgs.youtube-dl pkgs.curl pkgs.jq pkgs.pup ];
      
      unitConfig = {
        RequiresMountsFor = "/media/media";
      };
      serviceConfig = {
        User = "nathan";
      };
      
      script = ''
        source ${./media-scraper.functions.sh}
        ${builtins.readFile /etc/secrets/media-scraper.list}

      '';
      startAt = "01:00:00";
    };
}
