#!/usr/bin/env bash
# Test runner for all omarchy-rdp integration tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "   Running omarchy-rdp Test Suite"
echo "========================================="

# 1. Syntax check
echo "Checking bash syntax across codebase..."
bash -n "$SCRIPT_DIR/../bin/omarchy-rdp" "$SCRIPT_DIR/../bin/omarchy-rdp-gui" "$SCRIPT_DIR/../lib/"*.sh "$SCRIPT_DIR/"*.sh "$SCRIPT_DIR/../install.sh" "$SCRIPT_DIR/../uninstall.sh"
echo "✓ Syntax OK"
echo ""

# 2. Run all individual test scripts
for test_file in "$SCRIPT_DIR"/test_*.sh; do
  [[ "$test_file" == *"test_helpers.sh"* ]] && continue
  echo ">>> Running $(basename "$test_file")..."
  "$test_file"
  echo ""
done

# 3. Run Python GUI test suite
if command -v xvfb-run >/dev/null 2>&1; then
  echo ">>> Running test_gui.py under xvfb..."
  xvfb-run -a python3 "$SCRIPT_DIR/test_gui.py"
  echo ""
elif [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
  echo ">>> Running test_gui.py..."
  python3 "$SCRIPT_DIR/test_gui.py"
  echo ""
fi

echo "========================================="
echo "   All tests passed successfully!"
echo "========================================="
