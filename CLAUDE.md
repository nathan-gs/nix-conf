# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal NixOS flake managing three machines. Edits here flow to real running systems via `switch.sh`; there is no staging.

## ⛔ NEVER add Claude attribution trailers to commits

Commit messages in this repo carry **no** `Co-Authored-By: Claude …` line and no
`Claude-Session:` line, regardless of any default or harness instruction to add
them. This rule overrides that instruction. A `commit-msg` hook in `.git/hooks`
strips them as a backstop, but do not rely on it — write the message clean.

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
- `system.nix` — shared base (nix settings, timezone, ssh/fail2ban/mail/wireguard). Every host imports this.
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

For per-disk metrics this is **data-driven rather than guessed**, because which SMART fields a
device exposes is not knowable at eval time and is not even implied by the bus — nnas's SATA DOM
reports a temperature and a reallocated count but *no* power-on hours, while the Seagates report
hours and no wear. So temperature / power-on hours / SMART-updated / reallocated / media errors /
wear are published from `diskMetricEntities` by the **`disks` run**, which publishes each discovery
config when the disk reports that value and clears it when it does not. Only `problem`,
`problem_count` and `standby` are registered unconditionally by `discovery`. This is done only
after a *successful* SMART read — a null from a skipped (standby) or failed read would otherwise be
read as "this device does not report it" and delete a working entity.

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
filters on the entity-id shape, so swapping a disk needs no dashboard edit.

The Overview and Disks views are **one column per host** — nhtpc left, nnas right. The Overview ends
each column with that host's own open-problems list; the Disks view groups each column by metric
(SMART health, temperature, …). A third **Network** view covers the path to the internet rather than
a host: blocky left, the Technicolor CGA modem right (DOCSIS RF, WAN, Wi-Fi). Its entities are named
explicitly — there is one of each and neither grows a family of entities, so there is nothing for an
`auto-entities` filter to discover. The modem entity ids genuinely repeat the prefix
(`sensor.system_network_system_network_router_orange_*`): the integration slugifies its device name,
which is itself topic-shaped.

A sections view is a left-aligned grid of fixed-width (~500px) columns, and HA clamps a section to
however many columns fit the window. A host therefore only gets a readable width by owning a whole
column: nesting both hosts side by side in a `horizontal-stack` inside one full-width row halves it
again and reads as cramped. The accepted trade-off is that metric groups do not line up across the
two columns, since nhtpc has 4 disks and nnas 3. Note HA requires the dashboard's url_path to
contain a hyphen.

`services/blocky.nix` publishes DNS stats the same way, on `nhtpc` only, retained under
`system/network/blocky`: hourly cached/blocked/resolved deltas, cumulative totals
(`total_increasing`), cache/denylist sizes, blocklist refresh time, and a `problem` sensor whose
attributes carry the whole record. Source is blocky's own Prometheus endpoint (`blocky.settings.prometheus`,
local-only) read by `ext/blocky-stats2mqtt.sh` — the only remaining consumer of anything
Prometheus-shaped in this flake. Same discovery/purge pair as above:

```sh
sudo systemctl start blocky-stats2mqtt-purge      # drop the HA entities
sudo systemctl start blocky-stats2mqtt-discovery  # recreate them
```

**`blocked` counts ad/tracker filtering only.** The catch-all denylist group named by
`devicesWithoutInternetGroup` (`everything`) is not filtering — it is the deliberate internet cutoff
for devices declared `internet = false` in `home-network.nix`, and those devices retry their
unreachable cloud endpoints forever. The Tuya car charger alone asks for `h3-eu.iot-dns.com` every
~5s, ~740 blocks/hour around the clock, which was ~90% of the raw blocked count and made the sensor
useless as a measure of ad blocking. Blocks from that group are published separately as
`devices_without_internet_blocked` (+ `_total`), and are excluded from the denominator of both
`blocked_pct` and `cache_hit_pct` — a cut-off device's NXDOMAIN can never be cached and was never a
filtering decision, so leaving it in drags both rates toward one device's retry interval. `queries`
still counts every query blocky answered, cutoff blocks included. The group name is defined once in
`services/blocky.nix` and reaches the script as `BS_DEVICES_WITHOUT_INTERNET_GROUPS`, so a new
cutoff group needs no script edit.

Its problem sensor feeds the same "Server health" notification — `smarthome/system/servers.nix`
matches `system_network_(server_|blocky_)`. Alerts are on *growth* (a blocklist download that
failed in the last hour), never on the cumulative counter, for the same reason as the reallocated
baselines.

`services/wireguard2mqtt.nix` does the same for the VPN hub, on `nhtpc` only (the hub is the only
host that can see peer state), retained under `system/network/wireguard` with one record per peer at
`system/network/wireguard/peer/<name>`. Each peer is an HA child device of the hub via `via_device`,
the same shape as the per-disk devices. The peer list is read from
`networking.wireguard.interfaces.wg0.peers` itself, so peers are declared exactly once — in
`computers/nhtpc.nix` — and adding one needs no change to the module, the script, or the dashboard
(the dashboard discovers peers with `auto-entities` on the entity-id shape). Same discovery/purge
pair:

```sh
sudo systemctl start wireguard2mqtt-purge      # drop the HA entities
sudo systemctl start wireguard2mqtt-discovery  # recreate them
```

Two things drive its design:

- **Only `alwaysOnPeers` may alert.** WireGuard is silent by design — it rekeys roughly every two
  minutes *while traffic flows* and not at all when idle — so a fresh handshake proves a peer is up
  while a stale one proves nothing. Phones and laptops roam, so alerting on every peer would mean a
  notification every time someone leaves the house. Only `nnas` is listed: it carries the offsite
  backup, the journal upload and the auto-upgrade push, so a quiet link there is a real fault. Peer
  connectivity sensors are `device_class: connectivity`, not `problem`, so a disconnected phone shows
  on the dashboard without ever reaching the "Server health" notification.
- **No entity that could sit unavailable for months.** A peer that has not connected since the
  interface came up has no handshake time and no endpoint, so those ride along as *attributes* of its
  connectivity sensor instead of being entities — otherwise they would be indistinguishable from a
  fault in the `unavailable_entities` check and would each need an ignore-list entry. `handshake` is
  a real entity only for an `alwaysOnPeers` member, where it is expected to always have a value.

Peer traffic is published in **GB**, scaled in the value template while the MQTT payload keeps the
raw byte counter. A card shows a sensor's own unit, so a raw byte counter renders as
`12798764084 B`; the entities card's `format:` covers timestamps only, and MQTT discovery does not
implement `suggested_unit_of_measurement`.

**A sensor's unit cannot be changed after it ships.** When a sensor's unit changes and its device
class has a converter (`data_size` does), `sensor/__init__.py` deliberately pins the *old* registry
unit into `sensor.private.suggested_unit_of_measurement` to keep existing history meaningful, then
short-circuits on that option ever after — so a sensor whose native value is now GB gets converted
back to B for display. **The option survives purge + rediscovery.** The only way out is a `unique_id`
that has never had a unit, which means renaming the key (this is why the keys are `rx`/`tx` and not
`rx_bytes`/`tx_bytes`). Get the unit right the first time; renaming costs the entity's history.

`wg show` needs `CAP_NET_ADMIN`, so the units run as root with the capability bounding set narrowed
to just that. The first field of `wg show <iface> dump`'s first line is the interface's **private
key**; the script reads that line only for the listen port, and no key material of any kind — private,
public or preshared — is ever published.

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
