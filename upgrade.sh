#!/bin/sh
nix flake update
sudo nixos-rebuild --flake .#nhtpc switch --upgrade
