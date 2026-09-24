# DompetKu Device Security Assessment

**Phase:** D2 — Critical Hardening

## Overview
Because DompetKu runs on a physical Android device bridging secure banking notifications to an external web server, the physical and OS security of the device acts as the trust anchor.

## Addressed Risks

### 1. Secret Storage (Webhook Auth)
- **Previous Risk:** Webhook secret and authorization headers were stored in plaintext within Hive (which is basically a JSON-like binary format easily extractable on a rooted device or via ADB backup).
- **Current Mitigation:**
  - Migrated to `flutter_secure_storage`.
  - On Android, this uses the `EncryptedSharedPreferences` backed by the Android Keystore system (Hardware-backed AES encryption where available).
- **Residual Risk:** A fully rooted device running specialized memory-dumping tools (Frida, etc.) while the app is active *can* still extract the secret. However, offline extraction via simple backup tools is mitigated.
- **Evidence Level:** CODE VERIFIED.

### 2. Device Recovery & Offline Safety
- **Scenario:** Notification arrives -> network disabled -> event queued -> network returns -> app restart -> event sends.
- **Mitigation:**
  - `DatabaseService` relies on persistent disk I/O. As long as `saveTransaction` completes, the event survives app crashes, memory pressure kills (OOM), and phone reboots.
  - The Android `NotificationListenerService` explicitly restarts and attempts to re-bind upon device boot (defined in AndroidManifest).
- **Evidence Level:** CODE VERIFIED. (Requires manual physical device test for DEVICE VERIFIED).

### 3. Debug Logging
- **Previous Risk:** Logging printed plaintext payloads, which on Android can be read by other apps holding `READ_LOGS` permissions or via USB debugging.
- **Mitigation:** Sensitive logging explicitly disabled in Release builds.
- **Evidence Level:** CODE VERIFIED.

### 4. Smart Paste / Clipboard
- **Mitigation:** DompetKu itself does not programmatically copy sensitive data to the clipboard, preventing other apps from polling clipboard changes.

## Unmitigated / Residual Risks (Acceptable for Phase D2)
- **Rooted Devices:** DompetKu currently has no Root Detection or SafetyNet/PlayIntegrity checks. A hostile actor with physical access to the unlocked device can theoretically manipulate the local SQLite/Hive database to spoof fake QRIS notifications before they hit the webhook. (Requires trust in the physical cashier device).
- **Screen Recording:** Notification contents can be intercepted if the user runs a malicious screen-recording app.
