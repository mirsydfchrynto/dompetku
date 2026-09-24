# DompetKu Release Verification Report

**Phase:** D3 — Release Verification

## P0 — Deduplication Correctness
- **Finding:** Relying purely on `MD5(package + amount + payerName)` creates a false-positive risk where two identical legitimate payments (same amount, same payer) within a 1-hour window are incorrectly deduped, causing the second payment to be lost.
- **Fix Applied:** Expanded `TransactionModel` and `QrisParser` to capture the unique Android OS `NotificationEvent.key` and `NotificationEvent.timestamp`. These OS-level identifiers precisely distinguish between a rebroadcast of an old notification and a brand new notification of a new payment.
- **Evidence Level:** CODE VERIFIED. New test suites explicitly prove that identical text payloads with different OS keys are treated as separate valid payments.

## P0 — Server 409 Semantics
- **Contract Verified:** DompetKu treats HTTP `409 Conflict` strictly as an Idempotency Hit (Terminal ACK).
- **Constraint:** The GASTON.YK backend MUST ONLY return 409 if it has successfully identified the event as a duplicate of a previously successfully processed transaction. If the backend uses 409 for "Amount Mismatch" or "Order Expired", those must be returned as 400 or 422 to trigger the `DEAD_LETTER` state for operator review. DompetKu assumes 409 means "I already have this, you can safely stop retrying."

## P1 — Retry Age vs Retry Count
- **Current Metric:** 10 retries with linear backoff (5m, 10m, 15m... 50m). Total retry lifespan = ~4.5 hours.
- **Risk:** An overnight backend outage (e.g., 8 hours) will cause events to transition to `DEAD_LETTER` before the server recovers.
- **Mitigation:** Operator review is required for dead letters. The retry bound is kept at 10 to prevent infinite queue growth, but the backoff is deemed sufficient for transient network drops. Major outages will require the operator to manually requeue dead letters from the Hive database.

## P1 — Outbound Data Minimization
- **Payload Audit:** DompetKu currently transmits the `message` field (which contains the raw notification text).
- **Backend Dependency:** The backend (GASTON.YK) relies on this text for secondary verification and extracting the `GAS-` order ID if not explicitly parsed. Therefore, removing `message` from the outbound webhook payload would break backend compatibility.
- **Mitigation:** The raw message is minimized *locally* after 24 hours (overwritten with `[STRIPPED FOR PRIVACY]`), but is transmitted in full at the time of the event to satisfy the backend contract.

## P1 — Event Time Semantics
- **Device Receive Timestamp (`DateTime.now()`):** Used for internal local queue management and backoff calculation.
- **Notification Timestamp (`event.timestamp`):** The authoritative time the financial institution created the notification on the device.
- **Constraint:** DompetKu uses `event.timestamp` for deduplication. The webhook payload includes `timestamp` (Device Send Time), but relies on the backend to reconcile the actual payment time.

## P3 — Payment Attribution Handoff
DompetKu explicitly guarantees:
1. Capture of valid financial notifications from allowlisted apps.
2. Extraction of `amount` and `appSource`.
3. Deterministic event deduplication via OS-level identifiers.
4. Bounded, semantic webhook delivery.

DompetKu does **NOT** guarantee:
1. Matching the payment to a specific user's order (Order Attribution).
2. Handling amounts that cover multiple orders or partial payments.
3. Deciding if a payment is late or expired.

All attribution and state transitions are strictly the responsibility of the GASTON.YK backend. DompetKu is solely a secure transport bridge.
