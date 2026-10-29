#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

usage() {
  cat <<'HELP'
Uso: bash script/rebuild_demo_data.sh --reset [--build] [--no-geocode]
  --reset       Apaga e recria o banco LOCAL após salvar backup.
  --build       Reconstrói a imagem Rails antes de iniciar.
  --no-geocode  Não consulta o provedor de coordenadas.
  --help        Mostra esta ajuda.
Atualiza notes.md na raiz com contas, senhas, operadores, códigos e cupons.
Não executa testes nem build do Expo. Restrito a cacautrip_development.
HELP
}
reset=0
build=0
geocode=1
for argument in "$@"; do
  case "$argument" in
    --reset) reset=1 ;;
    --build) build=1 ;;
    --no-geocode) geocode=0 ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Opção desconhecida: %s\n' "$argument" >&2; usage; exit 2 ;;
  esac
done
if [[ "$reset" != 1 ]]; then usage; exit 2; fi

api_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
workspace_dir="$(dirname -- "$api_dir")"
cd -- "$api_dir"
compose=(docker compose --project-directory "$api_dir" -f "$api_dir/docker-compose.yml")
database_url='postgresql://postgres:postgres@db:5432/cacautrip_development'
mkdir -p storage/backups
backup_dir="$(mktemp -d "$api_dir/storage/backups/demo-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
backup_file="$backup_dir/database.dump"
failed() {
  local status=$?
  printf '\nRecriação interrompida (código %s). Backup: %s\n' "$status" "$backup_dir" >&2
  printf 'Consulte o erro acima. Serviços parados não são reiniciados automaticamente após falha.\n' >&2
  exit "$status"
}
trap failed ERR

if [[ "$build" == 1 ]]; then "${compose[@]}" build web; fi
"${compose[@]}" up -d --wait db
"${compose[@]}" stop web maintenance
printf '\nSalvando backup antes de recriar a base...\n'
"${compose[@]}" exec -T db pg_dump -U postgres -d cacautrip_development --format=custom > "$backup_file"
if [[ ! -s "$backup_file" ]]; then printf 'Backup vazio; nenhum dado apagado.\n' >&2; exit 1; fi
if [[ -f "$workspace_dir/notes.md" ]]; then cp -p -- "$workspace_dir/notes.md" "$backup_dir/notes.md"; fi
printf 'Backup: %s\n' "$backup_dir"

"${compose[@]}" run --rm --no-deps \
  --volume "$workspace_dir:/workspace" \
  --env RAILS_ENV=development \
  --env "DATABASE_URL=$database_url" \
  --env RESET_DATABASE=cacautrip_development \
  --env NOTES_PATH=/workspace/notes.md \
  --env "SEED_GEOCODE=$geocode" \
  web bash -ceu '
    bundle exec rails runner script/reset_development_data.rb
    bundle exec rails db:prepare
    bundle exec rails runner script/seed_demo_data.rb
  '

"${compose[@]}" up -d web maintenance
printf '\nBase recriada e migrations aplicadas.\nAcessos: %s/notes.md\nBackup: %s\n' "$workspace_dir" "$backup_dir"
printf 'API: http://localhost:3000 | Gestão: http://localhost:3000/gestao\n'
