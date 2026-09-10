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

class WebhookService {
  static const Duration _timeout = Duration(seconds: 10);

  /// Helper untuk membangun header HTTP request.
  static Map<String, String> _buildHeaders(String? authHeader, {String? url}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Otomatis tambahkan bypass-tunnel-reminder untuk LocalTunnel (loca.lt)
    if (url != null && url.contains('loca.lt')) {
      headers['bypass-tunnel-reminder'] = 'true';
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
      final map = {
        'id': transaction.id,
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

  /// Mengirim transaksi ke endpoint webhook.
  static Future<WebhookResult> sendTransaction(
    TransactionModel transaction, {
    http.Client? client,
    bool forceSend = false,
  }) async {
    final httpClient = client ?? http.Client();

    try {
      final webhookUrl = await DatabaseService.getWebhookUrl();
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

      final authHeader = await DatabaseService.getAuthHeader();
      final payloadFormat = await DatabaseService.getPayloadFormat();
      final messageContent = formatMessage(transaction, payloadFormat);

      final body = jsonEncode({
        'message': messageContent,
      });

      final headers = _buildHeaders(authHeader, url: webhookUrl);
      final uri = Uri.parse(webhookUrl);

      final response = await httpClient
          .post(
            uri,
            headers: headers,
            body: body,
          )
          .timeout(_timeout);

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

      final headers = _buildHeaders(authHeader, url: cleanUrl);
      final body = jsonEncode({
        'message': 'Test koneksi webhook dari DompetKu Xiaomi',
      });

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
}
