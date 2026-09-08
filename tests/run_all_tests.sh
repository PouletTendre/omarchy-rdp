#!/usr/bin/env bash
# Test runner for all omarchy-rdp integration tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "   Running omarchy-rdp Test Suite"
echo "========================================="

# 1. Syntax check
echo "Checking bash syntax across codebase..."
bash -n "$SCRIPT_DIR/../bin/omarchy-rdp" "$SCRIPT_DIR/../lib/"*.sh "$SCRIPT_DIR/"*.sh "$SCRIPT_DIR/../install.sh"
echo "✓ Syntax OK"
echo ""

# 2. Run all individual test scripts
for test_file in "$SCRIPT_DIR"/test_*.sh; do
  [[ "$test_file" == *"test_helpers.sh"* ]] && continue
  echo ">>> Running $(basename "$test_file")..."
  "$test_file"
  echo ""
done

echo "========================================="
echo "   All tests passed successfully!"
echo "========================================="
