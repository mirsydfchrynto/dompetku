# DompetKu Hardening Report
**Phase:** D2 — Critical Hardening

## Overview
This report details the execution and verification of Phase D2 Critical Hardening for the DompetKu Android application. The objective was to eliminate high-impact operational and security risks without redesigning the architecture or modifying the backend.

## Addressed Risks

### P0 — Disable Unsafe Generic Payment Detection
**Status:** IMPLEMENTED
**Evidence Level:** CODE VERIFIED
**Details:**
- Modified `QrisParser.parse` to remove the fallback for unknown Android packages matching generic keywords like "qris" or "uang masuk".
- Unknown/unregistered apps now return `null` and are strictly rejected.
- Simulator remains intact (`com.dompetku.simulator`).
- Tests added verifying that unknown apps (e.g., Line spoofing financial text) are rejected.

### P0 — Retry / Dead Letter
**Status:** IMPLEMENTED
**Evidence Level:** CODE VERIFIED
**Details:**
- Modified `WebhookService.sendTransaction` to enforce semantic HTTP response handling.
- `NETWORK/TIMEOUT` and `5xx` -> trigger bounded `RETRY`.
- `409` -> mapped to `success` (terminal acknowledgement) to prevent infinite loops.
- `400/401/403/422` -> set to `dead_letter` state immediately.
- Max retries bounded at 10 with progressive backoff.
- Tests verified 409 and 400 behaviors.

### P0 — Event Identity / Deduplication
**Status:** IMPLEMENTED
**Evidence Level:** CODE VERIFIED
**Details:**
- `TransactionModel` updated with a `dedupeFingerprint`.
- `dedupeFingerprint` is deterministically generated as `md5(package + amount + payerName)`.
- `DatabaseService.isDuplicateTransaction` now uses fingerprint matching and expanded the dedupe window to 1 hour (from 90 seconds).
- Dedupe tests updated and verified.

### P1 — Secret Storage
**Status:** IMPLEMENTED
**Evidence Level:** CODE VERIFIED
**Details:**
- Webhook Secret and Auth Header now stored in Android Keystore using `flutter_secure_storage`.
- Added migration logic to safely move plaintext Hive secrets to Keystore storage seamlessly.

### P1 — Raw Message Minimization
**Status:** IMPLEMENTED
**Evidence Level:** CODE VERIFIED
**Details:**
- Added `DatabaseService.cleanupOldTransactions` called during `main.dart` startup.
- Automatically purges successfully delivered events older than 7 days.
- Strips `rawMessage` (replaced with `[STRIPPED FOR PRIVACY]`) for successful events older than 24 hours to balance reconciliation capability with data privacy.

### P1 — Logging
**Status:** IMPLEMENTED
**Evidence Level:** CODE VERIFIED
**Details:**
- Audited `notification_listener_service.dart`.
- All `debugPrint` statements exposing `rawMessage`, `amount`, and `payerName` were conditionally wrapped with Flutter's `kDebugMode`. Release builds will not log these values.

## Supported Sources Support Matrix
**Status:** CLASSIFIED
For each financial app:
- **DANA**: IMPLEMENTED + TESTED
- **SeaBank**: IMPLEMENTED + TESTED
- **ShopeePay**: IMPLEMENTED + TESTED
- **GoPay**: IMPLEMENTED + TESTED
- **OVO**: IMPLEMENTED + TESTED
- **Jago**: IMPLEMENTED + TESTED
- **BCA**: IMPLEMENTED + TESTED
- **Mandiri (Livin)**: IMPLEMENTED + TESTED
- **BRI (BRImo)**: IMPLEMENTED + TESTED
- **BNI (wondr)**: IMPLEMENTED + TESTED
- **NeoBank**: IMPLEMENTED + TESTED
- **Jenius**: IMPLEMENTED + TESTED

*Note: While CODE VERIFIED and TESTED via extensive unit tests, DEVICE VERIFIED is recommended for varying Android OEM OS flavors (Xiaomi MIUI, Oppo ColorOS, etc.) regarding background execution limits.*
