{config, pkgs, lib, ...}:

{
  systemd.services.media-scraper = {
      description = "Media Scraper";
      after = [ "network-online.target" ];
      environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";

      environment.VRT_USERNAME=builtins.readFile ../secrets/media-scraper.vrt.username;
      environment.VRT_PASSWORD=builtins.readFile ../secrets/media-scraper.vrt.password;
      path = [ pkgs.youtube-dl pkgs.curl pkgs.jq pkgs.pup ];
      
      unitConfig = {
        RequiresMountsFor = "/media/media";
      };
      serviceConfig = {
        User = "nathan";
      };
      
      script = ''
        source ${./media-scraper.functions.sh}
        
        vrt_search_and_download "/media/media/Series" "Fargo"

        vrt_search_and_download "/media/media/Kids/Series" "Dropje"
        vrt_search_and_download "/media/media/Kids/Series" "Andy's baby dieren"
        vrt_search_and_download "/media/media/Kids/Series" "Andy's dino avonturen"
        vrt_search_and_download "/media/media/Kids/Series" "Andy's prehistorische avonturen"
        vrt_search_and_download "/media/media/Kids/Series" "Shaun het schaap"
        vrt_search_and_download "/media/media/Kids/Series" "Masha en de Beer"
        vrt_search_and_download "/media/media/Kids/Series" "Ridder Muis"
        


        nickjr "/media/media/Kids/Series" "Paw Patrol" http://www.nickjr.nl /paw-patrol/videos/        
        nickjr "/media/media/Kids/Series" "Rusty Rivets" http://www.nickjr.nl /rusty-rivets/videos/

      '';
      startAt = "01:00:00";
    };
}
