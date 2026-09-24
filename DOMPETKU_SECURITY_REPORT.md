# Phase D1: DOMPETKU_SECURITY_REPORT

## 1. Device Security

### Hive Database Encryption
- **Finding**: Hive NoSQL DB is used for storing `TransactionModel` and `settings` natively in plaintext.
- **Vulnerability**: No `HiveAesCipher` is employed. Any user with root access, physical access, or capable of creating ADB backups (if `android:allowBackup="true"` is set in Manifest) can read sensitive financial notification histories and Webhook secrets.
- **Classification**: **RISK** (Local Privilege Escalation / Data Exposure).

### Webhook Secret Storage
- **Finding**: Webhook URLs, Auth Headers, and Webhook Secrets are saved directly to the Hive 'settings' box.
- **Vulnerability**: Stored in plaintext. Survives backups. Extractable from a rooted device or debug build.
- **Classification**: **RISK**.

### Clipboard Usage
- **Finding**: "Smart Paste Auto-Detect" implies the app reads the clipboard to auto-fill URLs.
- **Vulnerability**: If clipboard polling is overly aggressive, it might intercept unintended sensitive data. If URLs contain tokens, they can be leaked.
- **Classification**: **UNKNOWN** (Need UI review, but conceptually risky).

### Debug Logging
- **Finding**: The app makes extensive use of `debugPrint` (e.g., `debugPrint('[DompetKu] Received event: pkg=$package, title=$title, body=$body');`).
- **Vulnerability**: Financial amounts, payer names, and notification bodies are logged to logcat. On debug builds or unstripped releases, this exposes PII to any other app with `READ_LOGS` permissions or via USB ADB.
- **Classification**: **RISK**.

## 2. Privacy / Data Minimization

### Raw Notification Storage
- **Finding**: The `TransactionModel` retains `rawMessage: '$title\n$body'`.
- **Vulnerability**: Notifications occasionally contain overall account balances or sensitive transaction IDs alongside the transfer amount. The app stores these indefinitely and transmits them in the webhook (`json_string` format).
- **Classification**: **RISK** (Over-collection / Data hoarding).

### Data Retention
- **Finding**: Hive DB acts as an append-only ledger for all received notifications. There is no auto-pruning or TTL (Time-To-Live).
- **Vulnerability**: Permanent storage of PII without auto-delete functionality after successful reconciliation.
- **Classification**: **RISK**.

## 3. Threat Matrix & Summary

| Threat Area | Specific Vector | Status | Mitigation Requirement |
|-------------|-----------------|--------|------------------------|
| **Secrets** | Plaintext Hive storage | **RISK** | Encrypt Hive box with Keystore/EncryptedSharedPreferences |
| **Logging** | `debugPrint` on PII | **RISK** | Remove or strip `debugPrint` in Release builds |
| **Privacy** | `rawMessage` transmission | **RISK** | Send only structured data (amount, payer); drop raw message after parsing |
| **Spoofing**| Generic In Detector | **RISK** | Require exact package match; disable fallback for unknown packages |
