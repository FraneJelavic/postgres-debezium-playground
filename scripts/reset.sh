#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials

printf 'This will remove Compose project %s and these project volumes:\n' "$COMPOSE_PROJECT_NAME"
docker volume ls \
  --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME" \
  --format '  {{.Name}}'
printf 'It will also remove %s.\n' "$credentials_file"

if [[ "${CONFIRM_RESET:-}" != YES ]]; then
  read -r -p "Type the exact project name '$COMPOSE_PROJECT_NAME' to continue: " confirmation
  [[ "$confirmation" == "$COMPOSE_PROJECT_NAME" ]] || {
    printf 'Reset cancelled.\n'
    exit 1
  }
fi

compose down --volumes --remove-orphans
rm -f "$credentials_file"
printf 'Reset complete. Removed project volumes and generated credentials.\n'
