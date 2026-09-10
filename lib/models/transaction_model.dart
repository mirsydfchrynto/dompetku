// ============================================================
// FILE: transaction_model.dart
//
// TUJUAN: "Formulir digital" untuk satu transaksi QRIS
//
// Setiap kali ada pembayaran QRIS masuk, sistem membuat
// satu objek TransactionModel dan menyimpannya ke database.
//
// FIELD yang tersimpan:
//   id        : nomor unik (pakai milliseconds sejak 1970)
//   amount    : nominal dalam Rupiah (50000.0)
//   type      : channel kode ("dana_in", "seabank_in", "gopay_in", dll), atau "demo"
//   appSource : nama e-wallet / bank ("GoPay", "DANA", "SeaBank", dll)
//   payerName : nama pembayar jika ada
//   dateTime  : kapan terjadi
//   rawMessage: pesan notifikasi asli (penting untuk belajar!)
//   appPackage: package name Android ("com.gojek.gopay")
// ============================================================

import 'package:hive/hive.dart';

// Baris ini menghubungkan ke file yang akan di-generate otomatis
// Jalankan: flutter pub run build_runner build
part 'transaction_model.g.dart';

// @HiveType memberi tahu Hive bahwa class ini bisa disimpan
// typeId = 0 adalah nomor unik untuk class ini
@HiveType(typeId: 0)
class TransactionModel extends HiveObject {
  // @HiveField(0) = urutan field di database (jangan diubah!)
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount; // Nominal: 50000.0 = Rp 50.000

  @HiveField(2)
  final String type; // "dana_in", "seabank_in", "gopay_in", "demo", dll

  @HiveField(3)
  final String appSource; // "GoPay", "DANA", "OVO", "ShopeePay", "Jago"

  @HiveField(4)
  final String payerName; // Nama pembayar: "Budi S." atau "Pelanggan"

  @HiveField(5)
  final DateTime dateTime; // Waktu transaksi

  @HiveField(6)
  final String rawMessage; // Pesan asli dari notifikasi (untuk edukasi)

  @HiveField(7)
  final String appPackage; // Package: "com.gojek.gopay"

  @HiveField(8)
  final String webhookStatus; // "disabled", "pending", "success", "failed"

  @HiveField(9)
  final int? webhookHttpCode; // 200, 404, 500, dll

  @HiveField(10)
  final String? webhookError; // Pesan error jika gagal kirim

  @HiveField(11)
  final DateTime? webhookSentAt; // Waktu pengiriman ke webhook

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.appSource,
    required this.payerName,
    required this.dateTime,
    required this.rawMessage,
    required this.appPackage,
    this.webhookStatus = 'disabled',
    this.webhookHttpCode,
    this.webhookError,
    this.webhookSentAt,
  });

  TransactionModel copyWith({
    String? id,
    double? amount,
    String? type,
    String? appSource,
    String? payerName,
    DateTime? dateTime,
    String? rawMessage,
    String? appPackage,
    String? webhookStatus,
    int? webhookHttpCode,
    String? webhookError,
    DateTime? webhookSentAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      appSource: appSource ?? this.appSource,
      payerName: payerName ?? this.payerName,
      dateTime: dateTime ?? this.dateTime,
      rawMessage: rawMessage ?? this.rawMessage,
      appPackage: appPackage ?? this.appPackage,
      webhookStatus: webhookStatus ?? this.webhookStatus,
      webhookHttpCode: webhookHttpCode ?? this.webhookHttpCode,
      webhookError: webhookError ?? this.webhookError,
      webhookSentAt: webhookSentAt ?? this.webhookSentAt,
    );
  }

  // ── HELPER PROPERTIES ────────────────────────────────────

  // Format Rupiah: 50000.0 → "Rp 50.000"
  String get formattedAmount {
    final numStr = amount.toStringAsFixed(0);
    // Tambahkan titik setiap 3 digit dari kanan
    final buffer = StringBuffer();
    int count = 0;
    for (int i = numStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(numStr[i]);
      count++;
    }
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  // Apakah ini transaksi masuk? (diakhiri '_in', 'demo', dan bukan '_out' / 'keluar')
  bool get isIncoming => !type.endsWith('_out') && !type.contains('keluar');

  // Apakah ini transaksi keluar?
  bool get isOutgoing => !isIncoming;

  // Label arah transaksi ("Uang Masuk" atau "Uang Keluar")
  String get directionLabel => isIncoming ? 'Uang Masuk' : 'Uang Keluar';

  // Format nominal dengan tanda + atau - (misal: "+ Rp 50.000" atau "- Rp 50.000")
  String get displayAmount => '${isIncoming ? '+' : '-'} $formattedAmount';
}
