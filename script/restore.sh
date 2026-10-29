#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
backup_file="${1:?Informe o caminho do backup .dump}"
[[ -f "$backup_file" ]] || { printf 'Arquivo não encontrado.\n' >&2; exit 1; }
printf 'A restauração substituirá o banco de desenvolvimento. Digite RESTAURAR para continuar: '
read -r confirmation
[[ "$confirmation" == 'RESTAURAR' ]] || exit 1
docker compose exec -T db pg_restore --clean --if-exists --no-owner -U postgres -d cacautrip_development < "$backup_file"
printf 'Restauração concluída.\n'