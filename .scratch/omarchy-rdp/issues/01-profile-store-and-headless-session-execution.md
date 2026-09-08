# 01: Profile Store and Headless Session Execution

**What to build:** Allow users and test scripts to manage connection Profiles (create, read, list, and delete) persisted in a structured JSON store, and launch a remote desktop Session using FreeRDP 3 with Dynamic Resolution and basic flags via the top-level CLI interface.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] A configuration store persists Profiles with name, host, port (default 3389), and username to `profiles.json` under the user config directory.
- [x] Non-interactive CLI commands allow listing Profiles (`--list`), retrieving a Profile (`--get <name>`), adding a Profile (`--add <json>`), and deleting a Profile (`--delete <name>`).
- [x] Non-interactive CLI command `--get-args <name>` outputs the exact FreeRDP 3 argument vector generated for a Profile, including `/v:`, `/u:`, `/dynamic-resolution`, and `/cert:ignore`.
- [x] Executing a Session via `--connect <name>` spawns FreeRDP 3 with the assembled arguments.
- [x] Automated integration test suite validates the CLI seam against an isolated temporary configuration directory.
