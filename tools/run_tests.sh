#!/usr/bin/env bash
# Runs THE LAST SIGNAL's automated headless test suite.
#
# Usage:
#   tools/run_tests.sh                      # uses `godot` from PATH
#   GODOT=/path/to/Godot_v4.7.2 tools/run_tests.sh
#   tools/run_tests.sh --suite=gameplay     # only suites whose file name contains "gameplay"
#
# Step 1 (--import) builds Godot's .godot/ cache (global class names, imports); it is
# required on a fresh clone. Step 2 runs every suite; exit code 0 means all checks passed.
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd -- "$@"
