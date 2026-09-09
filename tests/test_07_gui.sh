#!/usr/bin/env bash
# Integration test for Ticket 04: GUI system integration, .desktop files & cross-compatibility

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

APP="$SCRIPT_DIR/../bin/omarchy-rdp"
APP_GUI="$SCRIPT_DIR/../bin/omarchy-rdp-gui"
DESKTOP_DIR="$SCRIPT_DIR/../desktop"

echo "Running Ticket 07 GUI integration tests..."
setup_test_env
trap cleanup_test_env EXIT

# 1. Verify bin/omarchy-rdp-gui executable
assert_eq "true" "$([[ -x "$APP_GUI" ]] && echo true || echo false)" "omarchy-rdp-gui has executable permissions"

gui_help="$("$APP_GUI" --help 2>&1 || true)"
assert_contains "$gui_help" "Application options" "Direct GUI binary outputs application options"

# 2. Verify omarchy-rdp --gui delegation
cli_gui_help="$("$APP" --gui --help 2>&1 || true)"
assert_contains "$cli_gui_help" "Application options" "omarchy-rdp --gui delegates to GUI binary"

# 3. Verify .desktop file syntax and fields
if command -v desktop-file-validate >/dev/null 2>&1; then
  val_out="$(desktop-file-validate "$DESKTOP_DIR/omarchy-rdp.desktop" "$DESKTOP_DIR/omarchy-rdp-tui.desktop" 2>&1 || true)"
  assert_eq "" "$val_out" "desktop-file-validate reports no errors on .desktop files"
fi

desktop_content="$(cat "$DESKTOP_DIR/omarchy-rdp.desktop")"
assert_contains "$desktop_content" "Exec=omarchy-rdp-gui" "omarchy-rdp.desktop executes omarchy-rdp-gui"
assert_contains "$desktop_content" "Terminal=false" "omarchy-rdp.desktop has Terminal=false"

desktop_tui_content="$(cat "$DESKTOP_DIR/omarchy-rdp-tui.desktop")"
assert_contains "$desktop_tui_content" "Exec=foot --app-id=omarchy-rdp -e omarchy-rdp" "omarchy-rdp-tui.desktop executes foot TUI"
assert_contains "$desktop_tui_content" "Terminal=false" "omarchy-rdp-tui.desktop has Terminal=false"

# 4. Cross-compatibility: Profile added via CLI is readable by Python ProfileManager
"$APP" --add '{"name":"CliProfile","host":"10.0.1.10","port":3389,"username":"cliuser","domain":"WORK","sound":true,"clipboard":true}'

py_check="$(python3 -c '
import os, sys
sys.path.insert(0, "'"$SCRIPT_DIR/../lib"'")
from gui import ProfileManager
pm = ProfileManager("'"$XDG_CONFIG_HOME/omarchy-rdp"'")
p = pm.get_profile("CliProfile")
if p and p.get("host") == "10.0.1.10" and p.get("domain") == "WORK":
    print("MATCH")
')"
assert_eq "MATCH" "$py_check" "Profile created by CLI is cleanly read by Python GUI ProfileManager"

# 5. Cross-compatibility: Profile added via Python ProfileManager is readable by CLI
python3 -c '
import os, sys
sys.path.insert(0, "'"$SCRIPT_DIR/../lib"'")
from gui import ProfileManager
pm = ProfileManager("'"$XDG_CONFIG_HOME/omarchy-rdp"'")
pm.save_profile({
    "name": "GuiProfile",
    "host": "10.0.2.20",
    "port": 3390,
    "username": "guiuser",
    "domain": "CORP",
    "sound": True,
    "clipboard": True,
    "dynamic_resolution": True
})
'

cli_list="$("$APP" --list)"
assert_contains "$cli_list" "GuiProfile" "Profile created by GUI is listed in CLI --list"

cli_host="$("$APP" --get "GuiProfile" | jq -r .host)"
assert_eq "10.0.2.20" "$cli_host" "CLI --get retrieves host from GUI profile"

cli_port="$("$APP" --get "GuiProfile" | jq -r .port)"
assert_eq "3390" "$cli_port" "CLI --get retrieves port from GUI profile"

cli_args="$("$APP" --get-args "GuiProfile")"
assert_contains "$cli_args" "/v:10.0.2.20:3390" "CLI --get-args formats host/port from GUI profile"
assert_contains "$cli_args" "/u:guiuser" "CLI --get-args formats username from GUI profile"
assert_contains "$cli_args" "/d:CORP" "CLI --get-args formats domain from GUI profile"

report_results
