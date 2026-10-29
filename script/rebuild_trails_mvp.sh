#!/usr/bin/env bash
set -euo pipefail
cd /home/afoxavier/cacautrip/cacautrip-api
docker compose up -d db
docker compose stop web maintenance
mkdir -p storage/backups
backup_file="storage/backups/before-guide-trails-$(date -u +%Y%m%dT%H%M%SZ).dump"
docker compose exec -T db pg_dump -U postgres -d cacautrip_development -Fc > "$backup_file"
[[ -s "$backup_file" ]] || { printf 'Backup vazio; limpeza cancelada.\n' >&2; exit 1; }
printf 'Backup salvo: %s\n' "$backup_file"
docker compose run --rm --no-deps -v /home/afoxavier/cacautrip:/workspace -e RAILS_ENV=development -e DATABASE_URL=postgresql://postgres:postgres@db:5432/cacautrip_development -e RESET_DATABASE=cacautrip_development -e NOTES_PATH=/workspace/notes.md web bash -c 'bundle exec rails runner script/reset_development_data.rb && bundle exec rails db:migrate && bundle exec rails runner script/seed_trails_mvp.rb'
docker compose up -d web maintenance
printf 'Banco de desenvolvimento renovado; API e manutenção reiniciadas.\n'