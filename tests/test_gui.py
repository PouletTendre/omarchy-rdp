#!/usr/bin/env python3
"""Tests for Ticket 01: Core GUI Window, Profile Listing & Real-time Search."""

import json
import os
import shutil
import sys
import tempfile
import unittest

# Add lib directory to path
LIB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "lib"))
sys.path.insert(0, LIB_DIR)

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw

from gui import (
    ProfileManager,
    MainWindow,
    RdpGuiApp,
    KeyringManager,
    SessionManager,
    ProfileFormDialog,
)


class TestProfileManager(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="omarchy-rdp-gui-test-")
        self.config_dir = os.path.join(self.test_dir, "omarchy-rdp")
        os.makedirs(self.config_dir, exist_ok=True)
        self.profiles_file = os.path.join(self.config_dir, "profiles.json")

    def tearDown(self):
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_list_profiles_empty_when_no_file(self):
        pm = ProfileManager(config_dir=self.config_dir)
        self.assertEqual(pm.list_profiles(), [])

    def test_list_profiles_loads_valid_json(self):
        sample_data = [
            {"name": "DevBox", "host": "192.168.1.50", "port": 3389, "username": "devuser"},
            {"name": "ProdServer", "host": "10.0.0.1", "port": 3389, "username": "admin"},
        ]
        with open(self.profiles_file, "w") as f:
            json.dump(sample_data, f)

        pm = ProfileManager(config_dir=self.config_dir)
        profiles = pm.list_profiles()
        self.assertEqual(len(profiles), 2)
        self.assertEqual(profiles[0]["name"], "DevBox")
        self.assertEqual(profiles[1]["name"], "ProdServer")

    def test_filter_profiles_matches_name_host_and_user(self):
        sample_data = [
            {"name": "AlphaHost", "host": "10.0.0.10", "username": "alice"},
            {"name": "BetaHost", "host": "10.0.0.20", "username": "bob"},
            {"name": "GammaDev", "host": "192.168.1.30", "username": "charlie"},
        ]
        with open(self.profiles_file, "w") as f:
            json.dump(sample_data, f)

        pm = ProfileManager(config_dir=self.config_dir)
        # Search by name
        res = pm.filter_profiles("alpha")
        self.assertEqual([p["name"] for p in res], ["AlphaHost"])

        # Search by IP
        res = pm.filter_profiles("192.168")
        self.assertEqual([p["name"] for p in res], ["GammaDev"])

        # Search by username
        res = pm.filter_profiles("BOB")
        self.assertEqual([p["name"] for p in res], ["BetaHost"])

        # Empty search returns all
        res = pm.filter_profiles("")
        self.assertEqual(len(res), 3)


class TestMainWindow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Adw.init()

    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="omarchy-rdp-window-test-")
        self.config_dir = os.path.join(self.test_dir, "omarchy-rdp")
        os.makedirs(self.config_dir, exist_ok=True)
        self.profiles_file = os.path.join(self.config_dir, "profiles.json")

        self.sample_data = [
            {"name": "DesktopWin", "host": "192.168.1.100", "port": 3389, "username": "noah"},
            {"name": "OfficeVM", "host": "10.10.10.5", "port": 3389, "username": "corpuser"},
        ]
        with open(self.profiles_file, "w") as f:
            json.dump(self.sample_data, f)

        self.pm = ProfileManager(config_dir=self.config_dir)
        self.app = Adw.Application(application_id="org.omarchy.rdp.test")
        self.window = MainWindow(application=self.app, profile_manager=self.pm)

    def tearDown(self):
        if hasattr(self, "window") and self.window:
            self.window.destroy()
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_window_populates_profile_rows(self):
        self.assertEqual(len(self.window.profile_rows), 2)
        row_names = [row.profile["name"] for row in self.window.profile_rows.values()]
        self.assertIn("DesktopWin", row_names)
        self.assertIn("OfficeVM", row_names)

    def test_window_search_filters_rows(self):
        self.window.search_entry.set_text("Office")
        # Trigger filter update
        visible_rows = [
            name for name, row in self.window.profile_rows.items()
            if row.get_visible()
        ]
        self.assertEqual(visible_rows, ["OfficeVM"])

    def test_empty_state_shown_when_no_profiles(self):
        empty_pm = ProfileManager(config_dir=os.path.join(self.test_dir, "empty"))
        empty_window = MainWindow(application=self.app, profile_manager=empty_pm)
        self.assertTrue(empty_window.status_page.get_visible())
        empty_window.destroy()


class TestKeyringManager(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="omarchy-rdp-keyring-test-")
        self.mock_bin = os.path.join(self.test_dir, "bin")
        os.makedirs(self.mock_bin, exist_ok=True)
        self.orig_path = os.environ.get("PATH", "")
        os.environ["PATH"] = f"{self.mock_bin}:{self.orig_path}"
        self.keyring_tsv = os.path.join(self.test_dir, "keyring.tsv")

        mock_secret = f"""#!/usr/bin/env bash
KEYRING_FILE="{self.keyring_tsv}"
touch "$KEYRING_FILE"
action="$1"
shift
TAB=$'\\t'
case "$action" in
  lookup)
    service=""
    profile=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        service) service="$2"; shift 2 ;;
        profile) profile="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    awk -F"$TAB" -v s="$service" -v p="$profile" '$1 == s && $2 == p {{ print $3 }}' "$KEYRING_FILE"
    ;;
  store)
    service=""
    profile=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --label=*) shift ;;
        service) service="$2"; shift 2 ;;
        profile) profile="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    secret="$(cat)"
    awk -F"$TAB" -v s="$service" -v p="$profile" '$1 != s || $2 != p' "$KEYRING_FILE" > "$KEYRING_FILE.tmp" || true
    mv "$KEYRING_FILE.tmp" "$KEYRING_FILE"
    printf '%s\\t%s\\t%s\\n' "$service" "$profile" "$secret" >> "$KEYRING_FILE"
    ;;
  clear)
    service=""
    profile=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        service) service="$2"; shift 2 ;;
        profile) profile="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    awk -F"$TAB" -v s="$service" -v p="$profile" '$1 != s || $2 != p' "$KEYRING_FILE" > "$KEYRING_FILE.tmp" || true
    mv "$KEYRING_FILE.tmp" "$KEYRING_FILE"
    ;;
esac
exit 0
"""
        script_path = os.path.join(self.mock_bin, "secret-tool")
        with open(script_path, "w") as f:
            f.write(mock_secret)
        os.chmod(script_path, 0o755)

    def tearDown(self):
        os.environ["PATH"] = self.orig_path
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_keyring_store_lookup_and_delete(self):
        self.assertIsNone(KeyringManager.get_password("TestHost"))
        self.assertTrue(KeyringManager.set_password("TestHost", "SecretPass123"))
        self.assertEqual(KeyringManager.get_password("TestHost"), "SecretPass123")
        self.assertTrue(KeyringManager.delete_password("TestHost"))
        self.assertIsNone(KeyringManager.get_password("TestHost"))


class TestSessionManager(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="omarchy-rdp-session-test-")
        self.config_dir = os.path.join(self.test_dir, "config", "omarchy-rdp")
        os.makedirs(self.config_dir, exist_ok=True)
        self.mock_bin = os.path.join(self.test_dir, "bin")
        os.makedirs(self.mock_bin, exist_ok=True)
        self.orig_path = os.environ.get("PATH", "")
        os.environ["PATH"] = f"{self.mock_bin}:{self.orig_path}"
        self.log_file = os.path.join(self.test_dir, "mock_xfreerdp3.log")
        self.notify_log = os.path.join(self.test_dir, "notify.log")

        # Mock xfreerdp3
        mock_xfreerdp = f"""#!/usr/bin/env bash
echo "CLI: $@" >> "{self.log_file}"
if [[ "$*" == *"/args-from:fd:3"* ]]; then
  fd_content="$(cat <&3)"
  echo "FD3: $fd_content" >> "{self.log_file}"
fi
if [[ -n "${{SLEEP_MOCK:-}}" ]]; then
  sleep "$SLEEP_MOCK"
fi
exit "${{EXIT_CODE:-0}}"
"""
        xf_path = os.path.join(self.mock_bin, "xfreerdp3")
        with open(xf_path, "w") as f:
            f.write(mock_xfreerdp)
        os.chmod(xf_path, 0o755)

        # Mock notify-send / omarchy-notification-send
        mock_notify = f"""#!/usr/bin/env bash
echo "NOTIFY: $@" >> "{self.notify_log}"
exit 0
"""
        for n in ("notify-send", "omarchy-notification-send"):
            np = os.path.join(self.mock_bin, n)
            with open(np, "w") as f:
                f.write(mock_notify)
            os.chmod(np, 0o755)

        self.sm = SessionManager(config_dir=self.config_dir)

    def tearDown(self):
        os.environ["PATH"] = self.orig_path
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_build_rdp_args_standard(self):
        profile = {
            "name": "DevWin",
            "host": "192.168.1.100",
            "port": 3389,
            "username": "user1",
            "domain": "CORP",
            "sound": True,
            "microphone": False,
            "clipboard": True,
            "dynamic_resolution": True,
            "ignore_cert": True,
        }
        args = self.sm.build_rdp_args(profile, credential="MyPassword")
        self.assertIn("/v:192.168.1.100:3389", args)
        self.assertIn("/u:user1", args)
        self.assertIn("/d:CORP", args)
        self.assertIn("/sound", args)
        self.assertIn("/clipboard", args)
        self.assertIn("/dynamic-resolution", args)
        self.assertIn("/cert:ignore", args)
        self.assertIn("/p:MyPassword", args)
        self.assertNotIn("/microphone", args)

    def test_session_lifecycle_and_active_state(self):
        profile = {"name": "Server1", "host": "10.0.0.1", "username": "admin"}
        os.environ["SLEEP_MOCK"] = "5"
        launched = self.sm.start_session(profile, credential="test")
        self.assertTrue(launched)
        self.assertTrue(self.sm.is_active("Server1"))

        # Stop session
        stopped = self.sm.stop_session("Server1")
        self.assertTrue(stopped)
        # Give a moment to finish
        import time
        time.sleep(0.2)
        self.assertFalse(self.sm.is_active("Server1"))
        del os.environ["SLEEP_MOCK"]

    def test_session_failure_triggers_notification(self):
        profile = {"name": "FailingServer", "host": "10.0.0.2", "username": "admin"}
        os.environ["EXIT_CODE"] = "1"
        self.sm.start_session(profile, credential="test")
        import time
        time.sleep(0.5)
        self.assertTrue(os.path.exists(self.notify_log))
        with open(self.notify_log) as f:
            content = f.read()
        self.assertIn("FailingServer", content)
        del os.environ["EXIT_CODE"]

    def test_multiple_parallel_sessions(self):
        p1 = {"name": "HostA", "host": "10.0.0.10", "username": "u1"}
        p2 = {"name": "HostB", "host": "10.0.0.20", "username": "u2"}
        os.environ["SLEEP_MOCK"] = "5"
        self.assertTrue(self.sm.start_session(p1))
        self.assertTrue(self.sm.start_session(p2))
        self.assertTrue(self.sm.is_active("HostA"))
        self.assertTrue(self.sm.is_active("HostB"))

        self.sm.stop_session("HostA")
        import time
        time.sleep(0.2)
        self.assertFalse(self.sm.is_active("HostA"))
        self.assertTrue(self.sm.is_active("HostB"))

        self.sm.stop_session("HostB")
        time.sleep(0.2)
        self.assertFalse(self.sm.is_active("HostB"))
        del os.environ["SLEEP_MOCK"]


class TestProfileCrud(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Adw.init()

    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="omarchy-rdp-crud-test-")
        self.config_dir = os.path.join(self.test_dir, "omarchy-rdp")
        os.makedirs(self.config_dir, exist_ok=True)
        self.mock_bin = os.path.join(self.test_dir, "bin")
        os.makedirs(self.mock_bin, exist_ok=True)
        self.orig_path = os.environ.get("PATH", "")
        os.environ["PATH"] = f"{self.mock_bin}:{self.orig_path}"
        self.keyring_tsv = os.path.join(self.test_dir, "keyring.tsv")

        mock_secret = f"""#!/usr/bin/env bash
KEYRING_FILE="{self.keyring_tsv}"
touch "$KEYRING_FILE"
action="$1"
shift
TAB=$'\\t'
case "$action" in
  lookup)
    service=""
    profile=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        service) service="$2"; shift 2 ;;
        profile) profile="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    awk -F"$TAB" -v s="$service" -v p="$profile" '$1 == s && $2 == p {{ print $3 }}' "$KEYRING_FILE"
    ;;
  store)
    service=""
    profile=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --label=*) shift ;;
        service) service="$2"; shift 2 ;;
        profile) profile="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    secret="$(cat)"
    awk -F"$TAB" -v s="$service" -v p="$profile" '$1 != s || $2 != p' "$KEYRING_FILE" > "$KEYRING_FILE.tmp" || true
    mv "$KEYRING_FILE.tmp" "$KEYRING_FILE"
    printf '%s\\t%s\\t%s\\n' "$service" "$profile" "$secret" >> "$KEYRING_FILE"
    ;;
  clear)
    service=""
    profile=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        service) service="$2"; shift 2 ;;
        profile) profile="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    awk -F"$TAB" -v s="$service" -v p="$profile" '$1 != s || $2 != p' "$KEYRING_FILE" > "$KEYRING_FILE.tmp" || true
    mv "$KEYRING_FILE.tmp" "$KEYRING_FILE"
    ;;
esac
exit 0
"""
        script_path = os.path.join(self.mock_bin, "secret-tool")
        with open(script_path, "w") as f:
            f.write(mock_secret)
        os.chmod(script_path, 0o755)

        self.pm = ProfileManager(config_dir=self.config_dir)
        self.app = Adw.Application(application_id="org.omarchy.rdp.crudtest")
        self.window = MainWindow(application=self.app, profile_manager=self.pm)

    def tearDown(self):
        if hasattr(self, "window") and self.window:
            self.window.destroy()
        os.environ["PATH"] = self.orig_path
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_create_profile_saves_metadata_and_keyring(self):
        dlg = ProfileFormDialog(parent=self.window, profile_manager=self.pm)
        dlg.name_row.set_text("OfficeVM")
        dlg.host_row.set_text("10.0.0.50")
        dlg.user_row.set_text("winadmin")
        dlg.pwd_row.set_text("SecurePass999")
        dlg._on_save_clicked(None)

        prof = self.pm.get_profile("OfficeVM")
        self.assertIsNotNone(prof)
        self.assertEqual(prof["host"], "10.0.0.50")
        self.assertEqual(prof["username"], "winadmin")
        self.assertNotIn("password", prof)

        stored_pass = KeyringManager.get_password("OfficeVM")
        self.assertEqual(stored_pass, "SecurePass999")

    def test_create_profile_validation_rejects_empty(self):
        initial_count = len(self.pm.list_profiles())
        dlg = ProfileFormDialog(parent=self.window, profile_manager=self.pm)
        dlg.name_row.set_text("")
        dlg.host_row.set_text("10.0.0.50")
        dlg._on_save_clicked(None)
        # Not saved because name was empty
        self.assertEqual(len(self.pm.list_profiles()), initial_count)

    def test_edit_profile_persists_changes(self):
        self.pm.save_profile({"name": "EditMe", "host": "192.168.1.1", "username": "olduser"})
        prof = self.pm.get_profile("EditMe")

        dlg = ProfileFormDialog(parent=self.window, profile_manager=self.pm, profile=prof)
        dlg.host_row.set_text("192.168.1.99")
        dlg.user_row.set_text("newuser")
        dlg._on_save_clicked(None)

        updated = self.pm.get_profile("EditMe")
        self.assertEqual(updated["host"], "192.168.1.99")
        self.assertEqual(updated["username"], "newuser")

    def test_delete_profile_cleans_profiles_and_keyring(self):
        self.pm.save_profile({"name": "DeleteMe", "host": "1.2.3.4"})
        KeyringManager.set_password("DeleteMe", "PasswordToDelete")

        self.assertIsNotNone(self.pm.get_profile("DeleteMe"))
        self.assertEqual(KeyringManager.get_password("DeleteMe"), "PasswordToDelete")

        self.window._do_delete_profile("DeleteMe")

        self.assertIsNone(self.pm.get_profile("DeleteMe"))
        self.assertIsNone(KeyringManager.get_password("DeleteMe"))


if __name__ == "__main__":
    unittest.main()

