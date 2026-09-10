// ============================================================
// FILE: csv_exporter.dart
//
// TUJUAN: Export data transaksi ke file CSV
//         yang bisa dibuka di Excel / Google Sheets
//
// FORMAT OUTPUT CSV:
//   ID,Tanggal,Jam,Nominal,Via,Pembayar,Pesan
//   1234567890,09/09/2026,14:30,50000,GoPay,Budi S.,"GoPay: Pembayaran..."
//
// ALUR:
//   1. Ambil semua transaksi dari database
//   2. Konversi ke format List<List<dynamic>>
//   3. Ubah ke string CSV
//   4. Simpan ke file di folder Dokumen HP
//   5. Share via WhatsApp / Email / dll
// ============================================================

import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';

class CsvExporter {
  /// Export transaksi ke file CSV dan kembalikan path file.
  static Future<String> exportTransactions(
      List<TransactionModel> transactions) async {
    // LANGKAH 1: Buat baris header (nama kolom)
    final headers = [
      'ID',
      'Tanggal',
      'Jam',
      'Nominal (Rp)',
      'Via',
      'Pembayar',
      'Tipe',
      'Pesan Asli',
    ];

    // LANGKAH 2: Konversi tiap transaksi ke satu baris
    final rows = transactions.map((t) {
      return [
        t.id,
        DateFormat('dd/MM/yyyy').format(t.dateTime),
        DateFormat('HH:mm').format(t.dateTime),
        t.amount.toStringAsFixed(0), // Tanpa desimal: "50000"
        t.appSource,
        t.payerName,
        t.type == 'demo' ? 'Demo' : t.type.toUpperCase(),
        // Ganti newline dengan spasi agar tidak rusak di CSV
        t.rawMessage.replaceAll('\n', ' | '),
      ];
    }).toList();

    // LANGKAH 3: Gabungkan header + rows
    final allRows = [headers, ...rows];

    // LANGKAH 4: Konversi ke string CSV
    // ListToCsvConverter dari package 'csv'
    final csvString = const ListToCsvConverter().convert(allRows);

    // LANGKAH 5: Simpan ke file di folder Dokumen HP
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filename = 'dompetku_$timestamp.csv';
    final filePath = '${directory.path}/$filename';

    final file = File(filePath);
    // Tulis dengan encoding UTF-8 agar karakter Indonesia terbaca
    await file.writeAsString(csvString, encoding: utf8);

    return filePath;
  }

  /// Share file CSV ke aplikasi lain (WA, Gmail, dll).
  static Future<void> shareFile(String filePath) async {
    final xFile = XFile(filePath);
    await Share.shareXFiles(
      [xFile],
      subject:
          'Data QRIS DompetKu ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
      text: 'Data transaksi QRIS dari aplikasi DompetKu',
    );
  }
}
