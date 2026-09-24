# DompetKu Payment Event Lifecycle

**Phase:** D2 — Critical Hardening

This document defines the exact state machine and lifecycle for an incoming payment event captured by DompetKu.

## State Machine
The lifecycle transitions through the following definitive states:

1. **RECEIVED**
   - Android OS broadcasts an incoming notification to `AppNotificationListenerService`.
   - **Evidence Level:** CODE VERIFIED.

2. **PARSED**
   - `QrisParser` attempts to extract amount, payer, and source.
   - If parser fails or app is unrecognized: Event is discarded (or treated as AMBIGUOUS/Non-Financial). Ambiguous parsing is strictly isolated from the automatic payment success path.
   - **Evidence Level:** CODE VERIFIED.

3. **QUEUED**
   - A `TransactionModel` is created.
   - `DatabaseService.isDuplicateTransaction` checks the `dedupeFingerprint` against a 1-hour rolling window.
   - If not a duplicate, it's saved locally via Hive.
   - **Evidence Level:** CODE VERIFIED.

4. **SENDING**
   - `WebhookService` prepares the HTTP POST request to the GASTON.YK backend.
   - Applies secure headers and HMAC signatures.
   - **Evidence Level:** CODE VERIFIED.

5. **ACKED (Terminal)**
   - Backend responds with `2xx`.
   - Local state `webhookStatus` marked as `success`.
   - **Evidence Level:** CODE VERIFIED.

6. **DUPLICATE_ACK (Terminal)**
   - Backend responds with `409 Conflict`.
   - Indicates backend already processed this identical payload (idempotency hit).
   - Local state `webhookStatus` mapped to `success` to prevent redundant retries.
   - **Evidence Level:** CODE VERIFIED.

7. **RETRY**
   - Network failure, Timeout, or `5xx` Server Error.
   - `webhookStatus` marked as `failed`.
   - `retryCount` incremented.
   - Event will be picked up on the next queue iteration.
   - **Evidence Level:** CODE VERIFIED.

8. **DEAD_LETTER (Terminal)**
   - Hard rejection from backend (`400`, `401`, `403`, `422`).
   - Or `retryCount` exceeds max limit (10).
   - `webhookStatus` marked as `dead_letter` and `isDeadLetter = true`.
   - Will NOT be automatically retried; operator intervention is required.
   - **Evidence Level:** CODE VERIFIED.

## Conclusion
Ambiguous/Unknown notifications are no longer forcefully funneled into the `QUEUED` state using the generic "uang masuk" regex. Events now travel through deterministic and strictly verified paths. No event can silently cycle infinitely.
