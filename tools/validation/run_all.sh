#!/usr/bin/env bash
# Everything CI runs: import, headless tests, optional bot playthrough.   tools/validation/run_all.sh [--playthrough]
set -euo pipefail
cd "$(dirname "$0")/../.."
godot --headless --path . --import || godot --headless --path . --import
godot --headless --path . --fixed-fps 60 tests/run_tests.tscn
if [ "${1:-}" = "--playthrough" ]; then
  godot --headless --path . --fixed-fps 60 tests/playthrough.tscn -- --runs=3
fi
