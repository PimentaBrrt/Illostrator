#!/usr/bin/env bash
# Turn a VectorCraft commit into the Illostrator source tree, as commits on a detached HEAD in <dir>:
#
#   1. BASE (the VectorCraft commit illostrator.patch was made on) + rename.sh   "Illostrator: rename (base)"
#   2. + illostrator.patch                                                      "Illostrator: layer"
#   3. <ref> + rename.sh                                                     "Illostrator: rename"
#      + cherry-pick of 2, a real 3-way merge against 1
#   4. + overlay.sh (app icon, NOTICE)                                       "Illostrator: icon and notice"
#
#   layer/build-tree.sh <dir> [ref]      ref: a VectorCraft branch or commit (default: main)
#
# <dir> is cloned when it doesn't exist. Its working tree must be clean (uncommitted changes would
# be lost). When the cherry-pick conflicts, the script stops with an error and nothing is built:
# fix it by hand, then regenerate the patch on the newer base with make-patch.sh.
set -euo pipefail
LAYER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$1"
REF="${2:-main}"
BASE="$(cat "$LAYER/BASE")"
URL="https://github.com/storytold/vectorcraft.git"

if [ ! -d "$DIR/.git" ]; then
  git init -q "$DIR"
  git -C "$DIR" remote add upstream "$URL"
fi
cd "$DIR"
git config core.autocrlf false
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$URL"
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "error: $DIR has uncommitted changes; commit or discard them first" >&2
  exit 1
fi

commit() { git -c user.name="Illostrator layer" -c user.email="illostrator@users.noreply.github.com" commit -q --no-verify "$@"; }
# A fresh or shallow clone fetches single commits; a full clone fetches normally.
depth=()
if [ "$(git rev-parse --is-shallow-repository)" = true ] || ! git rev-parse -q --verify HEAD >/dev/null; then depth=(--depth=1); fi

git cat-file -e "$BASE^{commit}" 2>/dev/null || git fetch -q "${depth[@]}" upstream "$BASE"
git fetch -q "${depth[@]}" upstream "$REF"
TARGET="$(git rev-parse FETCH_HEAD)"

git checkout -q -f --detach "$BASE"
"$LAYER/rename.sh" .
commit -am "Illostrator: rename (base)"
git apply --index "$LAYER/illostrator.patch"
commit -m "Illostrator: layer"
LAYER_COMMIT="$(git rev-parse HEAD)"
git update-ref refs/illostrator/layer "$LAYER_COMMIT"

git checkout -q -f --detach "$TARGET"
"$LAYER/rename.sh" .
commit -am "Illostrator: rename"
if ! git -c user.name="Illostrator layer" -c user.email="illostrator@users.noreply.github.com" cherry-pick "$LAYER_COMMIT" >/dev/null; then
  git diff --name-only --diff-filter=U | sed 's/^/conflict: /' >&2
  git cherry-pick --abort
  echo "error: illostrator.patch no longer applies to VectorCraft $TARGET; see \"Quando o patch para de aplicar\" in README.md" >&2
  exit 1
fi

"$LAYER/overlay.sh" .
git add -A assets/app-icon NOTICE
commit -m "Illostrator: icon and notice"
echo "Illostrator tree ready in $DIR: VectorCraft $TARGET"
