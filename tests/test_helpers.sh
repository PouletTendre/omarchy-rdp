#!/usr/bin/env bash
# Test helper utilities

set -euo pipefail

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

setup_test_env() {
  TEST_DIR="$(mktemp -d /tmp/omarchy-rdp-test.XXXXXX)"
  export XDG_CONFIG_HOME="$TEST_DIR/config"
  mkdir -p "$XDG_CONFIG_HOME"
  
  MOCK_BIN_DIR="$TEST_DIR/bin"
  mkdir -p "$MOCK_BIN_DIR"
  export PATH="$MOCK_BIN_DIR:$PATH"

  # Default mock xfreerdp3
  cat << 'MOCK_EOF' > "$MOCK_BIN_DIR/xfreerdp3"
#!/usr/bin/env bash
echo "xfreerdp3 cli: $@" >> "$XDG_CONFIG_HOME/mock_xfreerdp3.log"
if [[ "$*" == *"/args-from:fd:3"* ]]; then
  fd_content="$(cat <&3)"
  echo "xfreerdp3 fd3: $fd_content" >> "$XDG_CONFIG_HOME/mock_xfreerdp3.log"
else
  echo "xfreerdp3 invoked with: $@" >> "$XDG_CONFIG_HOME/mock_xfreerdp3.log"
fi
exit 0
MOCK_EOF
  chmod +x "$MOCK_BIN_DIR/xfreerdp3"
}

cleanup_test_env() {
  if [[ -n "${TEST_DIR:-}" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-Values do not match}"
  TEST_COUNT=$((TEST_COUNT + 1))
  if [[ "$expected" == "$actual" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  ✓ $msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  ✗ $msg"
    echo "    Expected: '$expected'"
    echo "    Actual:   '$actual'"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-Output does not contain substring}"
  TEST_COUNT=$((TEST_COUNT + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  ✓ $msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  ✗ $msg"
    echo "    Needle:   '$needle'"
    echo "    Haystack: '$haystack'"
  fi
}

report_results() {
  echo ""
  echo "Tests run: $TEST_COUNT | Passed: $PASS_COUNT | Failed: $FAIL_COUNT"
  if (( FAIL_COUNT > 0 )); then
    return 1
  fi
  return 0
}
