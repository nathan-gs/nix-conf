#!/bin/sh
nix flake update
sudo nixos-rebuild --flake .#$(hostname --short) switch --upgrade
