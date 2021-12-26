#!/bin/sh
sudo nixos-rebuild --flake .#$(hostname --short) switch
