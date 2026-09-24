# Phase D1: DOMPETKU_PARSER_MATRIX

## Supported Applications

| Provider | Package | Base Code | Status | Verified By |
|----------|---------|-----------|--------|-------------|
| **GoPay** | `com.gojek.gopay`, `com.gojek.app` | `gopay_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **DANA** | `id.dana` | `dana_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **DANA Bisnis** | `id.dana` (keyword check) | `dana_bisnis_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **OVO** | `ovo.id` | `ovo_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **ShopeePay** | `com.shopeepay.id`, `com.shopee.id` | `shopeepay_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **SeaBank** | `com.seabank.seabank`, `com.seabank.id`, `com.bancodesul.seabank` | `seabank_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **Bank Jago** | `com.jago.digitalBanking` | `jago_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **BCA Mobile** | `com.bca` | `bca_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **myBCA** | `id.co.bca.mybca` | `bca_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **Livin by Mandiri**| `id.co.mandiri.livin`, `com.bankmandiri.mandiriglobal` | `mandiri_in`| **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **BRImo** | `id.co.bri.brimo` | `bri_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **wondr by BNI** | `id.bni.wondr`, `id.co.bni.mobilebanking`, `src.mobi.bni` | `bni_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **Neobank** | `com.bnc.finance`, `com.bankneocommerce.bunc` | `neobank_in`| **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **Jenius** | `com.btpn.dc` | `jenius_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **Permata ME** | `com.permatabank.mobile`, `net.myinfosys.permata` | `permata_in`| **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **OCTO Mobile** | `id.co.cimbniaga.mobile.android`| `octo_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **LinkAja** | `com.telkom.mwallet` | `linkaja_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **Simulator** | `com.dompetku.simulator` | `simulator_in` | **IMPLEMENTED + TESTED** | `qris_parser_test.dart` |
| **Unknown/New App** | Any | Generic | **IMPLEMENTED + UNVERIFIED** | Relies on generic keywords |

## Parser Deficiencies
- **Ambiguous Notification Risk**: The "Generic In Detector" fallback triggers on keywords like "qris", "uang masuk" on unknown packages. If an un-blacklisted app (e.g. Line, Discord, SMS) receives a message "berhasil diterima qris Rp 50.000", the app will blindly parse it as a valid transaction.
- **Status**: **RISK**.
