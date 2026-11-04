#!/usr/bin/env bash
# Local desktop build (Linux x86_64): tools/ci/setup_godot.sh --templates && tools/ci/build_desktop.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/linux
godot --headless --path . --import || true
godot --headless --path . --import
godot --headless --path . --export-release "Linux" build/linux/corporate-ladder.x86_64
ls -la build/linux
