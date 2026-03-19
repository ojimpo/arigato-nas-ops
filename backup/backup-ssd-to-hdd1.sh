#!/usr/bin/env bash
set -euo pipefail
RESTIC_BIN="/home/kouki/.local/bin/restic"
export RESTIC_REPOSITORY="/mnt/media/.system-backups/arigato-nas/restic"
export RESTIC_PASSWORD_FILE="/home/kouki/.config/restic/arigato-nas-passphrase"
EXCLUDES="/home/kouki/.config/restic/arigato-nas-excludes.txt"
HOST_TAG="$(hostname -s)"
"$RESTIC_BIN" backup /home /etc /var/lib --exclude-file "$EXCLUDES" --one-file-system --tag "host:${HOST_TAG}" --tag "job:ssd-to-hdd1"
"$RESTIC_BIN" forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --prune
