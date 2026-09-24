# DompetKu Deduplication Audit

**Phase:** D3 — Release Verification

## The Flaw in Pure Text Deduplication
Prior to D3, DompetKu used a fingerprint of `MD5(package + amount + payerName)` combined with a fallback that matched exact `rawMessage` text strings within a 1-hour window.

**The Risk:** If a customer buys two identical coffees for Rp 50.000 within 10 minutes, the banking app will send two notifications. If the banking app does not include a timestamp inside the notification body (which most don't), the `rawMessage` for both events is identical. DompetKu would falsely classify the second coffee payment as a "duplicate" and drop it.

## The Solution: Android OS Identity Integration
We audited the `flutter_notification_listener` package and verified that the Android OS provides metadata that is guaranteed unique per *new* notification instance, but stable across *updates/rebroadcasts* of the same notification.

### D3 Fingerprint Architecture
The `dedupeFingerprint` is now built deterministically from:
1. `package` (e.g., `com.gojek.gopay`)
2. `amount` (e.g., `50000.0`)
3. `payerName` (e.g., `budi santoso`)
4. `notificationKey` (Android OS unique identifier for the notification instance)
5. `notificationTimestamp` (The exact millisecond the notification was originally created by the financial app)

### Scenario Proofs (Verified in Code)

| Scenario | Inputs | Result | Reason |
| :--- | :--- | :--- | :--- |
| **Android Rebroadcast** | Same OS Key, Same Timestamp, Same Text | **DUPLICATE** | Fingerprints match exactly. OS is just re-alerting. |
| **Delayed Duplicate** | Same OS Key, Same Timestamp, Same Text | **DUPLICATE** | Fingerprints match exactly. Fallback protects the 1-hour window. |
| **Identical Separate Payments** | Different OS Key, Different Timestamp, Same Text | **NEW TRANSACTION** | Fingerprints differ because Android issued a new Key/Timestamp. Fallback is safely bypassed. |

## Conclusion
The deduplication mechanism is now robust against identical separate transactions (preventing financial loss) while remaining aggressive against OS-level notification rebroadcasts (preventing double-crediting).
