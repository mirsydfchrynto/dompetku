# DompetKu Production Source Matrix

**Phase:** D3 — Release Verification

This matrix classifies the exact production readiness of each financial institution parser integrated into DompetKu. 

**Important:** "CODE VERIFIED" implies unit tests pass for known notification formats. "DEVICE VERIFIED" implies the integration has been tested on physical hardware and successfully survived Android OS battery optimization and background execution restrictions.

## Matrix

| Source | Target Package | Code Verified | Unit Tested | Device Verified | Production Ready |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **DANA** | `id.dana` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **SeaBank** | `com.bancodesul.seabank` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **ShopeePay** | `com.shopee.id` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **GoPay** | `com.gojek.app` / `com.gojek.gopay` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **OVO** | `ovo.id` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **Jago** | `com.jago.digitalBanking` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **BCA Mobile** | `com.bca` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **myBCA** | `com.bca.mybca` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **Livin' by Mandiri** | `id.bmri.livin` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **BRImo** | `id.co.bri.brimo` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **wondr by BNI** | `id.co.bni.wondr` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **NeoBank** | `com.ap.vbs` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **Jenius** | `com.btpn.dc` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **Permata ME** | `id.co.permatabank.permatamobile` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |
| **OCTO Mobile** | `id.co.cimbniaga.mobile.android` | ✅ | ✅ | ❌ UNKNOWN | **PARTIAL** |

## Recommendation for Tomorrow's Release
**NO source is fully DEVICE VERIFIED.**
Before deploying tomorrow's merchant operation, the operator **MUST** select the ONE primary payment app intended for receiving merchant funds (e.g., DANA Bisnis or GoPay Merchant) and physically execute the following checklist on the designated merchant device:

### Real-Device Checklist
1. **[ ] Notification Capture:** Send a real payment of Rp 1 to the merchant QR. Verify DompetKu captures it instantly.
2. **[ ] Network Recovery:** Disable Wi-Fi/Data. Send Rp 1. Verify DompetKu queues it. Re-enable network. Verify successful webhook delivery.
3. **[ ] App Restart Survival:** Force stop DompetKu. Send Rp 1. Re-open DompetKu. Verify the event was captured in the background (requires `NotificationListenerService` autostart).
4. **[ ] Phone Reboot:** Restart the Android device entirely. Do not manually open DompetKu. Send Rp 1. Verify backend receives the webhook (requires battery optimization whitelisting).

Without executing this checklist, DompetKu cannot guarantee production readiness for a specific OEM Android environment (MIUI, ColorOS, OneUI, etc.).
