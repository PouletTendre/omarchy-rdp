# 03: Hyprland Display Scale and Advanced RDP Options

**What to build:** Automatically query the active Hyprland monitor to calculate the appropriate Display Scale factor (`/scale:140` or `/scale:180`) for HiDPI rendering, eliminate the 23-second Kerberos NLA timeout via a local fallback configuration, and support audio redirection, microphone, clipboard sharing, and local directory Shares in FreeRDP 3.

**Blocked by:** 01: Profile Store and Headless Session Execution

**Status:** ready-for-agent

- [ ] Query focused monitor scale via `hyprctl monitors -j` and inject `/scale:140` (for scale >= 130%) or `/scale:180` (for scale >= 170%) into the FreeRDP 3 arguments.
- [ ] Generate a minimal `krb5.conf` with `dns_lookup_kdc = false` and export `KRB5_CONFIG` prior to launching FreeRDP 3 to prevent MIT Kerberos NLA timeouts.
- [ ] Support Profile flags for audio redirection (`/sound`), microphone (`/microphone`), and bidirectional clipboard (`/clipboard`).
- [ ] Support mounting a local Linux directory as a Windows network drive via `/drive:shared,<path>` when configured in the Profile.
- [ ] Integration tests verify that calculated scale factors, Kerberos environment setup, and advanced flags are correctly appended to the generated arguments.
