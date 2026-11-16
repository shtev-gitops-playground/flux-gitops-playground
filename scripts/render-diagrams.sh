#!/usr/bin/env bash
# Renders docs/diagrams/*.mmd to SVG, a light and a dark version of each, for the README.
# Uses Mermaid's own CLI in Docker. Rerun after editing a .mmd file and commit the SVGs.
#   scripts/render-diagrams.sh
set -euo pipefail
cd "$(dirname "$0")/../docs/diagrams"

IMAGE=minlag/mermaid-cli:12.0.1

for src in *.mmd; do
  name=${src%.mmd}
  for theme in default dark; do
    out=$name.svg config=mermaid-config.json
    [[ $theme == dark ]] && out=$name-dark.svg config=mermaid-config-dark.json
    docker run --rm -v "$PWD:/data" "$IMAGE" \
      -i "/data/$src" -o "/data/$out" -t "$theme" -b transparent -c "/data/$config" >/dev/null
    echo "rendered $out"
  done
done
