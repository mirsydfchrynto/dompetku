// ============================================================
// FILE: formatter.dart
//
// TUJUAN: Fungsi-fungsi pembantu untuk format tampilan
//
// Menggunakan package 'intl' untuk format lokal Indonesia:
//   - Format Rupiah: 50000 → "Rp 50.000"
//   - Format tanggal: DateTime → "09 Sep 2026"
//   - Format jam: DateTime → "14:30"
// ============================================================

import 'package:intl/intl.dart';

class Formatter {
  // Format mata uang Rupiah
  // Contoh: 50000.0 → "Rp 50.000"
  static String currency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID', // Lokal Indonesia
      symbol: 'Rp ', // Simbol Rupiah
      decimalDigits: 0, // Tidak pakai desimal
    );
    return formatter.format(amount);
  }

  // Format tanggal panjang
  // Contoh: "09 September 2026"
  static String dateLong(DateTime dt) {
    return DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
  }

  // Format tanggal pendek
  // Contoh: "09/09/2026"
  static String dateShort(DateTime dt) {
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  // Format jam
  // Contoh: "14:30"
  static String time(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  // Format untuk header grup di ListView
  // Contoh: "Hari ini", "Kemarin", atau "08 Sep 2026"
  static String dateGroupHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Hari ini';
    if (date == today.subtract(const Duration(days: 1))) return 'Kemarin';
    return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
  }

  // Format untuk export CSV: "20260909_1430"
  static String fileTimestamp(DateTime dt) {
    return DateFormat('yyyyMMdd_HHmm').format(dt);
  }
}
