#!/usr/bin/env bash
# Save the code changes in a tree made by build-tree.sh as the new illostrator.patch, based on the
# VectorCraft commit that tree came from. Use it after fixing a conflict or changing Illostrator's code.
#
#   layer/make-patch.sh <dir>
#
# The patch is everything that differs from "Illostrator: rename" (VectorCraft + rename.sh), committed
# or not, except the files overlay.sh owns (the app icon and NOTICE).
set -euo pipefail
LAYER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$1"

RENAME="$(git log --format=%H -1 --grep='^Illostrator: rename$')"
[ -n "$RENAME" ] || { echo "error: no \"Illostrator: rename\" commit in $1; run build-tree.sh first" >&2; exit 1; }
git diff "$RENAME" -- . ':(exclude)assets/app-icon' ':(exclude)NOTICE' > "$LAYER/illostrator.patch"
git rev-parse "$RENAME^" > "$LAYER/BASE"
echo "illostrator.patch: $(grep -c '^diff --git' "$LAYER/illostrator.patch") files, based on VectorCraft $(cat "$LAYER/BASE")"
