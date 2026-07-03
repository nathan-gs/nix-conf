# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal NixOS flake managing three machines. Edits here flow to real running systems via `switch.sh`; there is no staging.

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

## Auto-upgrade (`services/auto-upgrade.nix`)

Each host runs a 04:00 systemd timer that: `nix flake update` → `nixos-rebuild build` → `switch` → commits `flake.lock` with message `auto-upgrade: update flake.lock (YYYY-MM-DD)` and the tail of the switch output. On build/switch failure it `git checkout -- flake.lock` and exits non-zero. Implications:
- The git working tree on hosts must stay clean enough that committing `flake.lock` is safe (the script only stages `flake.lock`).
- Untested local edits to `.nix` files will be picked up at 04:00 by the same auto-upgrade run — push them or revert before then if you don't want that.
- The recent `git log` is dominated by these auto-commits; look past them for human changes.

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

## CI

`.github/workflows/test.yml` only runs `nix flake metadata` against an older nixpkgs channel — it does **not** evaluate or build the configurations. Treat green CI as "the flake parses," not "this builds."
