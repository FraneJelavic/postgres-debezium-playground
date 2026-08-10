#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials
require_commands docker jq rg shellcheck bash

find "${root_dir}/scripts" -type f -name '*.sh' -print0 \
  | while IFS= read -r -d '' script; do bash -n "$script"; done

shellcheck "${root_dir}"/scripts/*.sh "${root_dir}"/images/postgres-patroni/entrypoint.sh
jq empty "${root_dir}"/config/debezium/connector.template.json
compose config --quiet

if rg -n --hidden --glob '!.git/**' --glob '!.state/**' \
  'BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|AKIA[0-9A-Z]{16}' "${root_dir}"; then
  printf 'Potential secret material found.\n' >&2
  exit 1
fi

if rg -n --hidden --glob '!.git/**' --glob '!.state/**' \
  'docker\.ib-ci\.com|git\.ib-ci\.com|confluence\.infobip\.com|jira\.infobip\.com|serena\.infobip\.com' "${root_dir}"; then
  printf 'A prohibited private marker was found.\n' >&2
  exit 1
fi

compose config --format json \
  | jq -e '[.services[].ports[]? | select(.host_ip != "127.0.0.1")] | length == 0' >/dev/null || {
    printf 'A host port is not bound explicitly to loopback.\n' >&2
    exit 1
  }

mode=$(stat -f '%Lp' "${credentials_file}" 2>/dev/null || stat -c '%a' "${credentials_file}")
[[ "${mode}" == 600 ]] || {
  printf 'Credential file mode is %s, expected 600.\n' "${mode}" >&2
  exit 1
}

printf 'Static checks passed.\n'
