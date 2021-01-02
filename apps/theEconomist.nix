{config, pkgs, lib, ...}:

{
  systemd.services.the_economist = {
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
     
        ${pkgs.calibre}/bin/calibre-smtp \
          --attachment "$target_file" \
          --relay "${config.services.ssmtp.hostName}" \
          --encryption-method NONE \
          --subject "$title" \
          --verbose \
          nathan@nathan.gs \
          nathan@nathan.gs \
          "Calibre download of $title"
        
        popd
        rm -rf $work_dir
      '';
      startAt = "Sat 08:00:00";
    };
}
