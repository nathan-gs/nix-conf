# Forwards this host's journald to nhtpc (services/journal-remote.nix) over
# the existing WireGuard link. Plain HTTP: wg0 is already encrypted.
{ config, lib, pkgs, ... }:

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
  # "microhttpd: Application reported internal error").
  #
  # The second one is neither a network blip nor journal rotation, which is
  # what this comment used to claim. Debug logging on journal-remote
  # (2026-09-13) showed it answering 400 "Decompression of received blob
  # failed" after "ZSTD decoded less data than indicated" — a systemd 260.2 bug
  # handling zstd-compressed journal data objects, hidden behind microhttpd's
  # generic message at default log level. See services/journal-remote.nix for
  # the full trace and the evidence ruling out the link, the file size limits
  # and version skew. No entries are lost; upload resumes from its cursor and
  # the retry succeeds. Reproduces on demand by logging entries over ~512 B
  # (journald's zstd threshold) from nnas.
  #
  # Restart=always already recovers within seconds, so the upload itself is
  # fine. The damage is the transient `failed` state: if a `nixos-rebuild
  # switch` lands in that window, switch-to-configuration reports "the
  # following units failed" and exits 4, which auto-upgrade reads as a failed
  # switch — so a log shipper hiccup fails the whole upgrade.
  #
  # `SuccessExitStatus=1` was the first attempt at that and is *not* enough. It
  # keeps the unit out of `failed`, but switch-to-configuration's end-of-switch
  # scan (pkgs/by-name/sw/switch-to-configuration-ng/src/main.rs) walks every
  # active unit and flags any `.service` in the `auto-restart` substate whose
  # D-Bus `ExecMainStatus != 0`. ExecMainStatus is the raw wait status of the
  # last main process; SuccessExitStatus only changes how systemd *judges* that
  # status, not the number it reports. So a service that keeps exiting 1 is
  # flagged during its 10s restart gap even though it never enters `failed` —
  # exactly the state nnas was caught in on 2026-09-19 (`activating
  # (auto-restart)`, `code=exited, status=1/FAILURE`, switch exit 4). Note the
  # scan is over *all* active units, so `restartIfChanged = false` would not
  # have helped either: the unit does not have to be touched by the switch to
  # be reported by it.
  #
  # The only thing that scan reads is the exit status, so make the process
  # genuinely exit 0: wrap ExecStart in a shell that swallows the exit code.
  # Restart=always still brings it back 10s later, and the restart delay is
  # kept flat rather than letting upstream's RestartSteps back it off toward
  # 60s (a longer window is a bigger target for a switch to land in).
  #
  # Trade-off: a genuine misconfiguration now shows up only as a restart loop
  # in the journal — never as a failed unit, and so never in a switch summary
  # or in `systemctl --failed`.
  #
  # Upstream's WatchdogSec=3min has to go with it. The wrapper, not
  # systemd-journal-upload, is now the main process, and NotifyAccess defaults
  # to `main`, so the real binary's WATCHDOG=1 pings would be ignored and
  # systemd would kill the service every three minutes. `exec`ing the binary
  # instead would keep the watchdog but hand its exit code straight back to
  # systemd, which is the whole thing being avoided here.
  systemd.services.systemd-journal-upload = {
    # Never let repeated restarts park the unit in
    # `failed (start-request-repeated-too-quickly)` — same exit-4 problem.
    # This lands in [Unit], where systemd wants it.
    startLimitIntervalSec = 0;

    serviceConfig = {
      # The empty first element emits a bare `ExecStart=` reset line, which
      # systemd requires before overriding an upstream unit's ExecStart from a
      # drop-in — without it this would be *appended* to the original.
      ExecStart = lib.mkForce [
        ""
        "${pkgs.writeShellScript "journal-upload-ignore-exit" ''
          ${config.systemd.package}/lib/systemd/systemd-journal-upload --save-state || :
        ''}"
      ];
      WatchdogSec = lib.mkForce 0;

      RestartSec = lib.mkForce "10s";
      RestartSteps = 0;
      RestartMaxDelaySec = "10s";
    };
  };
}
