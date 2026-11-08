#!/usr/bin/env bash
# Executa os testes automatizados do Urban Riders.
# Uso: ./tests/run_tests.sh            (procura a Godot no PATH ou em /Applications)
#      GODOT=/caminho/godot ./tests/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --fixed-fps 60 -s res://tests/run_tests.gd 2>&1 \
  | grep -v -E 'mesh_storage|Parameter "m" is null'
exit "${PIPESTATUS[0]}"
