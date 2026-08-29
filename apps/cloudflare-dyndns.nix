{config, pkgs, lib, ...}:

with lib;

let 
  cfg = config.services.cloudflare-dyndns-nathan;
in
{
  options = {
    services.cloudflare-dyndns-nathan = {
      enable = mkEnableOption "CloudFlare DynDNS";
      
      authEmail = mkOption {
        type = types.str;
      };

      authKey = mkOption {
        type = types.str;
      };

      zoneId = mkOption {
        type = types.str;
      };

      recordId = mkOption {
        type = types.str;
      };

      recordName = mkOption {
        type = types.str;
      };

      schedule = mkOption {
        type = types.str;
        default = "*-*-* *:0/5:00";
      };

    };
  };

  config = mkIf cfg.enable {
    systemd.services.cloudflare-dyndns = {
      description = "Cloudflare ${cfg.recordName} Dynamic DNS update";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
      serviceConfig = {
        DynamicUser = "yes";
        StateDirectory = "cloudflare-dyndns";
      };
      script = ''
        set -euo pipefail

        cacheFile="$STATE_DIRECTORY/last-ip"
        currentIp="$(${pkgs.curl}/bin/curl -L --silent -H'Content-Type:text/plain' https://api.ipify.org)"

        if [ -f "$cacheFile" ] && [ "$(cat "$cacheFile")" = "$currentIp" ]; then
          echo "IP unchanged ($currentIp), skipping Cloudflare update"
          exit 0
        fi

        ${pkgs.curl}/bin/curl \
        --silent \
        -o /dev/null \
        -X PUT \
        https://api.cloudflare.com/client/v4/zones/${cfg.zoneId}/dns_records/${cfg.recordId} \
        -H "X-Auth-Email: ${cfg.authEmail}" \
        -H "X-Auth-Key: ${cfg.authKey}" \
        -H "Content-Type: application/json" \
        --data "{
                  \"content\":\"$currentIp\",
                  \"ttl\": 120,
                  \"id\":\"${cfg.recordId}\",
                  \"type\":\"A\",
                  \"name\":\"${cfg.recordName}\"
                }"

        echo "$currentIp" > "$cacheFile"
      '';
      startAt = cfg.schedule;
    };
  };
}
