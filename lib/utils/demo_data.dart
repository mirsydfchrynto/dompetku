// ============================================================
// FILE: demo_data.dart
//
// TUJUAN: Simulasi notifikasi QRIS untuk keperluan demo
//         TANPA perlu customer atau transaksi nyata!
//
// Cara pakai:
//   1. Tekan tombol "Simulasi Demo" di layar utama
//   2. Sistem akan ambil satu notifikasi acak dari daftar ini
//   3. Parser akan memproses seperti notifikasi nyata
//   4. Transaksi muncul di daftar!
//
// Semua contoh notifikasi di sini adalah realistis —
// format yang sama persis dengan yang dikirim e-wallet asli.
// ============================================================

import 'dart:math';
import '../models/transaction_model.dart';
import '../services/qris_parser.dart';

class DemoData {
  // Daftar skenario notifikasi per e-wallet
  // Setiap skenario punya beberapa variasi pesan
  static const List<Map<String, dynamic>> _scenarios = [
    // ── GOPAY ───────────────────────────────────────────────
    {
      'title': 'GoPay',
      'package': 'com.gojek.gopay',
      'messages': [
        'Pembayaran QRIS Rp50.000 berhasil diterima dari Budi S.',
        'QRIS Rp125.000 berhasil. Pembayaran diterima dari Andi W.',
        'Kamu menerima Rp75.000 dari pembayaran QRIS pelanggan.',
        'Pembayaran QRIS Rp200.000 sukses dari Sari K.',
        'QRIS Rp15.000 diterima. Saldo GoPay Merchant bertambah.',
      ],
    },

    // ── DANA ────────────────────────────────────────────────
    {
      'title': 'DANA',
      'package': 'id.dana',
      'messages': [
        'Pembayaran QRIS Rp85.000,00 sukses diterima.',
        'Transaksi QRIS Rp200.000,00 berhasil. Saldo DANA bertambah.',
        'QRIS berhasil! Kamu menerima Rp45.000,00',
        'Pembayaran QRIS Rp175.000,00 sukses diterima dari Gastonyk Official',
        'Kamu menerima transfer masuk sebesar Rp 350.000 dari KURNIAWAN',
      ],
    },

    // ── OVO ─────────────────────────────────────────────────
    {
      'title': 'OVO',
      'package': 'ovo.id',
      'messages': [
        'OVO QRIS Rp60.000 berhasil diterima.',
        'Pembayaran QRIS Rp95.000 sukses. Saldo OVO merchant +Rp95.000',
        'Kamu menerima transfer sebesar Rp50.000 dari BUDI',
        'Pembayaran QRIS Rp185.000 berhasil diterima dari Pembeli Jersey',
      ],
    },

    // ── SHOPEEPAY ───────────────────────────────────────────
    {
      'title': 'ShopeePay',
      'package': 'com.shopeepay.id',
      'messages': [
        'ShopeePay: Pembayaran QRIS Rp33.000 diterima.',
        'Kamu menerima transfer saldo ShopeePay sebesar Rp 25.000 dari SITI',
        'ShopeePay: Pembayaran QRIS Rp120.000 diterima untuk Pesanan Gastonyk',
      ],
    },

    // ── SEABANK ─────────────────────────────────────────────
    {
      'title': 'SeaBank',
      'package': 'com.seabank.seabank',
      'messages': [
        'Kamu menerima transfer masuk sebesar Rp 100.000 dari SITI RAHMAWATI',
        'Transaksi QRIS sebesar Rp 75.000 berhasil diterima.',
        'Kamu menerima transfer masuk sebesar Rp 240.000 dari HENDRA SETIAWAN',
      ],
    },

    // ── JAGO ────────────────────────────────────────────────
    {
      'title': 'Bank Jago',
      'package': 'com.jago.digitalBanking',
      'messages': [
        'Kamu menerima Rp50.000 dari AHMAD ke Kantong Utama',
        'Ada uang masuk sebesar Rp 250.000 dari BUDI SANTOSO',
        'Kamu menerima Rp175.000 dari RIZKY ke Kantong Toko',
      ],
    },

    // ── BCA MOBILE ──────────────────────────────────────────
    {
      'title': 'BCA Mobile',
      'package': 'com.bca',
      'messages': [
        'm-Transfer: Rp 500.000,00 dari BUDI SANTOSO telah masuk ke rek 1234567890',
        'Pembayaran QRIS Rp75.000 BERHASIL ke Toko Berkah',
        'm-Transfer: Rp 175.000,00 dari ARDIANTO telah masuk ke rek 1234567890',
      ],
    },

    // ── LIVIN BY MANDIRI ────────────────────────────────────
    {
      'title': 'Livin',
      'package': 'id.co.mandiri.livin',
      'messages': [
        'Transfer Masuk: Dana sebesar Rp 300.000,00 dari SITI RAHMAWATI telah masuk ke rekening Anda',
        'Pembayaran QRIS Rp150.000 berhasil diterima dari Rudi',
        'Transfer Masuk: Dana sebesar Rp 175.000,00 dari FAJAR ALFIAN telah masuk ke rekening Anda',
      ],
    },

    // ── WONDR BY BNI ────────────────────────────────────────
    {
      'title': 'wondr by BNI',
      'package': 'id.co.bni.mobilebanking',
      'messages': [
        'Transfer Masuk: Rp 100.000 dari AHMAD ke rekening 1234***',
        'Transaksi QRIS Rp50.000 berhasil diterima',
        'Transfer Masuk: Rp 210.000 dari DANIEL MARTHIN ke rekening 1234***',
      ],
    },
  ];

  /// Inject satu notifikasi demo secara acak.
  /// Kembalikan TransactionModel atau null jika parsing gagal.
  static Future<TransactionModel?> injectRandom() async {
    final random = Random();

    final scenario = _scenarios[random.nextInt(_scenarios.length)];
    final messages = scenario['messages'] as List<String>;
    final message = messages[random.nextInt(messages.length)];

    final transaction = QrisParser.parse(
      title: scenario['title'] as String,
      body: message,
      package: scenario['package'] as String,
    );

    if (transaction != null) {
      return TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: transaction.amount,
        type: transaction.type, // ← kode kanal dinamis e.g. dana_in, bca_in, qris_in
        appSource: transaction.appSource,
        payerName: transaction.payerName,
        dateTime: DateTime.now(),
        rawMessage: transaction.rawMessage,
        appPackage: transaction.appPackage,
      );
    }

    return null;
  }

  /// Buat beberapa transaksi sekaligus untuk demo awal.
  /// Berguna saat pertama kali buka app agar tidak kosong.
  static Future<List<TransactionModel>> generateInitialData() async {
    final List<TransactionModel> result = [];
    // Generate 5 transaksi dengan selisih waktu
    for (int i = 0; i < 5; i++) {
      final t = await injectRandom();
      if (t != null) {
        final adjustedTime = DateTime.now().subtract(
          Duration(minutes: (i + 1) * 23 + Random().nextInt(15)),
        );
        result.add(TransactionModel(
          id: (DateTime.now().millisecondsSinceEpoch - i * 1000).toString(),
          amount: t.amount,
          type: t.type,
          appSource: t.appSource,
          payerName: t.payerName,
          dateTime: adjustedTime,
          rawMessage: t.rawMessage,
          appPackage: t.appPackage,
        ));
      }
    }
    return result;
  }
}
