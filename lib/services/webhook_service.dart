// ============================================================
// FILE: webhook_service.dart
//
// TUJUAN: Mengirim data notifikasi ke server backend melalui HTTP POST
//
// SKEMA BACKEND:
//   Tabel: webhook_notif [id, message, created_at]
//   Payload: { "message": "..." }
//
// FITUR:
//   - Format payload teks raw & format JSON string terstruktur
//   - Pengiriman otomatis saat notifikasi masuk
//   - Timeout 10 detik dengan error handling lengkap
//   - Test ping koneksi ke endpoint tunneling (ngrok / Cloudflare / IP lokal)
//   - Mendukung custom authorization header / API key
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import 'database_service.dart';

class WebhookResult {
  final bool isSuccess;
  final int? statusCode;
  final String? errorMessage;

  const WebhookResult({
    required this.isSuccess,
    this.statusCode,
    this.errorMessage,
  });

  @override
  String toString() {
    if (isSuccess) {
      return 'Sukses ($statusCode)';
    }
    return 'Gagal${statusCode != null ? ' ($statusCode)' : ''}: $errorMessage';
  }
}

class RetryQueueResult {
  final int totalProcessed;
  final int successCount;
  final int failedCount;

  const RetryQueueResult({
    required this.totalProcessed,
    required this.successCount,
    required this.failedCount,
  });

  @override
  String toString() =>
      'Diproses: $totalProcessed, Berhasil: $successCount, Gagal: $failedCount';
}

class WebhookService {
  static const Duration _timeout = Duration(seconds: 10);

  /// Menghasilkan tanda tangan digital HMAC-SHA256 sesuai standar WebhookVerifierService.
  static String generateHmacSignature(
    String secret,
    String payload,
    int timestamp,
  ) {
    final message = '$timestamp.$payload';
    final key = utf8.encode(secret);
    final bytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  /// Helper untuk membangun header HTTP request.
  static Map<String, String> _buildHeaders(
    String? authHeader, {
    String? url,
    String? secret,
    String? body,
    int? timestamp,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Otomatis tambahkan bypass-tunnel-reminder untuk LocalTunnel (loca.lt)
    if (url != null && url.contains('loca.lt')) {
      headers['bypass-tunnel-reminder'] = 'true';
    }

    // HMAC-SHA256 Cryptographic Signature Headers (Anti-tamper & Anti-replay)
    if (secret != null &&
        secret.trim().isNotEmpty &&
        body != null &&
        timestamp != null) {
      final sig = generateHmacSignature(secret.trim(), body, timestamp);
      headers['X-Dompetku-Timestamp'] = timestamp.toString();
      headers['X-Dompetku-Signature'] = sig;
    }

    if (authHeader != null && authHeader.trim().isNotEmpty) {
      final trimmed = authHeader.trim();
      final lines = trimmed.split(RegExp(r'[\r\n;]+'));
      for (final line in lines) {
        final l = line.trim();
        if (l.isEmpty) continue;
        if (l.contains(':')) {
          final parts = l.split(':');
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            headers[key] = value;
          }
        } else {
          headers['Authorization'] = l;
        }
      }
    }

    return headers;
  }

  /// Membuat string payload isi kolom `message` sesuai preferensi.
  static String formatMessage(TransactionModel transaction, String format) {
    if (format == 'json_string') {
      final map = <String, dynamic>{
        'id': transaction.id,
        if (transaction.orderCode != null) 'order_code': transaction.orderCode,
        'appSource': transaction.appSource,
        'amount': transaction.amount,
        'formattedAmount': transaction.formattedAmount,
        'payerName': transaction.payerName,
        'type': transaction.type,
        'dateTime': transaction.dateTime.toIso8601String(),
        'rawMessage': transaction.rawMessage,
      };
      return jsonEncode(map);
    }

    // Default: Raw text format (Title: Body/RawMessage)
    if (transaction.rawMessage.startsWith(transaction.appSource)) {
      return transaction.rawMessage;
    }
    return '${transaction.appSource}: ${transaction.rawMessage}';
  }

  /// Mencoba pengiriman ke endpoint failover cadangan jika tersedia.
  static Future<http.Response?> _tryFallbackPost(
    http.Client httpClient, {
    required String primaryUrl,
    required String body,
    required String authHeader,
    required String webhookSecret,
    required int timestamp,
  }) async {
    final fallbackUrl = await DatabaseService.getFallbackWebhookUrl();
    if (fallbackUrl.isNotEmpty && fallbackUrl != primaryUrl) {
      try {
        final fallbackUri = Uri.parse(fallbackUrl);
        final fallbackHeaders = _buildHeaders(
          authHeader,
          url: fallbackUrl,
          secret: webhookSecret,
          body: body,
          timestamp: timestamp,
        );
        return await httpClient
            .post(
              fallbackUri,
              headers: fallbackHeaders,
              body: body,
            )
            .timeout(_timeout);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Mengirim transaksi ke endpoint webhook.
  static Future<WebhookResult> sendTransaction(
    TransactionModel transaction, {
    http.Client? client,
    bool forceSend = false,
  }) async {
    final httpClient = client ?? http.Client();
    String webhookUrl = '';
    String authHeader = '';
    String webhookSecret = '';
    String body = '';
    int timestamp = 0;

    try {
      webhookUrl = await DatabaseService.getWebhookUrl();
      final isEnabled = await DatabaseService.isAutoForwardEnabled();

      // Jika URL belum diset dan tidak dipaksa
      if (webhookUrl.isEmpty) {
        final updated = transaction.copyWith(
          webhookStatus: 'disabled',
          webhookError: 'URL webhook belum diatur',
        );
        await DatabaseService.updateTransaction(updated);
        return const WebhookResult(
          isSuccess: false,
          errorMessage: 'URL webhook belum diatur',
        );
      }

      if (!isEnabled && !forceSend) {
        final updated = transaction.copyWith(
          webhookStatus: 'disabled',
          webhookError: 'Auto forward dinonaktifkan',
        );
        await DatabaseService.updateTransaction(updated);
        return const WebhookResult(
          isSuccess: false,
          errorMessage: 'Auto forward dinonaktifkan',
        );
      }

      authHeader = await DatabaseService.getAuthHeader();
      webhookSecret = await DatabaseService.getWebhookSecret();
      final payloadFormat = await DatabaseService.getPayloadFormat();
      final messageContent = formatMessage(transaction, payloadFormat);

      final payloadMap = <String, dynamic>{
        'message': messageContent,
        'amount': transaction.amount,
        'id': transaction.id,
        'appSource': transaction.appSource,
        if (transaction.orderCode != null) 'order_code': transaction.orderCode,
      };

      body = jsonEncode(payloadMap);
      timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final headers = _buildHeaders(
        authHeader,
        url: webhookUrl,
        secret: webhookSecret,
        body: body,
        timestamp: timestamp,
      );
      final uri = Uri.parse(webhookUrl);

      http.Response response = await httpClient
          .post(
            uri,
            headers: headers,
            body: body,
          )
          .timeout(_timeout);

      // Jika server utama merespons 500-504 (Server Error / Bad Gateway / Gateway Timeout),
      // otomatis coba kirim ke endpoint failover sebelum menyerah
      if (response.statusCode >= 500 && response.statusCode <= 504) {
        final fallbackResp = await _tryFallbackPost(
          httpClient,
          primaryUrl: webhookUrl,
          body: body,
          authHeader: authHeader,
          webhookSecret: webhookSecret,
          timestamp: timestamp,
        );
        if (fallbackResp != null &&
            fallbackResp.statusCode >= 200 &&
            fallbackResp.statusCode < 300) {
          response = fallbackResp;
        }
      }

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      final updated = transaction.copyWith(
        webhookStatus: isSuccess ? 'success' : 'failed',
        webhookHttpCode: response.statusCode,
        webhookSentAt: DateTime.now(),
        webhookError: isSuccess
            ? null
            : 'Server merespons ${response.statusCode}: ${response.body.isNotEmpty ? (response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body) : 'Error'}',
      );
      await DatabaseService.updateTransaction(updated);

      return WebhookResult(
        isSuccess: isSuccess,
        statusCode: response.statusCode,
        errorMessage: isSuccess ? null : 'HTTP ${response.statusCode}',
      );
    } on TimeoutException {
      // ── FAILOVER UPON TIMEOUT ──────────────────────────────
      final fallbackResp = await _tryFallbackPost(
        httpClient,
        primaryUrl: webhookUrl,
        body: body,
        authHeader: authHeader,
        webhookSecret: webhookSecret,
        timestamp: timestamp,
      );
      if (fallbackResp != null &&
          fallbackResp.statusCode >= 200 &&
          fallbackResp.statusCode < 300) {
        final updated = transaction.copyWith(
          webhookStatus: 'success',
          webhookHttpCode: fallbackResp.statusCode,
          webhookSentAt: DateTime.now(),
          webhookError: null,
        );
        await DatabaseService.updateTransaction(updated);
        return WebhookResult(
          isSuccess: true,
          statusCode: fallbackResp.statusCode,
        );
      }

      final updated = transaction.copyWith(
        webhookStatus: 'failed',
        webhookSentAt: DateTime.now(),
        webhookError: 'Request timeout (10 detik)',
      );
      await DatabaseService.updateTransaction(updated);
      return const WebhookResult(
        isSuccess: false,
        errorMessage: 'Request timeout (10 detik)',
      );
    } on SocketException catch (e) {
      // ── FAILOVER UPON SOCKET EXCEPTION ─────────────────────
      final fallbackResp = await _tryFallbackPost(
        httpClient,
        primaryUrl: webhookUrl,
        body: body,
        authHeader: authHeader,
        webhookSecret: webhookSecret,
        timestamp: timestamp,
      );
      if (fallbackResp != null &&
          fallbackResp.statusCode >= 200 &&
          fallbackResp.statusCode < 300) {
        final updated = transaction.copyWith(
          webhookStatus: 'success',
          webhookHttpCode: fallbackResp.statusCode,
          webhookSentAt: DateTime.now(),
          webhookError: null,
        );
        await DatabaseService.updateTransaction(updated);
        return WebhookResult(
          isSuccess: true,
          statusCode: fallbackResp.statusCode,
        );
      }

      final updated = transaction.copyWith(
        webhookStatus: 'failed',
        webhookSentAt: DateTime.now(),
        webhookError: 'Koneksi gagal: ${e.message}',
      );
      await DatabaseService.updateTransaction(updated);
      return WebhookResult(
        isSuccess: false,
        errorMessage: 'Koneksi gagal: ${e.message}',
      );
    } on FormatException catch (e) {
      final updated = transaction.copyWith(
        webhookStatus: 'failed',
        webhookSentAt: DateTime.now(),
        webhookError: 'URL tidak valid: ${e.message}',
      );
      await DatabaseService.updateTransaction(updated);
      return WebhookResult(
        isSuccess: false,
        errorMessage: 'URL tidak valid: ${e.message}',
      );
    } catch (e) {
      final updated = transaction.copyWith(
        webhookStatus: 'failed',
        webhookSentAt: DateTime.now(),
        webhookError: e.toString(),
      );
      await DatabaseService.updateTransaction(updated);
      return WebhookResult(
        isSuccess: false,
        errorMessage: e.toString(),
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Test ping koneksi ke endpoint URL dengan payload dummy.
  static Future<WebhookResult> testConnection(
    String url, {
    String? authHeader,
    String? secret,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();

    try {
      final cleanUrl = url.trim();
      if (cleanUrl.isEmpty) {
        return const WebhookResult(
          isSuccess: false,
          errorMessage: 'URL tidak boleh kosong',
        );
      }

      final uri = Uri.parse(cleanUrl);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return const WebhookResult(
          isSuccess: false,
          errorMessage: 'Format URL tidak valid (contoh: https://... atau http://...)',
        );
      }

      final body = jsonEncode({
        'action': 'ping',
        'event': 'ping',
        'message': 'Test koneksi webhook dari DompetKu Xiaomi (ping)',
      });
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final headers = _buildHeaders(
        authHeader,
        url: cleanUrl,
        secret: secret,
        body: body,
        timestamp: timestamp,
      );

      final response = await httpClient
          .post(
            uri,
            headers: headers,
            body: body,
          )
          .timeout(_timeout);

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      return WebhookResult(
        isSuccess: isSuccess,
        statusCode: response.statusCode,
        errorMessage: isSuccess
            ? null
            : 'Server merespons ${response.statusCode}: ${response.body.isNotEmpty ? (response.body.length > 80 ? '${response.body.substring(0, 80)}...' : response.body) : 'Error'}',
      );
    } on TimeoutException {
      return const WebhookResult(
        isSuccess: false,
        errorMessage: 'Koneksi timeout (10 detik). Pastikan server/tunneling aktif.',
      );
    } on SocketException catch (e) {
      return WebhookResult(
        isSuccess: false,
        errorMessage: 'Gagal terhubung ke host: ${e.message}',
      );
    } on FormatException catch (e) {
      return WebhookResult(
        isSuccess: false,
        errorMessage: 'Format URL tidak valid: ${e.message}',
      );
    } catch (e) {
      return WebhookResult(
        isSuccess: false,
        errorMessage: 'Error: $e',
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  static bool _isRetryingQueue = false;

  /// Cek apakah proses retry queue sedang berjalan
  static bool get isRetryingQueue => _isRetryingQueue;

  /// Melakukan batch retry untuk semua transaksi berstatus 'failed' atau 'pending'.
  /// Dilindungi oleh mutex `_isRetryingQueue` agar tidak terjadi race condition / dobel kirim.
  static Future<RetryQueueResult> retryFailedTransactions({
    http.Client? client,
    int limit = 20,
    Duration delayBetweenRequests = const Duration(milliseconds: 150),
  }) async {
    if (_isRetryingQueue) {
      return const RetryQueueResult(
        totalProcessed: 0,
        successCount: 0,
        failedCount: 0,
      );
    }

    _isRetryingQueue = true;
    int successCount = 0;
    int failedCount = 0;

    try {
      final queue = await DatabaseService.getFailedOrPendingTransactions(
        limit: limit,
      );
      if (queue.isEmpty) {
        return const RetryQueueResult(
          totalProcessed: 0,
          successCount: 0,
          failedCount: 0,
        );
      }

      final httpClient = client ?? http.Client();

      try {
        for (final tx in queue) {
          final result = await sendTransaction(
            tx,
            client: httpClient,
            forceSend: true,
          );

          if (result.isSuccess) {
            successCount++;
          } else {
            failedCount++;
          }

          if (delayBetweenRequests > Duration.zero) {
            await Future.delayed(delayBetweenRequests);
          }
        }
      } finally {
        if (client == null) {
          httpClient.close();
        }
      }

      return RetryQueueResult(
        totalProcessed: queue.length,
        successCount: successCount,
        failedCount: failedCount,
      );
    } finally {
      _isRetryingQueue = false;
    }
  }
}

