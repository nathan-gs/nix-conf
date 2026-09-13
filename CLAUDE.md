# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal NixOS flake managing three machines. Edits here flow to real running systems via `switch.sh`; there is no staging.

## ⛔ NEVER run `switch.sh` (or otherwise switch/activate a configuration)

**Deploying is exclusively the user's prerogative.** Claude must NEVER run
`./switch.sh`, `nixos-rebuild switch`, `./upgrade.sh`, or any command that
activates a configuration on a running host — not even to fix an outage, verify
a change, or "close the loop", and not even if a previous task seemed to imply
it. Applying changes is always the user's call, every time.

Claude MAY build to verify (`sudo nixos-rebuild build --flake .#<host>`) and
commit/merge to `main` locally, then stop and tell the user to run `switch.sh`
themselves. If a change can only be verified live, say so and wait — do not
switch.

## Common commands

```sh
./switch.sh        # nixos-rebuild switch for the current host (uses `hostname --short`)
./upgrade.sh       # nix flake update + switch --upgrade
sudo nixos-rebuild build --flake .#<host>   # dry build (used by auto-upgrade to gate a switch)
nix flake metadata # quick sanity check; this is what CI runs
```

The flake's `nixosConfigurations` are keyed by hostname (`nhtpc`, `ngo`, `nnas`), so `--flake .#<host>` is how you target a specific machine.

## Hosts

| Host    | Role                                | Entry point              |
|---------|-------------------------------------|--------------------------|
| `nhtpc` | Home server (smarthome, media, HA)  | `computers/nhtpc.nix`    |
| `ngo`   | Surface Go laptop, GNOME desktop    | `computers/ngo.nix`      |
| `nnas`  | Headless NAS                        | `computers/nnas.nix`     |

`ngo` is set up as a **remote-builder client** — it offloads x86_64 builds to `h.nathan.gs` (which is `nhtpc` via WireGuard). `nhtpc` runs the `nixdist` user (`services/remote-build-host.nix`) that accepts those builds. If you change things that affect closure size on `ngo`, expect builds to happen on `nhtpc`.

## Layout

- `computers/<host>.nix` — top-level per-host entry point. Imports shared modules + host-specific hardware/network.
- `system.nix` — shared base (nix settings, timezone, prometheus node exporter, ssh/fail2ban/mail/wireguard). Every host imports this.
- `disks.nix` — **custom module** exposing a `disks` option (see "Disk abstraction" below).
- `software.nix` — system-wide packages.
- `services/` — service modules. Hosts opt in by importing them individually from `computers/<host>.nix`.
- `apps/` — user-facing app modules (smaller scope than `services/`).
- `smarthome.nix` + `smarthome/` — Home Assistant config tree, only imported by `nhtpc`. Heavily nested by domain (`energy/`, `hvac/`, `occupancy/`, …).
- `lib/ha.nix` — helpers (`sensor.*`, `genId`, …) for building Home Assistant entity attrsets. Use these instead of hand-writing entity dicts.
- `pkgs/` — vendored package definitions for things not in nixpkgs or pinned to a specific version.
- `manual/` — notes and one-off SQL/JSON; not imported by Nix.

## Secrets

Secrets live in a **separate git repo** at `/etc/nixos/secrets`, pulled in as the `secrets` flake input (`git+file:///etc/nixos/secrets`). They are exposed via `config.secrets.*` (e.g. `config.secrets.wireguard.nhtpc.private`, `config.secrets.ssh.<name>.pub`, `config.secrets.cloudflare.*`). Never inline credentials — extend the secrets repo and reference `config.secrets`.

## Disk abstraction (`disks.nix`)

`disks.nix` defines an options module: each host declares `disks.root`, `disks.data`, and `disks.btrfs.volumes` (with `disks.btrfs.snapshots.monthly.volumes`). From those, the module generates:
- `services.smartd` device list
- `fileSystems."/media/<volume>"` btrfs subvolume mounts
- `systemd.services.btrfs-backup-nightly` / `btrfs-backup-monthly` snapshots into `/media/disks/backup/<volume>/`
- `systemd.services.btrfs-scrub` (monthly, on the first listed volume)
- prometheus textfile exporters for btrfs + smartd via scripts in `ext/`

When adding/removing data disks or btrfs volumes, edit the host file's `disks = { … }` block — don't hand-roll `fileSystems` entries.

## Health monitoring (`services/server-health2mqtt.nix`)

`nhtpc` and `nnas` publish their own health to MQTT for Home Assistant, retained, under
`system/network/server/<host>/`:

| Topic | Tier | Contents |
|-------|------|----------|
| `…/host` | fast | uptime, load, CPU used/iowait, memory, swap, CPU/NVMe/chipset temps (+ all hwmon temps & fans as attributes), root fs usage, failed units, reboot-required |
| `…/disk/<serial>` | slow | per-disk SMART: health, temperature, power-on hours, wear, reallocated/pending sectors |
| `…/disk/<serial>/standby` | slow | `ON` when the disk was asleep and deliberately not read |
| `…/btrfs` | slow | device error counters, usage, missing devices, scrub status/age/errors |

Two rules drive the design, both because these boxes boot off small flash and `nnas` is weak:

- **Never wake a disk.** Every `smartctl` call passes `-n standby`. A sleeping disk publishes
  only to `…/standby` — its data topic is left untouched so the retained last-known-good values
  and their `ts` survive. On a host whose disks sleep, a disk record being days old is *normal*;
  the `.smart_updated` sensor is how you tell that apart from a fault.
- **Never write local state.** MQTT retain is the state store — no spool or stamp files. Units run
  at `LogLevelMax=warning` so the frequent timer does not dribble journal writes onto root.

The fast tier (`hostInterval`, 5m / 10m on nnas) reads only `/proc`, `/sys` and `/run` — zero disk
IO. The slow tier (`disksInterval`, 30m) is the only one that forks `smartctl`/`btrfs`.

That 30m is bounded by the **spin-down timer, not CPU**. Verified on nhtpc with all three data
disks in standby: a full `disks` run leaves every one of them in standby — `smartctl -n standby`
does not touch a sleeping disk, and `btrfs device stats` / `filesystem usage` read in-kernel
counters while `scrub status` reads a file on the root filesystem. But on a disk that happens to be
*awake*, the SMART command may reset its idle timer, so an interval at or below
`disks.hdparm.standby * 5` seconds (120 → 10 minutes here) risks holding disks awake forever.
Keep a comfortable margin above that.

Entities register themselves through **MQTT discovery**, generated in Nix from each host's own
`disks` block, so `nnas` publishes its own inventory and nhtpc's HA config never enumerates it.
Each host becomes one HA device, with every physical disk a child device (real model + serial)
linked via `via_device`. Alerting lives in `smarthome/system/servers.nix` and finds the problem
sensors by entity-id shape — adding a disk needs no HA-side change.

Thresholds (disk temp, fs %, scrub age, wear) are evaluated **on each host**, not in HA, so a host
judges itself; HA only routes the resulting `problems` list to a notification.

Reallocated sectors are tracked as a first-class per-disk entity (`…_reallocated`, or
`…_media_errors` on NVMe) — it is the best early warning of a failing drive. Both it and the btrfs
device-error counters are **cumulative and never decrease**, so alerting on "> 0" would pin a
machine carrying an old count into a permanent alert. They alert on growth past a declared
baseline instead: `serverHealth2mqtt.baselineReallocated.<serial>` and `baselineBtrfsErrors`, both
defaulting to 0. Set them by hand with a comment saying when and why — never auto-learned, since a
baseline that absorbs whatever it sees would absorb a slowly-growing fault too.

**No entity is created for a metric the hardware cannot report.** An entity that is unavailable for
the life of the machine is indistinguishable from a fault in the `unavailable_entities` check in
`smarthome/ha/default.nix`, and would have to be added to that ignore list. So `wear` exists only
for NVMe (the ATA disks here expose no equivalent), `nvme_temperature` only on a host that has an
NVMe, and there is no chipset-temperature entity at all since whether a host exposes a trustworthy
platform sensor is not knowable at eval time — that value still ships inside the `temps` attribute
map. Likewise a sleeping disk publishes `problem_count: 0` ("OK") rather than nothing; only values
that are genuinely unknown are left null, and those go unavailable rather than "unknown".

Entities are created from **retained** discovery configs, so removing one means publishing an empty
payload over its topic — deleting it in the HA UI alone just brings it back. `server-health2mqtt-purge.service`
(manual, never timed) does that for this host's configs, after which
`server-health2mqtt-discovery.service` recreates them:

```sh
sudo systemctl start server-health2mqtt-purge      # drop the HA entities
sudo systemctl start server-health2mqtt-discovery  # recreate them
```

Needed whenever a generated `entity_id` changes (HA only honours `default_entity_id` when an entity
is *created*) and to clear out a disk that has been replaced, whose retained topics would otherwise
keep its entities alive forever. Purge touches discovery topics only — state topics keep their
retained payloads, so recreated entities repopulate at once rather than sitting unknown until the
next slow-tier run, which for a sleeping disk could be days.

A **"Server health" dashboard** (`smarthome/dashboards/server-health.yaml`) is registered from
`smarthome/system/servers.nix` as an additional YAML-mode dashboard at `/server-health` — the
default dashboard stays storage-mode and UI-editable. It uses the sections view type, unlike the
older masonry dashboards in that directory. Being YAML mode it is **not editable in the UI**: edit
the file and switch. It is **copied** into `/var/lib/hass/dashboards/` and touched, not symlinked
into the store: HA caches a YAML dashboard and invalidates by `os.path.getmtime()`, which follows
symlinks into `/nix/store` where every mtime is epoch 1970 — so a symlinked dashboard is never seen
as newer and edits only appear after an HA restart. Host names are hardcoded (there are two); disk rows come from `auto-entities`
filters on the entity-id shape, so swapping a disk needs no dashboard edit. Note HA requires the
dashboard's url_path to contain a hyphen.

`services/hw-health-report.nix` (monthly email, `nhtpc` only) is intentionally still in place:
HA runs on nhtpc, so if nhtpc is down there is no one to alert. Keep a mail path for that case.

## Auto-upgrade (`services/auto-upgrade.nix`)

Nightly **leader / follower** timers (±delay 10m) so only one host advances flake inputs. **Every host switches itself** — the leader publishes a lock, it never drives a switch on another machine:

| Host    | Role     | `updateFlake` | Timer           | Behavior |
|---------|----------|---------------|-----------------|----------|
| `nhtpc` | leader   | `true`        | 04:00 / 05:00   | `nix flake update` → build self **and** remotes → switch self → commit `flake.lock` → `git push` secrets + nix-conf to remotes |
| `nnas`  | follower | `false`       | 05:00 / 05:45   | No flake update. Builds + switches itself from whatever `flake.lock` it has; mails its own failures |

Leader settings live on `nhtpc` (`syncRemotes = [ { host = "nnas.wg"; flakeAttr = "nnas"; } ]`). The push reuses the `nhtpc-backup` SSH key (same as media-rsync); no sudo needed on the remote. Push (not pull) because the only machine key is nhtpc→nnas — `nathan@nnas` has no private key of its own, which is why `bin/sync-nnas` only works from an interactive session with a forwarded agent. Secrets are pushed **before** nix-conf so the rev pinned in `flake.lock` exists on the follower. The leader still builds `#nnas` locally before committing the lock, so a lock that breaks the follower is never published.

The leader used to `nixos-rebuild switch` on nnas over SSH. That coupled the leader's exit status to the follower's: `switch-to-configuration` exits 4 when *any* unit fails to restart, so a transient `systemd-journal-upload` blip on nnas (see `services/journal-upload.nix`) reported nhtpc's already-successful upgrade as failed, and mailed about it. Each host owning its own switch and its own failure mail removes that.

On build/switch failure the leader discards `flake.lock` changes and records a fail marker (same lock hash is not retried until inputs move). Implications:
- The git working tree on the leader must stay clean enough that committing `flake.lock` is safe (the script only stages `flake.lock`).
- Untested local edits to `.nix` files on the leader will be picked up at 04:00 by the same auto-upgrade run — push them or revert before then if you don't want that.
- The recent `git log` is dominated by these auto-commits; look past them for human changes.
- Followers stay in sync via the leader's git push, not a second `nix flake update`.

## Available tooling

System-wide packages you can assume exist on every host: `git` (gitMinimal), `iotop`, `htop`, `powertop`, `tmux`, `tree`, `jq`, `onedrive`, `esphome` (from `nixpkgs-unstable`), `claude-code` (from `software.nix`), plus `hass-cli` (Home Assistant CLI, on `nhtpc`). And the standard NixOS base (`nix`, `nixos-rebuild`, `systemctl`, `journalctl`, `coreutils`, `bash`).

For anything else, **don't install it system-wide** — run it ad-hoc via `nix-shell`:

```sh
nix-shell -p ripgrep fd --run 'rg ...'
nix-shell -p sqlite --run 'sqlite3 /path/to.db ...'
```

Only add to `environment.systemPackages` in `software.nix` if the tool needs to be persistently available across sessions/reboots; otherwise prefer `nix-shell -p`.

## Conventions

- New services: add a module under `services/`, then import it from each `computers/<host>.nix` that should run it. Don't auto-include from `system.nix` — host opt-in is the pattern here.
- For Home Assistant entities, prefer the helpers in `lib/ha.nix` to keep `unique_id` generation consistent.
- The `nixpkgs-unstable` channel is available as `pkgs.nixpkgs-unstable.*` via an overlay in `flake.nix` — use it for individual packages that need to be newer (e.g. `esphome`) without bumping the whole system.

## Worktree workflow

After completing work in a worktree, always merge back to `main` locally:

```sh
git merge <worktree-branch> --no-ff
```

Then delete the worktree branch. Do not leave worktree branches unmerged.

## CI

`.github/workflows/test.yml` only runs `nix flake metadata` against an older nixpkgs channel — it does **not** evaluate or build the configurations. Treat green CI as "the flake parses," not "this builds."
