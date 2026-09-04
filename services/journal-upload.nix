# Forwards this host's journald to nhtpc (services/journal-remote.nix) over
# the existing WireGuard link. Plain HTTP: wg0 is already encrypted.
{ config, lib, ... }:

{
  services.journald.upload = {
    enable = true;
    settings.Upload.URL = "http://nhtpc.wg:19532";
  };
}
