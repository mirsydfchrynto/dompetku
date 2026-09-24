# Phase D1: DOMPETKU_FULL_AUDIT

## Executive Summary
This document provides a comprehensive audit of the DompetKu Android Application acting as a Financial Notification Listener and Webhook Bridge.

### 1. Notification Capture
- **Mechanism**: Utilizes `AppNotificationListenerService` extending `flutter_notification_listener`.
- **Filtering**: Intercepts notifications, applies package blacklists, and checks financial context via `QrisParser`.
- **Duplicate Notifications**: Handled via `DatabaseService.isDuplicateTransaction`. Duplicate is detected within a 90-second window if amount, appSource, and either rawMessage or payerName match. 
- **Classification**:
  - The same financial event can generate **2+ notifications** (Android OS rebroadcast).
  - Status: **VERIFIED**

### 2. Parser Security
- **Mechanism**: Regex-based extraction (`QrisParser`).
- **Filtration**: Explicit blacklist arrays for promo, cashback, OTP, and login alerts.
- **Classification**:
  - Valid: Parsed and sent.
  - Rejected: Discarded early (promos, outgoing transfers).
  - Ambiguous (Risk): Unknown apps triggering "Generic In Detector" fallback could mistakenly classify non-financial chat messages as payments if keywords are present.
  - Status: **RISK** (Fallback parser can be spoofed by un-blacklisted apps).

### 3. Local Persistence
- **Storage**: Hive NoSQL DB.
- **Lifecycle**: RECEIVED -> PARSED -> QUEUED (pending) -> SENDING -> ACKED (success) / FAILED -> RETRY.
- **Resilience**: Hive persists across reboots. However, infinite retry logic (Queue growth) without TTL or permanent fail-state for 4xx errors risks bloating the database.
- **Status**: **VERIFIED** (Persistence) / **RISK** (Queue growth).

### 4. Event Identity / Idempotency
- **Event ID**: `DateTime.now().millisecondsSinceEpoch.toString()`.
- **Gap**: The ID is generated at processing time, not derived from the notification payload. If the 90-second deduplication window passes and a delayed notification is parsed, it generates a new ID. The backend cannot rely solely on this ID for idempotency.
- **Status**: **RISK**.

### 5. Webhook Security
- **Authentication**: HMAC-SHA256 (`X-Dompetku-Signature`).
- **Secret Storage**: Plaintext in Hive.
- **Validation**: Timestamp is sent (`X-Dompetku-Timestamp`) offering basic replay protection if the server enforces TTL.
- **Status**: **RISK** (Device secret storage).

### 6. Server Ack / Retry
- **2xx**: Success.
- **4xx / 5xx**: Failed, goes into retry queue.
- **Retry Semantics**: Any non-2xx is endlessly retried up to 50 items per batch. `409 Conflict` or permanent `400 Bad Request` are not safely acknowledged and will clog the retry queue infinitely.
- **Status**: **RISK**.

### 7. Privacy / Data Minimization
- **Storage**: Full `rawMessage` (title + body) is stored indefinitely in Hive.
- **Risk**: Payer names and occasionally account balances (if present in notifications) are logged in plaintext and never automatically deleted.
- **Status**: **RISK**.

### 8. Device Security
- **Secret Storage**: Webhook secrets and auth headers are unencrypted. 
- **Status**: **RISK** on rooted devices or physical access.

### 9. Multi-Bank / Multi-Wallet
- Refer to `DOMPETKU_PARSER_MATRIX.md`.

### 10. Payment Attribution Contract
- Refer to `DOMPETKU_PAYMENT_ATTRIBUTION_RISK.md`.

### 11. Offline / Recovery Tests
- Tests verify basic timeout logic, but do not simulate offline app kill scenarios comprehensively. No evidence of integration tests proving no silent loss across OS reboots.
- **Status**: **UNKNOWN**.

### 12. Test Quality
- **Coverage**: 70 Unit Tests pass.
- **What they prove**: Regex logic per-bank (NORMAL), Webhook HMAC construction (NORMAL), 200/400/500 HTTP parsing (FAILURE).
- **What they lack**: Integration tests for database deduplication, infinite retry loops, and Android OS intent broadcast idempotency.
- **Status**: **TEST VERIFIED** (Unit level) / **UNKNOWN** (Integration level).
