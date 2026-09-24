# DompetKu v1.4.1 — Verified Merchant Bridge Build

## 🔒 Security Remediation & Hardening
- **Provenance Integrity:** Migrated release APK build pipeline to ensure exact matching of commit HEAD, APK hash, and signing certificate.
- **Secret Isolation:** Removed inline keystore passwords from Git history (via `build.gradle.kts`) and successfully migrated to `.gitignore`d `key.properties`. No secrets remain tracked in the repository.
- **R8 Minification:** Added exact `proguard-rules.pro` file mapping for Flutter's `assembleRelease` optimization. 

## 📦 Artifact Provenance
- **Exact Commit SHA:** f16a596160f2af83fb9002c7bd08c1150d406109
- **APK Version:** 1.4.1
- **Version Code:** 141
- **APK SHA-256:** 3ab60fa55787f3d220a503f21ec50d46909ec88efdccfaa160fc0c4f0e6c3e04
- **Signing Certificate Fingerprint (SHA-256):** c4059398be3b3c326673f84fc7d0802342c116513558d73b229cc27b48cb2f15

⚠️ **Real-device payment verification is still pending.**
*(Do not deploy to full merchant production until the human operator verifies the physical transaction flow).*
