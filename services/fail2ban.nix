{ config, pkgs, lib, ... }:
{
  services.fail2ban = {
    enable = true;
    bantime-increment.enable = true;

    # Same ranges nginx treats as internal (home-network.nix): LAN, the
    # WireGuard subnet and localhost. Sourced from there rather than repeated
    # so the two can never drift -- previously only the LAN was listed, which
    # left a WireGuard client bannable by any jail even though nginx already
    # trusts it.
    ignoreIP = config.homeNetwork.trustedSources;
  };

}
