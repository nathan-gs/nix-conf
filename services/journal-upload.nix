# Forwards this host's journald to nhtpc (services/journal-remote.nix) over
# the existing WireGuard link. Plain HTTP: wg0 is already encrypted.
{ config, lib, ... }:

{
  services.journald.upload = {
    enable = true;
    settings.Upload.URL = "http://nhtpc.wg:19532";
  };

  # systemd-journal-upload exits 1 on *any* upload hiccup and has no separate
  # exit code for "transient network problem". Over this link that happens
  # several times a day: the wg tunnel between the two sites blips ("Failed to
  # connect ... Could not connect to server"), or journal-remote on nhtpc drops
  # the connection mid-stream ("Empty reply from server", logged there as
  # "microhttpd: Application reported internal error"). The latter still occurs
  # after the MaxFileSize fix in services/journal-remote.nix — it clusters
  # around switches and journal rotation, not around the old 32M ceiling.
  #
  # Restart=always already recovers within seconds, so the upload itself is
  # fine. The damage is the transient `failed` state: if a `nixos-rebuild
  # switch` lands in that window, switch-to-configuration reports "the
  # following units failed" and exits 4, which auto-upgrade reads as a failed
  # switch — so a log shipper hiccup fails the whole upgrade.
  #
  # Treat exit 1 as success so the unit cycles through `inactive` instead of
  # `failed`, and keep the restart delay flat rather than letting upstream's
  # RestartSteps back it off toward 60s (a longer window is a bigger target).
  # Trade-off: a genuine misconfiguration now shows up as a restart loop in
  # the journal rather than a failed unit.
  systemd.services.systemd-journal-upload = {
    # Never let repeated restarts park the unit in
    # `failed (start-request-repeated-too-quickly)` — same exit-4 problem.
    # This lands in [Unit], where systemd wants it.
    startLimitIntervalSec = 0;

    serviceConfig = {
      SuccessExitStatus = [ 1 ];
      RestartSec = lib.mkForce "10s";
      RestartSteps = 0;
      RestartMaxDelaySec = "10s";
    };
  };
}
