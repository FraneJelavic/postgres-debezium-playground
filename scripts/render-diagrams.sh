#!/usr/bin/env bash
set -Eeuo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build_dir="$root_dir/.state/c4-render"
output_dir="$root_dir/docs/c4"
check_only=0

if [[ ${1-} == --check ]]; then
  check_only=1
elif [[ $# -ne 0 ]]; then
  printf 'Usage: %s [--check]\n' "$0" >&2
  exit 2
fi

command -v docker >/dev/null 2>&1 || {
  printf 'docker is required to render C4 diagrams.\n' >&2
  exit 1
}

structurizr_image='structurizr/cli:2025.11.09@sha256:0399ac8e24c16e41277cfcec22caa29e4775013e5395c0720016828426d62749'
plantuml_image='plantuml/plantuml:1.2026.6@sha256:47870c1f76cfb3747bc7090bfe83013a4e3105b5a0bb1515e2baf5d3e2b3ee9d'

mkdir -p "$build_dir" "$output_dir"
find "$build_dir" -mindepth 1 -maxdepth 1 -delete

docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$root_dir:/usr/local/structurizr" \
  "$structurizr_image" export \
  -workspace docs/c4/src/workspace.dsl \
  -format plantuml/structurizr \
  -output .state/c4-render

shopt -s nullglob
sources=("$build_dir"/*.puml)
shopt -u nullglob
diagram_sources=()
for source in "${sources[@]}"; do
  [[ "$source" == *-key.puml ]] || diagram_sources+=("$source")
done
[[ ${#diagram_sources[@]} -eq 2 ]] || {
  printf 'Expected two exported diagram files, found %s.\n' "${#diagram_sources[@]}" >&2
  exit 1
}

source_names=()
for source in "${diagram_sources[@]}"; do
  source_names+=("$(basename "$source")")
done

docker run --rm \
  --user "$(id -u):$(id -g)" \
  --env PLANTUML_LIMIT_SIZE=8192 \
  --volume "$build_dir:/data" \
  "$plantuml_image" -tpng "${source_names[@]}"

context_png=$(find "$build_dir" -maxdepth 1 -type f -name '*context.png' -print -quit)
containers_png=$(find "$build_dir" -maxdepth 1 -type f -name '*containers.png' -print -quit)
[[ -n "$context_png" && -n "$containers_png" ]] || {
  printf 'Rendered context or container PNG was not found.\n' >&2
  exit 1
}

if (( check_only == 1 )); then
  cmp -s "$context_png" "$output_dir/context.png" || {
    printf 'docs/c4/context.png is stale; run make diagrams.\n' >&2
    exit 1
  }
  cmp -s "$containers_png" "$output_dir/containers.png" || {
    printf 'docs/c4/containers.png is stale; run make diagrams.\n' >&2
    exit 1
  }
  printf 'C4 diagrams are current.\n'
else
  install -m 0644 "$context_png" "$output_dir/context.png"
  install -m 0644 "$containers_png" "$output_dir/containers.png"
  printf 'Rendered C4 diagrams in %s.\n' "$output_dir"
fi
