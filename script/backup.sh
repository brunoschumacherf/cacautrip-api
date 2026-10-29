#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
backup_dir="${BACKUP_DIR:-./storage/backups}"
mkdir -p "$backup_dir"
backup_file="$backup_dir/cacautrip-$(date -u +%Y%m%dT%H%M%SZ).dump"
docker compose exec -T db pg_dump -U postgres -d cacautrip_development -Fc > "$backup_file"
printf 'Backup salvo: %s\n' "$backup_file"