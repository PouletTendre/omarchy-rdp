# 02: Keyring Credential Management

**What to build:** Securely store and retrieve Windows authentication Credentials in the Linux Keyring (Secret Service) linked to each Profile, prompting the user for their password on the first Session launch if absent and automatically purging stored secrets when a Profile is deleted.

**Blocked by:** 01: Profile Store and Headless Session Execution

**Status:** resolved

- [x] Credentials (passwords) are saved to and read from the Linux Secret Service using `secret-tool` keyed by `service=omarchy-rdp` and `profile=<name>`.
- [x] No passwords or secrets are ever serialized to `profiles.json` on disk.
- [x] When initiating a Session, the Credential is automatically retrieved from the Keyring and supplied to the RDP engine via `/p:`.
- [x] If no Credential exists in the Keyring when launching a Session, the user is prompted securely for their password with an option to remember it in the Keyring.
- [x] Deleting a Profile purges the corresponding Credential from the Keyring.
- [x] Integration tests verify Credential storage, retrieval, and cleanup against a mock or isolated Secret Service handler.
