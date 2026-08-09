#!/usr/bin/env bash
set -Eeuo pipefail

: "${DEBEZIUM_PASSWORD:?DEBEZIUM_PASSWORD is required}"

connector_name=playground-outbox-connector
connect_url=http://connect:8083
rendered_config=/tmp/connector.json
config_only=/tmp/connector-config.json

sed "s/__DEBEZIUM_PASSWORD__/${DEBEZIUM_PASSWORD}/g" \
  /config/debezium/connector.template.json > "$config_only"

if curl --fail --silent "$connect_url/connectors/$connector_name" >/dev/null 2>&1; then
  curl --fail --silent --show-error \
    --request PUT \
    --header 'Content-Type: application/json' \
    --data-binary "@$config_only" \
    "$connect_url/connectors/$connector_name/config" >/dev/null
  curl --fail --silent --show-error \
    --request POST \
    "$connect_url/connectors/$connector_name/restart?includeTasks=true&onlyFailed=true" >/dev/null
else
  {
    printf '{"name":"%s","config":' "$connector_name"
    cat "$config_only"
    printf '}\n'
  } > "$rendered_config"
  curl --fail --silent --show-error \
    --request POST \
    --header 'Content-Type: application/json' \
    --data-binary "@$rendered_config" \
    "$connect_url/connectors" >/dev/null
fi

deadline=$((SECONDS + 120))
while (( SECONDS < deadline )); do
  status=$(curl --fail --silent "$connect_url/connectors/$connector_name/status" || true)
  if [[ "$status" == *'"connector":{"state":"RUNNING"'* ]] \
    && [[ "$status" == *'"tasks":[{"id":0,"state":"RUNNING"'* ]]; then
    printf 'Connector %s is RUNNING.\n' "$connector_name"
    exit 0
  fi
  sleep 2
done

printf 'Timed out waiting for connector: %s\n' "$status" >&2
exit 1
