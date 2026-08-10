#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib.sh
source "$script_dir/lib.sh"
load_credentials
require_commands bash docker git grep jq shellcheck

scan_repository() {
  local pattern=$1 file status matched=1
  while IFS= read -r -d '' file; do
    if grep -nHIE "$pattern" "$root_dir/$file"; then
      matched=0
    else
      status=$?
      (( status == 1 )) || return "$status"
    fi
  done < <(git -C "$root_dir" ls-files --cached --others --exclude-standard -z)
  return "$matched"
}

find "${root_dir}/scripts" -type f -name '*.sh' -print0 \
  | while IFS= read -r -d '' script; do bash -n "$script"; done

shellcheck "${root_dir}"/scripts/*.sh "${root_dir}"/images/postgres-patroni/entrypoint.sh
jq empty "${root_dir}"/config/debezium/connector.template.json
compose config --quiet

if scan_repository \
  'BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|AKIA[0-9A-Z]{16}'; then
  printf 'Potential secret material found.\n' >&2
  exit 1
fi

if scan_repository \
  'docker\.ib-ci\.com|git\.ib-ci\.com|confluence\.infobip\.com|jira\.infobip\.com|serena\.infobip\.com'; then
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
