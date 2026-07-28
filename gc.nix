{ config, pkgs, lib, ... }:

{

  nix.gc = {
    automatic = true;
    dates = "weekly";
    # Drop generations older than 14d so nightly auto-upgrade does not pin
    # the entire store forever. Bare collect-garbage only frees unreferenced
    # paths; without this, old system profiles keep disk use high.
    options = "--delete-older-than 14d";
  };

  # Cap boot-menu entries (each is a rooted generation). systemd-boot hosts
  # (nhtpc) and GRUB hosts (nnas) use different options; setting both is fine.
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.grub.configurationLimit = 5;

  # Intentionally *not* enabled here (nnas: Atom + ~5 GiB, small root):
  # - nix.settings.auto-optimise-store — hardlinks on every store write; steady
  #   CPU/I/O tax during builds/switches on weak hardware.
  # - nix.optimise.automatic — full-store walk; long, memory- and disk-heavy
  #   on larger stores. Prefer manual `nix-store --optimise` if space is tight.
  # nhtpc can opt in locally if desired.

}
