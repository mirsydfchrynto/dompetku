# DompetKu Data Retention & Privacy Policy

**Phase:** D2 — Critical Hardening

## Overview
Notification payloads contain highly sensitive financial data, including exact amounts, banking sources, and sometimes personal names (Payer Data). P1 Hardening introduces Data Minimization to ensure sensitive `rawMessage` content is not retained longer than operationally necessary.

## Retention Policy

### 1. In-Flight & Failed Transactions
- **Retention:** Indefinite (Bounded by device storage/limits).
- **Reason:** Requires operator intervention or automatic retry. Full `rawMessage` is preserved for debugging the specific failure or parsing anomaly.

### 2. Delivered / Reconciled Transactions
- **Condition:** `webhookStatus == 'success'` (or `409` duplicate ack).
- **Time < 24 Hours:**
  - `rawMessage` kept intact to allow same-day manual reconciliation and auditing if backend discrepancy occurs.
- **Time > 24 Hours:**
  - `rawMessage` is permanently overwritten with `[STRIPPED FOR PRIVACY]`.
  - Amount, payer name, and timestamp are preserved.
- **Time > 7 Days:**
  - The entire transaction record is permanently deleted from the local SQLite/Hive database.
  - The GASTON.YK backend is considered the Authoritative Record at this stage.

## Implementation
- Implemented via `DatabaseService.cleanupOldTransactions()`.
- Automatically invoked in `main.dart` upon every application startup.
- **Evidence Level:** CODE VERIFIED.

## Logging Policy
- Production (Release build): All `debugPrint` statements containing parsed `amount`, `payerName`, or raw notification payloads are suppressed.
- `kDebugMode` wrappers ensure logs are completely silent in release.
- **Evidence Level:** CODE VERIFIED.
