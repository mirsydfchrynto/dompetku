// ============================================================
// FILE: notification_listener_service.dart
//
// TUJUAN: Jembatan antara Android dan Flutter
//
// ALUR DATA:
//   [Notif masuk di HP]
//       ↓
//   [Android OS meneruskan ke NotificationListenerService]
//       ↓ (via Platform Channel / Method Channel)
//   [Flutter menerima event di sini]
//       ↓
//   [QrisParser.parse() → TransactionModel]
//       ↓
//   [DatabaseService.saveTransaction()]
//       ↓
//   [onNewTransaction() → refresh UI]
//
// Package: flutter_notification_listener
// Docs: https://pub.dev/packages/flutter_notification_listener
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'qris_parser.dart';
import 'database_service.dart';
import 'webhook_service.dart';
import '../models/transaction_model.dart';

// ── TOP-LEVEL CALLBACK ────────────────────────────────────────
// PENTING: Harus berupa top-level function beranotasi @pragma('vm:entry-point')
// agar Dart VM AOT runtime pada native Android engine dapat memanggilnya
// secara langsung tanpa mengalami batasan isolasi class.
@pragma('vm:entry-point')
void dompetkuNotificationCallback(NotificationEvent event) {
  AppNotificationListenerService.handleIncomingNotification(event);
}

@pragma('vm:entry-point')
class AppNotificationListenerService {
  // Callback yang dipanggil setiap ada transaksi baru terdeteksi.
  // HomeScreen mendaftarkan dirinya di sini untuk refresh otomatis.
  static Function(TransactionModel)? onNewTransaction;

  // Callback saat status transaksi di-update (misal: webhook status berubah)
  static Function(TransactionModel)? onTransactionUpdated;

  // ── START LISTENING ───────────────────────────────────────

  /// Mulai mendengarkan notifikasi Android.
  /// Berjalan sebagai Foreground Service agar tidak dimatikan oleh sistem Android / Xiaomi HyperOS.
  static Future<bool> startListening() async {
    try {
      await DatabaseService.ensureInitialized();

      // Initialize: siapkan channel komunikasi Flutter ↔ Android dengan top-level callback
      await NotificationsListener.initialize(
        callbackHandle: dompetkuNotificationCallback,
      );

      // Mulai service di background dengan notifikasi foreground resmi
      final started = await NotificationsListener.startService(
        foreground: true,
        title: "DompetKu Aktif",
        description: "Memonitor notifikasi pembayaran QRIS & e-wallet...",
      );

      debugPrint('[DompetKu] Notification Listener Service started: $started');
      return started ?? false;
    } catch (e, stack) {
      debugPrint('[DompetKu] Error starting notification listener: $e\n$stack');
      return false;
    }
  }

  /// Cek apakah listener service sedang aktif berjalan
  static Future<bool> isServiceRunning() async {
    try {
      return await NotificationsListener.isRunning ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Hentikan listener (saat app ditutup atau user menonaktifkan).
  static Future<void> stopListening() async {
    try {
      await NotificationsListener.stopService();
      debugPrint('[DompetKu] Notification Listener Service stopped');
    } catch (e) {
      debugPrint('[DompetKu] Error stopping notification listener: $e');
    }
  }

  // ── CALLBACK: Dipanggil setiap ada notifikasi baru ────────

  @pragma('vm:entry-point')
  static Future<void> handleIncomingNotification(NotificationEvent event) async {
    try {
      final title = event.title ?? '';
      final body = event.text ?? '';
      final package = event.packageName ?? '';

      debugPrint('[DompetKu] Received event: pkg=$package, title=$title, body=$body');

      // Pastikan environment database lokal siap
      await DatabaseService.ensureInitialized();

      // Coba parse notifikasi menjadi model transaksi QRIS / e-wallet
      final transaction = QrisParser.parse(
        title: title,
        body: body,
        package: package,
      );

      if (transaction != null) {
        final isDuplicate =
            await DatabaseService.isDuplicateTransaction(transaction);
        if (isDuplicate) {
          debugPrint(
            '[DompetKu] Transaksi duplikat diabaikan: ${transaction.appSource} '
            'Rp ${transaction.amount} (${transaction.payerName})',
          );
          return;
        }

        debugPrint(
            '[DompetKu] QRIS Transaksi terdeteksi: ${transaction.appSource} Rp ${transaction.amount}');
        await _processAndForward(transaction);
      } else {
        // Jika bukan format finansial standar, cek apakah user mengaktifkan tangkap semua notifikasi
        final onlyFinancial = await DatabaseService.isForwardFinancialOnly();
        if (!onlyFinancial && (title.isNotEmpty || body.isNotEmpty)) {
          final rawTx = TransactionModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            amount: 0,
            type: 'raw_notif',
            appSource: title.isNotEmpty ? title : 'Notifikasi',
            payerName: 'Sistem',
            dateTime: DateTime.now(),
            rawMessage: title.isNotEmpty ? '$title: $body' : body,
            appPackage: package,
          );
          final isDuplicate =
              await DatabaseService.isDuplicateTransaction(rawTx);
          if (isDuplicate) {
            debugPrint('[DompetKu] Notifikasi raw duplikat diabaikan');
            return;
          }
          await _processAndForward(rawTx);
        }
      }
    } catch (e, stack) {
      debugPrint('[DompetKu] Error in handleIncomingNotification: $e\n$stack');
    }
  }

  /// Proses penyimpanan lokal dan pengiriman webhook secara aman.
  static Future<void> _processAndForward(TransactionModel transaction) async {
    try {
      final isAutoForward = await DatabaseService.isAutoForwardEnabled();
      final initialTx = isAutoForward
          ? transaction.copyWith(webhookStatus: 'pending')
          : transaction;

      // 1. Simpan ke database lokal
      await DatabaseService.saveTransaction(initialTx);

      // 2. Panggil callback untuk refresh UI langsung (jika UI aktif)
      onNewTransaction?.call(initialTx);

      // 3. Jika auto-forward aktif, kirim ke server di background
      if (isAutoForward) {
        await WebhookService.sendTransaction(initialTx);
        final updated = await DatabaseService.getTransaction(initialTx.id);
        if (updated != null) {
          onTransactionUpdated?.call(updated);
        }

        // Flush buffer offline jika ada antrean tertunda dari saat HP offline
        unawaited(WebhookService.retryFailedTransactions().catchError((err) {
          debugPrint('[DompetKu] Background retry error: $err');
          return const RetryQueueResult(
            totalProcessed: 0,
            successCount: 0,
            failedCount: 0,
          );
        }));
      }
    } catch (e, stack) {
      debugPrint('[DompetKu] Error in _processAndForward: $e\n$stack');
    }
  }

  // ── PERMISSION ────────────────────────────────────────────

  /// Cek apakah user sudah memberikan izin Notification Access.
  static Future<bool> hasPermission() async {
    return await NotificationsListener.hasPermission ?? false;
  }

  /// Buka halaman Settings Android untuk aktifkan izin.
  static Future<void> openPermissionSettings() async {
    await NotificationsListener.openPermissionSettings();
  }
}
