#!/usr/bin/env bash
# Copy Illostrator's own files over a VectorCraft checkout (the app icon) and note the fork in NOTICE.
#
#   layer/overlay.sh <vectorcraft checkout>
set -euo pipefail
LAYER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$1"

cp -R "$LAYER/overlay/." .

if ! head -1 NOTICE | grep -qx 'Illostrator'; then
  {
    printf 'Illostrator\n'
    printf 'Illostrator is a modified fork of VectorCraft (https://github.com/storytold/vectorcraft):\n'
    printf "the product name, app icon, Help links and update check were changed. VectorCraft's notice follows.\n\n"
    cat NOTICE
  } > NOTICE.illostrator
  mv NOTICE.illostrator NOTICE
fi
