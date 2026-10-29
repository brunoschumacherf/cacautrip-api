#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
if [[ "${1:-}" != '--reset' || "$#" != 1 ]]; then
  printf 'Uso: bash script/rebuild_remote_demo_data.sh --reset\nApaga e recria a base cacautrip do Render, após backup.\n' >&2
  exit 2
fi
api_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
workspace_dir="$(dirname -- "$api_dir")"
cd -- "$api_dir"
compose=(docker compose --project-directory "$api_dir" -f "$api_dir/docker-compose.yml")
mkdir -p storage/backups
backup_dir="$(mktemp -d "$api_dir/storage/backups/render-demo-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
trap 'printf "Recriação interrompida. Backup e registros desta execução: %s\n" "$backup_dir" >&2' ERR

# O arquivo privado é preparado a partir da mesma URL usada pelo Compose.
# Credenciais são transmitidas ao pg_dump por ambiente, sem URL nos argumentos.
docker run --rm --user "$(id -u):$(id -g)" \
  --env-file "$api_dir/.env.remote-seed" \
  --volume "$backup_dir:/backup" \
  postgres:18-alpine pg_dump --format=custom --file=/backup/database.dump
[[ -s "$backup_dir/database.dump" ]]
if [[ -f "$workspace_dir/notes.md" ]]; then cp -p "$workspace_dir/notes.md" "$backup_dir/notes.md"; fi
printf 'Backup concluído: %s\n' "$backup_dir"

"${compose[@]}" run --rm --no-deps \
  --volume "$workspace_dir:/workspace" \
  --env RAILS_ENV=development \
  --env ALLOW_REMOTE_DEMO_RESET=cacautrip \
  --env RESET_DATABASE=cacautrip \
  --env NOTES_PATH=/workspace/notes.md \
  --env SEED_GEOCODE=1 \
  web bash -ceu '
    bundle exec rails runner script/reset_development_data.rb
    bundle exec rails db:prepare
    bundle exec rails runner script/seed_demo_data.rb
  '
printf '\nBase remota recriada. Acessos e códigos: %s/notes.md\nBackup: %s\n' "$workspace_dir" "$backup_dir"
