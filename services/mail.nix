{ config, pkgs, lib, ... }:
{
  # Email
  programs.msmtp = {
    enable = true;
    extraConfig = ''
      defaults
      
      account apimailer
      aliases /etc/aliases
      auth on
      auto_from on
      user ${config.secrets.smtp.user}
      host ${config.secrets.smtp.host}
      maildomain nathan.gs
      password ${config.secrets.smtp.password}
      port ${toString config.secrets.smtp.port}
      syslog on
      tls on

      account default : apimailer
    '';
    setSendmail = true;
  };

  environment.etc.aliases.text = ''
    default: ${config.secrets.email}
  '';

  # Rendered /etc/msmtprc contains the SMTP password (interpolated from
  # config.secrets above). Drop it from world-readable 0444 to 0600 so only
  # root can read the file at /etc. Note: the same value still appears in
  # /nix/store under the rendered file path — secrets in config.secrets are
  # not protected from local users with /nix/store read access.
  environment.etc.msmtprc.mode = "0600";
}
