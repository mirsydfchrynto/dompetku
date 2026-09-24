# Phase D1: DOMPETKU_PAYMENT_ATTRIBUTION_RISK

## The Attribution Contract
DompetKu acts as a bridge. The backend (GASTON.YK) uses a Static QRIS paired with Dynamic/Unique Payment Amounts (e.g., adding unique code Rp 50.012) and Manual Reconciliation.

### Trace Flow
1. **DompetKu Event**: `AppNotificationListenerService` captures notification.
2. **Amount Extraction**: `QrisParser` pulls exact amount (e.g., `50012`).
3. **Webhook**: Payload sent containing `amount`, `appSource`, `payerName`.
4. **Backend Allocation Lookup**: Backend searches for a pending order expecting `50012`.
5. **State Transition**: Order marked as PAID if amounts match.

## Risk Analysis

Since this is **NOT a true dynamic QRIS** (where each QR code is unique and uniquely tagged by the payment gateway), attribution relies **entirely** on the uniqueness of the `amount` across a specific time window.

### 1. Duplicate / Reused Amount Risk
- **Scenario**: Two users are told to pay Rp 50.000 simultaneously. The backend assigns them Rp 50.012 and Rp 50.013. If the backend accidentally assigns Rp 50.012 to two active orders, the first incoming webhook will mark *one* of them PAID (arbitrarily), leaving the other unpaid.
- **Classification**: **RISK**. Amount matching is not perfect identity.

### 2. Wrong Amount / Partial Payment
- **Scenario**: User is supposed to pay Rp 50.012. User manually edits the amount in their banking app and transfers exactly Rp 50.000.
- **Outcome**: Webhook sends `50000`. Backend fails to find an exact match. The order remains pending, and the money is orphaned.
- **Classification**: **RISK**.

### 3. Idempotency & Duplicate Delivery
- **Scenario**: Android rebroadcasts the same notification 5 minutes later (outside the 90-second local deduplication window). DompetKu assigns a new `id` and sends a second webhook for `50012`.
- **Outcome**: If the backend does not deduplicate based on `(amount, appSource, timestamp_range)`, it might apply the payment to a *new* order that happened to reuse `50012`.
- **Classification**: **RISK**. Backend MUST enforce strict idempotency logic beyond just the DompetKu `id`.

### 4. Same Amount from Another Payer (Collisions)
- **Scenario**: A random person transfers Rp 50.012 to the static QRIS by mistake or malice, while a legitimate user has a pending order for Rp 50.012.
- **Outcome**: The legitimate user's order is marked PAID by the random person's transfer. 
- **Classification**: **RISK**. (Inherent to Unique Amount allocation method).

### 5. False Positives (Spoofed Notification)
- **Scenario**: A user discovers the static QRIS doesn't check real gateways, but relies on phone notifications. User sends an SMS to the phone containing: "qris berhasil uang masuk Rp50.012". 
- **Outcome**: If the SMS package is not blacklisted, the "Generic In Detector" fallback parses it. Webhook fires. Backend marks order PAID. No actual money moved.
- **Classification**: **RISK**. Strict whitelist of Android packages is mandatory.

## Conclusion
Do not claim amount matching is perfect identity. It is a heuristic reconciliation method fraught with edge cases. Backend systems must be designed defensively to handle orphaned amounts, collision allocations, and manual override capabilities.
