#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -f /workspace/.underworld-dev/env.sh ]; then source /workspace/.underworld-dev/env.sh; fi
task_build_logs="$(mktemp -d)"
trap 'rm -rf "$task_build_logs"' EXIT
godot --headless --path . --editor --import --quit > "$task_build_logs/import.log" 2>&1
if rg -q 'SCRIPT ERROR|^ERROR:' "$task_build_logs/import.log"; then cat "$task_build_logs/import.log"; exit 1; fi
for suite in run_tests members_tests city_tests navigation_tests ui_smoke mobile_tests; do
  if ! timeout 90 godot --headless --path . --script "tests/$suite.gd" > "$task_build_logs/$suite.log" 2>&1; then cat "$task_build_logs/$suite.log"; exit 1; fi
  if rg -q 'SCRIPT ERROR|^ERROR:|FAIL:' "$task_build_logs/$suite.log" || ! rg -q 'TESTS: [1-9][0-9]* checks, 0 failures' "$task_build_logs/$suite.log"; then cat "$task_build_logs/$suite.log"; exit 1; fi
  rg 'TESTS:' "$task_build_logs/$suite.log"
done
mkdir -p builds
if ! godot --headless --path . --export-debug 'Android Prototype' builds/underworld-android-debug.apk > "$task_build_logs/export.log" 2>&1; then tail -40 "$task_build_logs/export.log"; exit 1; fi
if rg -q 'SCRIPT ERROR|^ERROR:' "$task_build_logs/export.log"; then tail -40 "$task_build_logs/export.log"; exit 1; fi
if [ "${1:-}" = "--emulator" ]; then
  if ! godot --headless --path . --export-debug 'Android Emulator' builds/underworld-emulator-debug.apk > "$task_build_logs/emulator.log" 2>&1; then tail -40 "$task_build_logs/emulator.log"; exit 1; fi
  if rg -q 'SCRIPT ERROR|^ERROR:' "$task_build_logs/emulator.log"; then tail -40 "$task_build_logs/emulator.log"; exit 1; fi
fi
(cd builds && sha256sum underworld-android-debug.apk > underworld-android-debug.apk.sha256)
printf 'Android phone package built: builds/underworld-android-debug.apk\n'
