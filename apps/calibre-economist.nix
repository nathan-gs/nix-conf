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
          "The Economist.recipe" "TheEconomist.epub"
        ${pkgs.calibre}/bin/ebook-convert \
          "The Economist.recipe" TheEconomist-short.epub \
          --test
        ${pkgs.busybox}/bin/unzip TheEconomist-short.epub content.opf
        title=$(sed -rn "s/<dc:title>(.*)<\/dc:title>/\1/p" content.opf | xargs)       
        echo $title
	target_file="/media/media/Books/Magazines/$title.epub"
        cp TheEconomist.epub "$target_file"

        relay="${config.secrets.smtp.host}"
        port="${toString config.secrets.smtp.port}"
     
        ${pkgs.calibre}/bin/calibre-smtp \
          --attachment "$target_file" \
          --relay "$relay" \
          --encryption-method TLS \
          --port $port \
          --username="${config.secrets.smtp.user}" \
          --password="${config.secrets.smtp.password}" \
          --subject "$title" \
          --verbose \
          ${config.secrets.email} \
          "${config.secrets.kindle.npaperwhite.email}" \
          "Calibre download of $title"

        ${pkgs.calibre}/bin/calibre-smtp \
          --attachment "$target_file" \
          --relay "$relay" \
          --encryption-method TLS \
          --port $port \
          --username="${config.secrets.smtp.user}" \
          --password="${config.secrets.smtp.password}" \
          --subject "$title" \
          --verbose \
          ${config.secrets.email} \
          "${config.secrets.kindle.nphone.email}" \
          "Calibre download of $title"

        ${pkgs.calibre}/bin/calibre-smtp \
          --attachment "$target_file" \
          --relay "$relay" \
          --encryption-method TLS \
          --port $port \
          --username="${config.secrets.smtp.user}" \
          --password="${config.secrets.smtp.password}" \
          --subject "$title" \
          --verbose \
          ${config.secrets.email} \
          "${config.secrets.kindle.nchromebook.email}" \
          "Calibre download of $title"

        
        popd
        rm -rf $work_dir
      '';
      startAt = "Sat 08:00:00";
    };
}
