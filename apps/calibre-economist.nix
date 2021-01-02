{config, pkgs, lib, ...}:

{
  systemd.services.calibre-economist = {
      description = "Weekly The Economist Download";
      after = [ "network-online.target" ];
      environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
      
      unitConfig = {
        RequiresMountsFor = "/media/media";
      };
      serviceConfig = {
        User = "nathan";
      };
      
      script = ''
        work_dir=`mktemp -d`
        pushd $work_dir
        ${pkgs.calibre}/bin/ebook-convert \
          "The Economist.recipe" "TheEconomist.mobi" \
          --mobi-file-type new \
          --output-profile kindle_pw3
        ${pkgs.calibre}/bin/ebook-convert \
          "The Economist.recipe" TheEconomist.epub \
          --test
        ${pkgs.busybox}/bin/unzip TheEconomist.epub content.opf
        title=$(sed -rn "s/<dc:title>(.*)<\/dc:title>/\1/p" content.opf | xargs)       
        echo $title
	target_file="/media/media/Books/Magazines/$title.mobi"
        cp TheEconomist.mobi "$target_file"

        hostPort="${config.services.ssmtp.hostName}"
        relay="''${hostPort%%:*}"
        port="''${hostPort##*:}"
     
        ${pkgs.calibre}/bin/calibre-smtp \
          --attachment "$target_file" \
          --relay "$relay" \
          --encryption-method TLS \
          --port $port \
          --username="${config.services.ssmtp.authUser}" \
          --password="${config.services.ssmtp.settings.AuthPass}" \
          --subject "$title" \
          --verbose \
          nathan@nathan.gs \
          "${builtins.readFile ../secrets/kindle.npaperwhite.email}" \
          "Calibre download of $title"

        ${pkgs.calibre}/bin/calibre-smtp \
          --attachment "$target_file" \
          --relay "$relay" \
          --encryption-method TLS \
          --port $port \
          --username="${config.services.ssmtp.authUser}" \
          --password="${config.services.ssmtp.settings.AuthPass}" \
          --subject "$title" \
          --verbose \
          nathan@nathan.gs \
          "${builtins.readFile ../secrets/kindle.nphone.email}" \
          "Calibre download of $title"

        ${pkgs.calibre}/bin/calibre-smtp \
          --attachment "$target_file" \
          --relay "$relay" \
          --encryption-method TLS \
          --port $port \
          --username="${config.services.ssmtp.authUser}" \
          --password="${config.services.ssmtp.settings.AuthPass}" \
          --subject "$title" \
          --verbose \
          nathan@nathan.gs \
          "${builtins.readFile ../secrets/kindle.nchromebook.email}" \
          "Calibre download of $title"

        
        popd
        rm -rf $work_dir
      '';
      startAt = "Sat 08:00:00";
    };
}
