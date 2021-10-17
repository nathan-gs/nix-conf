#!/bin/sh

d=$(date +%Y%m%d%H%M%S)
tar czf "/media/documents/nathan/nix-secrets/secrets-$d.tar.gz" /etc/secrets/
