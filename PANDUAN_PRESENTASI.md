# 🎤 Panduan Presentasi & Demo: DompetKu Webhook

Dokumen ini disusun untuk memudahkan siapa saja (pemula, mahasiswa, intern, hingga developer senior) dalam **mempresentasikan, mendemokan, dan mengajarkan** cara kerja aplikasi **DompetKu**.

---

## ⏱️ 1. Naskah Presentasi 3 Menit (Elevator Pitch)

Gunakan naskah ini saat diminta menjelaskan inti project secara ringkas:

> *"Halo semuanya! Project yang kami kembangkan bernama **DompetKu**, sebuah solusi otomasi kasir mobile yang menjembatani notifikasi pembayaran di smartphone Android langsung ke database server backend secara realtime.*
>
> *Masalah yang sering dialami toko fisik saat ini adalah: kasir harus mengecek HP manual berulang kali atau menanyakan bukti transfer ke pelanggan setiap kali ada transaksi QRIS (seperti GoPay, DANA, BCA, OVO).*
>
> *Dengan DompetKu:*
> 1. *Setiap ada notifikasi pembayaran masuk, background listener Android langsung menangkapnya.*
> 2. *Aplikasi mengekstrak nominal uang dan nama pengirim menggunakan ekspresi reguler (Regex).*
> 3. *Data disimpan secara offline di database lokal HP menggunakan Hive.*
> 4. *Secara simultan, aplikasi langsung menembakkan **HTTP POST Webhook** ke server backend tim, otomatis mengisi tabel `webhook_notif`.*
>
> *Semua ini berjalan otomatis, ringan, dan dilengkapi Simulator Interaktif di dalam aplikasi sehingga siapapun bisa mempelajari alurnya dalam hitungan menit."*

---

## 🚀 2. Alur Langkah Demi Langkah untuk Demo (Live Demo Flow)

Ada 2 cara mendemokan aplikasi: **Metode Simulator (Paling Mudah)** dan **Metode HP Fisik / ADB**.

### Skenario A: Demo Menggunakan Fitur Simulator Bawaan (100% Aman & Instan)
1. **Buka Aplikasi DompetKu** di HP Android atau Emulator.
2. Di halaman utama, tap banner **"Pusat Edukasi & Simulator"** (atau ikon topi sarjana 🎓 di AppBar).
3. Pilih tab kedua: **"Simulator"**.
4. Tap salah satu chip template cepat: misal **"GoPay Rp50.000"** atau **"BCA Mobile Rp75.000"**.
5. Tunjukkan kepada penonton:
   - Kotak **"Hasil Ekstraksi Regex"** langsung menampilkan: Nominal Rp50.000,00, Sumber: GoPay, Pembayar: Budi S.
   - Kotak **"JSON Payload"** menampilkan format persis yang dikirim ke backend: `{"message": "..."}`.
6. Tap tombol hijau **"Kirim ke Backend Sekarang"**.
7. Lihat respons server: Muncul badge hijau `✅ Sukses Terkirim! Backend merespons HTTP 201`.
8. Kembali ke halaman utama (`HomeScreen`): Card transaksi baru sudah bertengger di paling atas lengkap dengan badge `200 OK`.

### Skenario B: Demo Menggunakan Tombol "Demo +" di Halaman Utama
1. Di halaman utama, tap tombol mengambang **"Demo +"** di kanan bawah.
2. Transaksi acak akan dibuat, disimpan ke database lokal HP, dan langsung ditembakkan ke endpoint webhook yang aktif.
3. Status badge di card akan berubah dari kuning `Mengirim...` menjadi hijau `200 OK`.

### Skenario C: Verifikasi di Sisi Backend / cURL
Untuk membuktikan data benar-benar masuk ke server backend:
```bash
curl -X POST https://787e-103-3-222-52.ngrok-free.app/api/notification \
  -H "Content-Type: application/json" \
  -d '{"message": "Pembayaran QRIS Rp50.000 berhasil diterima dari Budi S."}'
```
Backend akan merespons:
```json
{"message":"Success","id":40,"created_at":"2026-09-09"}
```

---

## 🧩 3. Poin Penjelasan Kode & Arsitektur (Untuk Pengajar & Penguji)

Ketika ditanya mengenai struktur kode dan arsitektur aplikasi, jelaskan 4 modul inti berikut:

| Komponen | File Sumber | Cara Menjelaskan ke Penguji |
|---|---|---|
| **Background Listener** | `lib/services/notification_listener_service.dart` & `AndroidManifest.xml` | *"Menggunakan Android Native `NotificationListenerService`. Begitu ada event notifikasi dari OS, sistem memicu callback tanpa menguras baterai HP."* |
| **Ekstraksi String (Regex)** | `lib/services/qris_parser.dart` | *"Berfungsi sebagai detektif pintar. Regex mencari pola mata uang `Rp[0-9.,]+` dan nama setelah kata `dari`. Dilengkapi fallback pintar sehingga mendukung aplikasi baru."* |
| **Penyimpanan Lokal** | `lib/services/database_service.dart` | *"Menggunakan NoSQL Hive yang sangat cepat dan ringan di HP. Data tersimpan permanen sehingga riwayat kasir tidak hilang saat HP mati."* |
| **Koneksi Jaringan Webhook** | `lib/services/webhook_service.dart` | *"Mengirim HTTP POST dengan timeout 10 detik, penanganan error jaringan, dan dukungan bypass header untuk tunneling seperti ngrok dan loca.lt."* |

---

## ❓ 4. Tanya Jawab Umum (FAQ) & Kunci Jawaban

#### Q1: "Kenapa memilih format `{"message": "..."}` daripada banyak kolom JSON terpisah?"
> **Jawaban:** *"Format ini mengikuti kontrak arsitektur yang sudah ditentukan tim backend (`table webhook_notif [id, message, created_at]`). Dengan mengirimkan teks pesan lengkap atau JSON ter-enkapsulasi dalam kolom `message`, tim backend fleksibel melakukan parsing ulang atau logging tanpa perlu sering mengubah migrasi schema database."*

#### Q2: "Bagaimana jika HP offline atau sinyal terputus saat notifikasi masuk?"
> **Jawaban:** *"Transaksi tetap tersimpan dengan aman di database lokal HP (Hive) dengan status `failed`. Di halaman Detail Transaksi, disediakan tombol **'Coba Kirim Ulang' (Retry Webhook)** sehingga kasir bisa mengirimkannya kembali saat sinyal sudah normal."*

#### Q3: "Bagaimana cara menyambungkan aplikasi ini ke laptop backend pengembang?"
> **Jawaban:** *"Cukup gunakan tunneling publik seperti **ngrok** (`ngrok http 8000`) atau **LocalTunnel** (`npx loca.lt --port 8000`), lalu masukkan URL hasilnya di menu **Integrasi Webhook** pada aplikasi. Aplikasi sudah dilengkapi preset cepat untuk URL tim dan auto-bypass header."*

#### Q4: "Apakah aplikasi ini aman dari segi privasi?"
> **Jawaban:** *"Sangat aman. Secara default, opsi **'Hanya Transaksi QRIS / Finansial'** diaktifkan. Notifikasi pesan pribadi seperti WhatsApp, SMS perbankan OTP, atau promo otomatis diabaikan dan tidak pernah disimpan maupun dikirim ke server."*

---

## 🏆 5. Checklist Kesiapan Demo

- [x] Endpoint backend teruji aktif (contoh: ngrok Willi Magang).
- [x] Izin notifikasi Android aktif di HP kasir.
- [x] Modul simulator di tab Edukasi teruji berfungsi.
- [x] Unit test 25/25 lulus 100%.
- [x] Laporan status webhook reaktif di UI (badge 200 OK / Gagal).
