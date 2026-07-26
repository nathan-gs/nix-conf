#!/usr/bin/env bash
# Manual trigger for the media-rsync systemd unit (nhtpc → nnas).
set -euo pipefail
exec systemctl start --wait media-rsync.service
