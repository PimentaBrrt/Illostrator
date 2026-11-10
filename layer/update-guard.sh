#!/usr/bin/env bash
# Fail when a tree made by build-tree.sh checks VectorCraft's releases outside what the layer
# stubs. Illostrator updates through install/atualizar.ps1: such a check would offer to replace
# Illostrator with VectorCraft.
#
#   layer/update-guard.sh <dir>
#
# Looks for the calls that start a check (craft-update's check_at_start, check_now and
# check_for_update) in the app's code; tests are left out (test modules, tests.rs files, tests/
# folders and #[cfg(test)] items), as their updaters never reach the network. A call that can't
# start a check goes in ALLOWED, with the reason.
set -euo pipefail
cd "$1"

# file:code pairs (the code trimmed).
ALLOWED=(
  # The result window's Check Again: it only shows while a check is under way, and none starts.
  "crates/ui-egui/src/updates_ui.rs:CheckResultResponse::CheckAgain => rt.updater.check_now(ctx),"
)

found=$(grep -rlE '\.check_at_start\(|\.check_now\(|check_for_update\(' apps crates --include='*.rs' \
  | grep -vE '(^|/)tests(/|\.rs$)|_tests\.rs$' || true)
calls=$(for f in $found; do
  awk -v file="$f" '
    /^(pub(\([a-z]+\))? )?mod tests/ { exit }
    /#\[cfg\((all\()?test/ { attr = FNR }
    /\.check_at_start\(|\.check_now\(|check_for_update\(/ && !(attr && FNR - attr <= 3) {
      code = $0; sub(/^[ \t]+/, "", code); print file ":" code
    }' "$f"
done)

bad=0
while IFS= read -r call; do
  [ -n "$call" ] || continue
  ok=0
  for a in "${ALLOWED[@]}"; do [ "$call" = "$a" ] && ok=1; done
  if [ "$ok" = 0 ]; then echo "$call"; bad=1; fi
done <<< "$calls"
if [ "$bad" = 1 ]; then
  echo "::error::VectorCraft checks for updates outside the layer's stub; see the calls above"
  exit 1
fi
echo "No update check outside the layer's stub."
