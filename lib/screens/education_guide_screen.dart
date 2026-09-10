// ============================================================
// FILE: education_guide_screen.dart
//
// TUJUAN: Pusat Edukasi, Alur Kerja, Simulator Interaktif, dan
//         Kamus Istilah Digital lengkap untuk pemula & pengembang.
//
// FITUR UNGGULAN:
//   1. Tab Alur Kerja (Pipeline): Visualisasi perjalanan notifikasi
//      dari push Android, ekstraksi parser, filter anti-OTP,
//      hingga pengiriman webhook ke server cloud.
//   2. Tab Simulator Interaktif: Playground pengujian notifikasi
//      dengan tampilan notifikasi Android nyata (lengkap dengan logo bank asli),
//      ekstraksi data instan, dan tombol kirim langsung ke server aktif.
//   3. Tab Kamus Digital: Penjelasan istilah teknis (Webhook, Regex,
//      Hive, HTTP Status Codes, Tunneling, Payload JSON, dll)
//      dengan bahasa Indonesia yang ramah dan mudah dipahami.
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/qris_parser.dart';
import '../services/webhook_service.dart';
import '../widgets/app_logo_widget.dart';

class EducationGuideScreen extends StatefulWidget {
  const EducationGuideScreen({super.key});

  @override
  State<EducationGuideScreen> createState() => _EducationGuideScreenState();
}

class _EducationGuideScreenState extends State<EducationGuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State Simulator
  final _titleController = TextEditingController(text: 'DANA');
  final _messageController = TextEditingController(
    text: 'Kamu menerima Saldo DANA sebesar Rp 50.000 dari BUDI SANTOSO.',
  );
  String _selectedPackage = 'id.dana';

  TransactionModel? _parsedTransaction;
  bool _isSending = false;
  WebhookResult? _sendResult;
  String _activeWebhookUrl = '';

  final List<Map<String, String>> _templates = [
    // ── UANG MASUK (INCOMING) ─────────────────────────────────
    {
      'name': '📥 DANA Masuk Rp 50.000',
      'title': 'DANA',
      'package': 'id.dana',
      'message': 'Kamu menerima Saldo DANA sebesar Rp 50.000 dari BUDI SANTOSO.',
    },
    {
      'name': '📥 SeaBank Masuk Rp 100.000',
      'title': 'SeaBank',
      'package': 'com.seabank.seabank',
      'message': 'Kamu menerima transfer masuk sebesar Rp 100.000 dari SITI RAHMAWATI',
    },
    {
      'name': '📥 ShopeePay QRIS Rp 33.000',
      'title': 'ShopeePay',
      'package': 'com.shopeepay.id',
      'message': 'ShopeePay: Pembayaran QRIS Rp33.000 diterima.',
    },
    {
      'name': '📥 Bank Jago Rp 250.000',
      'title': 'Bank Jago',
      'package': 'com.jago.digitalBanking',
      'message': 'Kamu menerima Rp250.000 dari AHMAD ke Kantong Utama',
    },
    {
      'name': '📥 BCA Mobile Rp 500.000',
      'title': 'm-BCA',
      'package': 'com.bca',
      'message': 'm-Transfer: Rp 500.000,00 dari BUDI SANTOSO telah masuk ke rek 1234567890',
    },
    // ── UANG KELUAR (OUTGOING) ────────────────────────────────
    {
      'name': '📤 DANA Tarik Tunai Rp 50.000',
      'title': 'DANA',
      'package': 'id.dana',
      'message': 'Kamu berhasil menarik uang sebesar Rp 50.000 di Alfamart',
    },
    {
      'name': '📤 SeaBank Transfer Keluar Rp 100.000',
      'title': 'SeaBank',
      'package': 'com.seabank.seabank',
      'message': 'Kamu berhasil transfer ke rekening BCA sebesar Rp 100.000',
    },
    {
      'name': '📤 BRImo Tarik Tunai Rp 100.000',
      'title': 'BRImo',
      'package': 'id.co.bri.brimo',
      'message': 'Tarik tunai Rp 100.000 berhasil di ATM BRI',
    },
    {
      'name': '📤 Livin Bayar Tagihan Rp 150.000',
      'title': 'Livin',
      'package': 'id.co.mandiri.livin',
      'message': 'Pembayaran tagihan listrik Rp 150.000 berhasil',
    },
    {
      'name': '📤 DANA Transfer ke Budi Rp 50.000',
      'title': 'DANA',
      'package': 'id.dana',
      'message': 'Kamu berhasil transfer uang ke Budi sebesar Rp 50.000',
    },
    // ── FILTER ANTI-PROMO & ANTI-OTP (OTOMATIS DITOLAK) ──────
    {
      'name': '🚫 Uji Promo Diskon (Ditolak)',
      'title': 'Shopee',
      'package': 'com.shopee.id',
      'message': 'Dapatkan voucher diskon 50% hingga Rp 50.000 belanja hari ini!',
    },
    {
      'name': '🚫 Uji Promo Cashback (Ditolak)',
      'title': 'DANA',
      'package': 'id.dana',
      'message': 'Promo cashback 20% menantimu untuk semua transaksi DANA Deals!',
    },
    {
      'name': '🚫 Uji Kode OTP (Ditolak)',
      'title': 'DANA',
      'package': 'id.dana',
      'message': 'KODE OTP: 849201. JANGAN BERIKAN KODE INI KEPADA SIAPAPUN!',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWebhookUrl();
    _reparse();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadWebhookUrl() async {
    final url = await DatabaseService.getWebhookUrl();
    if (mounted) {
      setState(() => _activeWebhookUrl = url);
    }
  }

  void _applyTemplate(Map<String, String> template) {
    setState(() {
      _titleController.text = template['title']!;
      _messageController.text = template['message']!;
      _selectedPackage = template['package']!;
      _sendResult = null;
    });
    _reparse();
  }

  void _reparse() {
    final parsed = QrisParser.parse(
      title: _titleController.text.trim(),
      body: _messageController.text.trim(),
      package: _selectedPackage,
    );
    setState(() {
      _parsedTransaction = parsed;
      _sendResult = null;
    });
  }

  Future<void> _sendSimulatorToBackend() async {
    if (_parsedTransaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifikasi ini terfilter sebagai promosi, OTP, atau bukan transaksi finansial valid.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _sendResult = null;
    });

    final txToSave = TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: _parsedTransaction!.amount,
      type: _parsedTransaction!.type,
      appSource: _parsedTransaction!.appSource,
      payerName: _parsedTransaction!.payerName,
      dateTime: DateTime.now(),
      rawMessage: _parsedTransaction!.rawMessage,
      appPackage: _parsedTransaction!.appPackage,
      webhookStatus: 'pending',
    );

    await DatabaseService.saveTransaction(txToSave);

    final result = await WebhookService.sendTransaction(
      txToSave,
      forceSend: true,
    );

    if (mounted) {
      setState(() {
        _isSending = false;
        _sendResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Pusat Edukasi & Simulator',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00897B),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF00897B),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Alur Kerja'),
            Tab(icon: Icon(Icons.play_circle_outline), text: 'Simulator'),
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Kamus'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPipelineTab(),
          _buildSimulatorTab(),
          _buildDictionaryTab(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB 1: ALUR KERJA (PIPELINE)
  // ══════════════════════════════════════════════════════════
  Widget _buildPipelineTab() {
    final supportedBanks = [
      'DANA', 'SeaBank', 'ShopeePay', 'GoPay',
      'OVO', 'Jago', 'BCA Mobile', 'Livin Mandiri',
      'BRImo', 'wondr by BNI', 'Neobank', 'Jenius'
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00897B).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00897B).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.insights, color: Color(0xFF00897B), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Perjalanan data otomatis dari saat notifikasi bank masuk di HP hingga tersimpan di cloud database backend:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _StepCard(
          stepNumber: '1',
          title: 'Notifikasi Finansial di Android OS',
          subtitle: 'Aplikasi bank/e-wallet memunculkan push notifikasi resmi saat transaksi masuk atau keluar terjadi.',
          codeSnippet: 'Title: "DANA"\nText: "Kamu menerima Saldo DANA sebesar Rp 50.000 dari BUDI"',
          badgeText: 'Level: Android System Notification',
          badgeColor: Colors.blue,
        ),
        _StepArrow(),

        _StepCard(
          stepNumber: '2',
          title: 'Ditangkap oleh Background Listener',
          subtitle: 'NotificationListenerService DompetKu membaca push notifikasi secara real-time dan aman.',
          codeSnippet: 'NotificationListenerService.handleIncomingNotification(\n  title, body, packageName\n)',
          badgeText: 'Level: Foreground Service Android',
          badgeColor: Colors.indigo,
        ),
        _StepArrow(),

        _StepCard(
          stepNumber: '3',
          title: 'Analisis QrisParser & Filter Cerdas',
          subtitle: 'Mendeteksi nominal uang, membedakan arah transaksi (Masuk/Keluar), nama pihak, memblokir spam promo & OTP, serta menetapkan kanal dinamis (*_in / *_out).',
          codeSnippet: 'final tx = QrisParser.parse(title, body, package);\n// Masuk:  tx.type = "dana_in"\n// Keluar: tx.type = "dana_out"',
          badgeText: 'Level: Smart Parsing Engine',
          badgeColor: Colors.teal,
        ),
        _StepArrow(),

        _StepCard(
          stepNumber: '4',
          title: 'Penyimpanan Database Lokal Hive NoSQL',
          subtitle: 'Transaksi disimpan di memori HP agar dapat diakses tanpa kuota internet (offline-first).',
          codeSnippet: 'await DatabaseService.saveTransaction(transaction);',
          badgeText: 'Level: Local Hive NoSQL DB',
          badgeColor: Colors.amber.shade900,
        ),
        _StepArrow(),

        _StepCard(
          stepNumber: '5',
          title: 'Pengiriman Webhook HTTP POST ke Server',
          subtitle: 'Meneruskan payload JSON secara instan ke server backend (Vercel, ngrok Wili/Fauzan).',
          codeSnippet: 'POST https://webhook-server-sand.vercel.app/webhook\nBody: {"message": "..."}\nHeader: Content-Type: application/json',
          badgeText: 'Level: Real-time Cloud Integration',
          badgeColor: Colors.green.shade800,
        ),

        const SizedBox(height: 20),

        // ── KARTU EKOSISTEM RESMI ───────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xFF00897B), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '15+ Bank & E-Wallet Resmi Didukung',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: supportedBanks.map((name) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLogoWidget(appSource: name, size: 22, borderRadius: 5),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB 2: SIMULATOR NOTIFIKASI
  // ══════════════════════════════════════════════════════════
  Widget _buildSimulatorTab() {
    final payloadPreview = _parsedTransaction != null
        ? jsonEncode({
            'message': WebhookService.formatMessage(_parsedTransaction!, 'raw'),
          })
        : '{"message": "(Notifikasi belum valid sebagai transaksi uang masuk)"}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── PILIH TEMPLATE ─────────────────────────────────
        Text(
          'Pilih Notifikasi Simulasi:',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final t = _templates[i];
              return ActionChip(
                avatar: AppLogoWidget(appSource: t['title']!, size: 16, borderRadius: 3),
                label: Text(t['name']!, style: const TextStyle(fontSize: 11.5)),
                onPressed: () => _applyTemplate(t),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // ── PREVIEW NOTIFIKASI ANDROID NYATA ───────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppLogoWidget(
                    appSource: _titleController.text.trim(),
                    size: 28,
                    borderRadius: 6,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _titleController.text.trim(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    'Sekarang',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _messageController.text.trim(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── FORM INPUT NOTIFIKASI ──────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note, color: Color(0xFF00897B)),
                  const SizedBox(width: 8),
                  Text(
                    'Kustomisasi Notifikasi',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const Divider(height: 20),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Judul Notifikasi (Aplikasi / Bank)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (_) => _reparse(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Isi Pesan Notifikasi Asli',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (_) => _reparse(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── HASIL EKSTRAKSI & KIRIM ─────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hasil Ekstraksi Parser',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _parsedTransaction != null
                          ? (_parsedTransaction!.isIncoming
                              ? Colors.green.shade50
                              : Colors.red.shade50)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _parsedTransaction != null
                            ? (_parsedTransaction!.isIncoming
                                ? Colors.green.shade300
                                : Colors.red.shade300)
                            : Colors.grey.shade400,
                      ),
                    ),
                    child: Text(
                      _parsedTransaction != null
                          ? (_parsedTransaction!.isIncoming
                              ? 'UANG MASUK VALID'
                              : 'UANG KELUAR VALID')
                          : 'DITOLAK: PROMO / NON-FINANSIAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _parsedTransaction != null
                            ? (_parsedTransaction!.isIncoming
                                ? Colors.green.shade800
                                : Colors.red.shade800)
                            : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (_parsedTransaction != null) ...[
                _ResultItem(
                  label: 'Nominal Ekstrak',
                  value: _parsedTransaction!.displayAmount,
                  valueColor: _parsedTransaction!.isIncoming
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                _ResultItem(
                  label: 'Arah Transaksi',
                  value: _parsedTransaction!.directionLabel,
                  valueColor: _parsedTransaction!.isIncoming
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                _ResultItem(
                  label: 'Sumber Aplikasi',
                  value: _parsedTransaction!.appSource,
                ),
                _ResultItem(
                  label: 'Tipe Kanal (type)',
                  value: _parsedTransaction!.type,
                  valueColor: const Color(0xFF00897B),
                ),
                _ResultItem(
                  label: _parsedTransaction!.isIncoming
                      ? 'Nama Pengirim'
                      : 'Penerima / Tujuan',
                  value: _parsedTransaction!.payerName,
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pesan ini ditolak secara otomatis oleh Filter Pintar (Anti-Promo / Anti-OTP / Non-Finansial). Database dan webhook Anda terlindungi dari data sampah promosi.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              const Text(
                'JSON Payload yang dikirim ke Webhook:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  payloadPreview,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: Colors.lightGreenAccent,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (_activeWebhookUrl.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.cloud_queue, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Target Server Aktif: $_activeWebhookUrl',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendSimulatorToBackend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSending ? 'Mengirim ke Server...' : 'Kirim Simulasi ke Server',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              if (_sendResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _sendResult!.isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _sendResult!.isSuccess ? Colors.green.shade300 : Colors.red.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sendResult!.isSuccess ? Icons.check_circle : Icons.error_outline,
                        size: 20,
                        color: _sendResult!.isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _sendResult!.isSuccess
                              ? 'Terkirim! Server merespons HTTP ${_sendResult!.statusCode}'
                              : 'Gagal: ${_sendResult!.errorMessage}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _sendResult!.isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB 3: KAMUS KONSEP & ISTILAH LENGKAP
  // ══════════════════════════════════════════════════════════
  Widget _buildDictionaryTab() {
    final terms = [
      {
        'term': 'NotificationListenerService',
        'category': 'Android Native',
        'desc': 'Layanan resmi OS Android yang mengizinkan DompetKu memonitor notifikasi secara real-time. Membutuhkan izin manual dari pengguna di Pengaturan Sistem untuk privasi dan keamanan tingkat tinggi.'
      },
      {
        'term': 'Webhook (Event-Driven HTTP POST)',
        'category': 'Integrasi Backend',
        'desc': 'Metode pengiriman data otomatis layaknya kurir paket yang langsung mengantar begitu barang siap. Berbeda dengan polling (yang harus terus bolak-balik memeriksa server), webhook hanya menembak saat ada mutasi finansial (uang masuk atau keluar).'
      },
      {
        'term': 'Kode Kanal Dinamis (type)',
        'category': 'Model Transaksi',
        'desc': 'Identitas pengenal sumber dan arah dana yang spesifik (misal: dana_in, dana_out, seabank_in, seabank_out, bca_in, bca_out). Memudahkan backend mengelompokkan laporan arus kas masuk maupun keluar per rekening tanpa tercampur.'
      },
      {
        'term': 'Universal Amount Parser (Regex)',
        'category': 'Pengolahan Data',
        'desc': 'Pola ekspresi reguler cerdas yang mengenali seluruh variasi format nominal uang di Indonesia: Rp 50.000,00 (standar BI), IDR 100,000.00 (format internasional), maupun Rp 25.000,- (format kasir).'
      },
      {
        'term': 'Anti-Promo & OTP Shield',
        'category': 'Keamanan & Akurasi Data',
        'desc': 'Lapisan proteksi cerdas yang memilah transaksi nyata dari notifikasi sampah: otomatis menolak promo cashback, voucher diskon belanja, koin, flash sale, pesan sosial, dan kode OTP rahasia agar pembukuan 100% bersih.'
      },
      {
        'term': 'Payer Delimiter Limiter',
        'category': 'Pengolahan Data',
        'desc': 'Algoritma pemotong batas kalimat yang mengekstrak nama pengirim murni (misal: "AHMAD") tanpa tercampur dengan kata tujuan seperti "ke Kantong Utama" atau "telah masuk ke rekening".'
      },
      {
        'term': 'Hive Database (NoSQL)',
        'category': 'Penyimpanan Lokal',
        'desc': 'Database lokal berbasis key-value yang sangat cepat ditulis dengan bahasa Dart. Menyimpan riwayat transaksi di memori internal HP sehingga aplikasi tetap dapat berjalan lancar tanpa koneksi internet.'
      },
      {
        'term': 'HTTP Status 200 & 201 Created',
        'category': 'Networking',
        'desc': 'Kode respons resmi dari server. HTTP 200 berarti permintaan berhasil, sedangkan HTTP 201 (standar server cloud Vercel) menandakan data notifikasi telah sukses dibuat dan disimpan di database backend.'
      },
      {
        'term': 'HTTP Status 401 & 403 (Unauthorized)',
        'category': 'Networking',
        'desc': 'Respons server saat memerlukan Kunci Akses (API Key / Bearer Token). DompetKu menyediakan dialog ramah untuk langsung memasukkan kunci tersebut saat terdeteksi.'
      },
      {
        'term': 'Tunneling (ngrok & cloudflared)',
        'category': 'DevOps & Testing',
        'desc': 'Jembatan jaringan aman yang mengekspos localhost server pengembang di laptop (misal port 8000) ke internet publik sehingga dapat dihubungkan langsung dari HP fisik Xiaomi.'
      },
      {
        'term': 'Payload JSON',
        'category': 'Format Data',
        'desc': 'Format data standar industri untuk pertukaran data antar aplikasi. DompetKu membungkus detail transaksi ke dalam format JSON yang mudah diproses oleh Node.js, Python, Laravel, Go, dll.'
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: terms.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['term']!,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['category']!,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item['desc']!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Widget Helper ────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String subtitle;
  final String codeSnippet;
  final String badgeText;
  final Color badgeColor;

  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.codeSnippet,
    required this.badgeText,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFF00897B),
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              codeSnippet,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Colors.lightGreenAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Icon(Icons.arrow_downward, color: Color(0xFF00897B), size: 18),
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ResultItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
