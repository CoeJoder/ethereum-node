#!/bin/bash

# lint.sh
#
# Runs `shellcheck` on all of the bash scripts in this project.

proj_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"

"$proj_dir/external/bash-tools/test/lint.sh" \
  --path "$proj_dir/src" \
  --path "$proj_dir/tools" \
  --path "$proj_dir/test"
