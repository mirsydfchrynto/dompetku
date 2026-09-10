// ============================================================
// FILE: detail_screen.dart
//
// TUJUAN: Detail satu transaksi — menyajikan informasi transaksi,
//         pesan notifikasi asli, serta integrasi webhook backend
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/webhook_service.dart';
import '../utils/formatter.dart';
import '../widgets/app_logo_widget.dart';

class DetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const DetailScreen({super.key, required this.transaction});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TransactionModel _transaction;
  String _webhookUrl = '';
  String _payloadFormat = 'raw';
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _loadWebhookConfig();
  }

  Future<void> _loadWebhookConfig() async {
    final url = await DatabaseService.getWebhookUrl();
    final format = await DatabaseService.getPayloadFormat();
    if (mounted) {
      setState(() {
        _webhookUrl = url;
        _payloadFormat = format;
      });
    }
  }

  Future<void> _retryWebhook() async {
    if (_webhookUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL webhook belum diatur di menu Pengaturan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isRetrying = true);

    final result = await WebhookService.sendTransaction(
      _transaction,
      forceSend: true,
    );

    final updated = await DatabaseService.getTransaction(_transaction.id);

    if (mounted) {
      setState(() {
        _isRetrying = false;
        if (updated != null) {
          _transaction = updated;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.isSuccess
                      ? 'Berhasil dikirim ke backend (HTTP ${result.statusCode})'
                      : 'Gagal: ${result.errorMessage}',
                ),
              ),
            ],
          ),
          backgroundColor:
              result.isSuccess ? const Color(0xFF00897B) : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildWebhookStatusBadge() {
    switch (_transaction.webhookStatus) {
      case 'success':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Terkirim (${_transaction.webhookHttpCode ?? 200})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'failed':
        final codeText = _transaction.webhookHttpCode != null
            ? '${_transaction.webhookHttpCode}'
            : 'Error';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Gagal ($codeText)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  'Mengirim...',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            'Belum Dikirim',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final payloadPreview = jsonEncode({
      'message': WebhookService.formatMessage(_transaction, _payloadFormat),
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Detail Transaksi',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HERO: Nominal besar ────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AppLogoWidget(
                    appSource: _transaction.appSource,
                    size: 64,
                    borderRadius: 16,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _transaction.appSource,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        _transaction.displayAmount,
                        style: GoogleFonts.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: _transaction.isIncoming
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _transaction.isIncoming
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _transaction.isIncoming
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _transaction.isIncoming
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              size: 14,
                              color: _transaction.isIncoming
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _transaction.isIncoming
                                  ? 'Pembayaran Masuk'
                                  : 'Transaksi Keluar',
                              style: TextStyle(
                                color: _transaction.isIncoming
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_transaction.type == 'demo' ||
                          _transaction.type.startsWith('demo') ||
                          _transaction.type.startsWith('simulator'))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Text(
                            _transaction.type.toUpperCase(),
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── INFO DETAIL ─────────────────────────────────
            _InfoSection(
              title: 'Informasi Transaksi',
              children: [
                _InfoRow(label: 'Via', value: _transaction.appSource),
                _InfoRow(
                  label: _transaction.isIncoming ? 'Pengirim / Pembayar' : 'Penerima / Tujuan',
                  value: _transaction.payerName,
                ),
                _InfoRow(label: 'Arah Transaksi', value: _transaction.directionLabel),
                _InfoRow(label: 'Tipe Kanal', value: _transaction.type),
                _InfoRow(
                  label: 'Tanggal',
                  value: Formatter.dateLong(_transaction.dateTime),
                ),
                _InfoRow(
                  label: 'Jam',
                  value: Formatter.time(_transaction.dateTime),
                ),
                _InfoRow(label: 'ID Transaksi', value: _transaction.id),
              ],
            ),

            const SizedBox(height: 16),

            // ── INTEGRASI WEBHOOK BACKEND ───────────────────
            _InfoSection(
              title: 'Integrasi Webhook Backend',
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status Pengiriman',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _buildWebhookStatusBadge(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Endpoint Tujuan',
                  value: _webhookUrl.isNotEmpty ? _webhookUrl : 'Belum diatur',
                ),
                if (_transaction.webhookSentAt != null)
                  _InfoRow(
                    label: 'Waktu Kirim',
                    value: Formatter.time(_transaction.webhookSentAt!),
                  ),
                if (_transaction.webhookError != null &&
                    _transaction.webhookStatus == 'failed') ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Detail Error: ${_transaction.webhookError}',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Payload Dikirim:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    payloadPreview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.lightGreenAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _isRetrying ? null : _retryWebhook,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isRetrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      _isRetrying
                          ? 'Mengirim Ulang...'
                          : 'Kirim Ulang ke Server (Retry Webhook)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── PESAN ASLI: Kunci edukasi! ─────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Pesan Notifikasi Asli',
                        style: TextStyle(
                          color: Colors.green.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _transaction.rawMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: Colors.amberAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Teks di atas adalah pesan notifikasi asli dari ${_transaction.appSource}. '
                            'QrisParser mengekstrak nominal "${_transaction.formattedAmount}" dan WebhookService '
                            'meneruskannya ke tabel webhook_notif backend.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget Helper ────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
