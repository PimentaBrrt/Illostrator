#!/usr/bin/env bash
# Rename VectorCraft to Illostrator in a VectorCraft checkout: every case-sensitive "VectorCraft" in
# the Rust sources and the translation catalogs, so the English keys (`tl!("…")`) and the .tsv rows
# stay in step. Lowercase `vectorcraft` (crate names, the exe, env vars, the `.vectorcraft` file
# extension, the app id) and the `VectorcraftApp` type are kept.
#
#   layer/rename.sh <vectorcraft checkout>
#
# Left alone, because there the text is data rather than the product name on screen:
#   crates/engine/src/cmd/fileio/tests_aiimport.rs   a test font named "VectorCraftTestUnnamed",
#                                                    shown split at its capitals ("Vector Craft")
#   crates/ui-egui/src/tests/saveext.rs              `.VectorCraft`, the file extension in mixed case
set -euo pipefail
cd "$1"

grep -rlI "VectorCraft" crates apps --include='*.rs' --include='*.tsv' \
  | grep -v '^crates/engine/src/cmd/fileio/tests_aiimport.rs$' \
  | grep -v '^crates/ui-egui/src/tests/saveext.rs$' \
  | xargs -r sed -i 's/VectorCraft/Illostrator/g'
