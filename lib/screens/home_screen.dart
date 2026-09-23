// ============================================================
// FILE: home_screen.dart
//
// TUJUAN: Halaman utama aplikasi — ini yang pertama dilihat user
//
// KONSEP FLUTTER yang diajarkan di sini:
//   - StatefulWidget: widget yang punya state (data berubah)
//   - setState(): cara memberitahu Flutter untuk rebuild UI
//   - initState(): kode yang dijalankan saat widget pertama dibuat
//   - ListView.builder: list yang efisien (hanya render yang terlihat)
//   - RefreshIndicator: "pull to refresh" gesture
//   - FloatingActionButton: tombol mengambang di pojok
//
// PERBEDAAN StatelessWidget vs StatefulWidget:
//   StatelessWidget = tampilan statis, tidak berubah
//   StatefulWidget  = tampilan dinamis, bisa berubah saat ada data baru
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/notification_listener_service.dart';
import '../services/webhook_service.dart';
import '../services/csv_exporter.dart';
import '../utils/formatter.dart';
import '../widgets/transaction_card.dart';
import '../widgets/summary_banner.dart';
import '../widgets/empty_state.dart';
import 'detail_screen.dart';
import 'webhook_settings_screen.dart';
import 'education_guide_screen.dart';
import 'permission_screen.dart';

class HomeScreen extends StatefulWidget {
  // StatefulWidget: butuh State karena list transaksi bisa berubah

  const HomeScreen({super.key});

  // createState() membuat objek State yang akan mengelola data
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Konvensi nama: awali dengan _ (private) dan akhiri State
class _HomeScreenState extends State<HomeScreen> {
  // ── STATE VARIABLES ──────────────────────────────────────
  // Variabel-variabel ini adalah "state" — data yang bisa berubah
  // dan menyebabkan UI di-rebuild

  List<TransactionModel> _transactions = []; // Semua transaksi
  double _todayIncome = 0; // Total nominal masuk hari ini
  int _todayIncomeCount = 0; // Jumlah transaksi masuk hari ini
  bool _isLoading = true; // Sedang memuat data?
  String _selectedFilter = 'Semua'; // Filter aktif
  String _webhookUrl = ''; // URL webhook backend
  bool _isWebhookEnabled = true; // Status aktif webhook
  bool _isListenerActive = false; // Status listener Android service
  int _failedWebhookCount = 0; // Jumlah webhook gagal / belum terkirim
  bool _isRetryingQueue = false; // Status proses retry antrean
  Timer? _retryTimer; // Timer background auto-retry per 3 menit

  // Filter yang tersedia
  static const List<String> _filters = [
    'Semua',
    'Uang Masuk',
    'GoPay',
    'DANA',
    'OVO',
    'ShopeePay',
    'SeaBank',
    'Jago',
    'BCA Mobile',
    'Livin Mandiri',
    'BRImo',
    'wondr by BNI',
  ];

  // ── LIFECYCLE METHODS ────────────────────────────────────

  @override
  void initState() {
    // initState dipanggil SATU KALI saat widget pertama dibuat
    // Gunakan untuk: load data awal, setup listener, dll

    super.initState(); // Selalu panggil super.initState() dulu!

    // 1. Muat data dari database
    _loadData();

    // 2. Setup periodic auto-retry setiap 3 menit untuk transaksi offline buffer
    _retryTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _autoRetryQueue();
    });

    // 3. Daftarkan callback untuk notifikasi baru
    // Ketika ada transaksi baru dari NotificationListener,
    // fungsi ini dipanggil → refresh UI otomatis
    AppNotificationListenerService.onNewTransaction = (transaction) {
      if (mounted) {
        setState(() {
          _transactions.insert(0, transaction);
          final now = DateTime.now();
          if (transaction.dateTime.day == now.day &&
              transaction.dateTime.month == now.month &&
              transaction.dateTime.year == now.year) {
            _todayIncome += transaction.amount;
            _todayIncomeCount++;
          }
        });

        _refreshFailedCount();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${transaction.appSource}: ${transaction.displayAmount} berhasil dicatat',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00796B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };

    // Callback saat status webhook selesai dikirim di background
    AppNotificationListenerService.onTransactionUpdated = (updated) {
      if (mounted) {
        setState(() {
          final idx = _transactions.indexWhere((t) => t.id == updated.id);
          if (idx != -1) {
            _transactions[idx] = updated;
          }
        });
        _refreshFailedCount();
      }
    };

    // 4. Mulai listener (jika izin sudah ada)
    _startAndCheckListener();
  }

  Future<void> _startAndCheckListener() async {
    final started = await AppNotificationListenerService.startListening();
    if (mounted) {
      setState(() => _isListenerActive = started);
    }
  }

  Future<void> _restartListener() async {
    await AppNotificationListenerService.stopListening();
    final started = await AppNotificationListenerService.startListening();
    if (mounted) {
      setState(() => _isListenerActive = started);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                started ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  started
                      ? 'Listener Service berhasil diaktifkan!'
                      : 'Gagal memulai listener. Pastikan izin aktif di Settings.',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor:
              started ? const Color(0xFF00796B) : Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    AppNotificationListenerService.onNewTransaction = null;
    AppNotificationListenerService.onTransactionUpdated = null;
    super.dispose();
  }

  // ── DATA LOADING ─────────────────────────────────────────

  /// Muat semua data dari database dan update state.
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final transactions = await DatabaseService.getAllTransactions();
    final todayIncome = await DatabaseService.getTodayIncome();
    final todayIncomeCount = await DatabaseService.getTodayIncomeCount();
    final webhookUrl = await DatabaseService.getWebhookUrl();
    final isWebhookEnabled = await DatabaseService.isAutoForwardEnabled();
    final failedCount = await DatabaseService.getFailedWebhookCount();

    if (mounted) {
      setState(() {
        _transactions = transactions;
        _todayIncome = todayIncome;
        _todayIncomeCount = todayIncomeCount;
        _webhookUrl = webhookUrl;
        _isWebhookEnabled = isWebhookEnabled;
        _failedWebhookCount = failedCount;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshFailedCount() async {
    final count = await DatabaseService.getFailedWebhookCount();
    if (mounted) {
      setState(() => _failedWebhookCount = count);
    }
  }

  Future<void> _autoRetryQueue() async {
    if (_failedWebhookCount > 0 && !_isRetryingQueue && mounted) {
      setState(() => _isRetryingQueue = true);
      await WebhookService.retryFailedTransactions();
      if (mounted) {
        await _loadData();
        setState(() => _isRetryingQueue = false);
      }
    }
  }

  Future<void> _manualRetryQueue() async {
    if (_isRetryingQueue) return;
    setState(() => _isRetryingQueue = true);
    final result = await WebhookService.retryFailedTransactions();
    if (mounted) {
      await _loadData();
      if (!mounted) return;
      setState(() => _isRetryingQueue = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pengiriman ulang selesai: ${result.successCount} berhasil, ${result.failedCount} gagal.',
          ),
          backgroundColor: result.failedCount == 0
              ? const Color(0xFF00796B)
              : Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ── EXPORT CSV ───────────────────────────────────────────

  Future<void> _exportCsv() async {
    try {
      final filePath = await CsvExporter.exportTransactions(_transactions);
      await CsvExporter.shareFile(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── RESET DATA ───────────────────────────────────────────

  Future<void> _confirmReset() async {
    // Tampilkan dialog konfirmasi sebelum hapus semua
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Data?'),
        content: const Text(
          'Semua transaksi akan dihapus. Ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.clearAll();
      _loadData(); // Reload untuk tampilkan daftar kosong
    }
  }

  // ── FILTER ───────────────────────────────────────────────

  /// Ambil transaksi yang sesuai filter aktif.
  List<TransactionModel> get _filteredTransactions {
    if (_selectedFilter == 'Semua') return _transactions;
    if (_selectedFilter == 'Uang Masuk') {
      return _transactions.where((t) => t.isIncoming).toList();
    }
    return _transactions
        .where((t) => t.appSource == _selectedFilter)
        .toList();
  }

  // ── BUILD UI ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // build() dipanggil setiap kali setState() dipanggil
    // Flutter sangat efisien — hanya rebuild bagian yang berubah

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DompetKu',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                letterSpacing: -0.3,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListenerActive
                        ? const Color(0xFF00897B)
                        : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isListenerActive
                      ? 'Listener Aktif (Foreground)'
                      : 'Listener Menunggu Izin',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isListenerActive
                        ? const Color(0xFF00796B)
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          // Tombol Export CSV
          if (_transactions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
          // Menu tambahan
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'permission') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const PermissionScreen(isFromSettings: true),
                  ),
                );
              }
              if (value == 'restart_listener') _restartListener();
              if (value == 'reset') _confirmReset();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'permission',
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Panduan Izin HP'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restart_listener',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF00796B)),
                    SizedBox(width: 8),
                    Text('Restart Listener'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus Semua', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      // ── BODY UTAMA ──────────────────────────────────────
      body: RefreshIndicator(
        // RefreshIndicator: tarik ke bawah untuk refresh
        onRefresh: _loadData,
        color: const Color(0xFF00897B),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                // CustomScrollView memungkinkan campuran SliverList
                // dan widget biasa dalam satu scroll
                slivers: [
                  // ── SUMMARY BANNER ─────────────────────
                  SliverToBoxAdapter(
                    child: SummaryBanner(
                      totalIncome: _todayIncome,
                      countIncome: _todayIncomeCount,
                      isLoading: _isLoading,
                    ),
                  ),

                  // ── FAILED WEBHOOK OFFLINE BUFFER BANNER ──
                  if (_failedWebhookCount > 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFFD54F),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cloud_off_rounded,
                                color: Color(0xFFE65100),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_failedWebhookCount Transaksi Belum Terkirim',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'Tersimpan aman di buffer HP. Otomatis dicoba setiap 3 menit.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.brown.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isRetryingQueue
                                    ? null
                                    : _manualRetryQueue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE65100),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isRetryingQueue
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Kirim Ulang'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── QUICK ACTION STRIP (2-KOLOM BERDAMPINGAN) ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                      child: Row(
                        children: [
                          // Kartu Webhook
                          Expanded(
                            child: _QuickActionCard(
                              icon: _webhookUrl.isNotEmpty && _isWebhookEnabled
                                  ? Icons.cloud_done_rounded
                                  : Icons.cloud_queue_rounded,
                              iconColor:
                                  _webhookUrl.isNotEmpty && _isWebhookEnabled
                                      ? const Color(0xFF00796B)
                                      : Colors.grey.shade600,
                              title: 'Webhook Server',
                              subtitle: _webhookUrl.isNotEmpty
                                  ? (_isWebhookEnabled
                                      ? 'Aktif (Auto-POST)'
                                      : 'Dinonaktifkan')
                                  : 'Belum Diatur',
                              badgeText:
                                  _webhookUrl.isNotEmpty && _isWebhookEnabled
                                      ? 'LIVE'
                                      : 'OFF',
                              badgeColor:
                                  _webhookUrl.isNotEmpty && _isWebhookEnabled
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const WebhookSettingsScreen(),
                                  ),
                                );
                                _loadData();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Kartu Edukasi & Panduan
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.school_rounded,
                              iconColor: const Color(0xFF00796B),
                              title: 'Pusat Edukasi',
                              subtitle: 'Panduan & Alur QRIS',
                              badgeText: 'INFO',
                              badgeColor: const Color(0xFF00796B),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const EducationGuideScreen(),
                                  ),
                                );
                                _loadData();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── FILTER CHIPS ────────────────────────
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filters.length,
                        itemBuilder: (ctx, i) {
                          final filter = _filters[i];
                          final isSelected = filter == _selectedFilter;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: Text(filter),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() => _selectedFilter = filter);
                              },
                              selectedColor:
                                  const Color(0xFF00897B).withValues(alpha: 0.2),
                              checkmarkColor: const Color(0xFF00897B),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF00897B)
                                    : Colors.grey.shade700,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ── DAFTAR TRANSAKSI ────────────────────
                  _filteredTransactions.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: const EmptyState(),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, index) {
                              final transaction =
                                  _filteredTransactions[index];

                              // Tampilkan header tanggal
                              Widget? header;
                              if (index == 0) {
                                header = _DateHeader(
                                  date: transaction.dateTime,
                                );
                              } else {
                                final prev =
                                    _filteredTransactions[index - 1];
                                final prevDate = DateTime(
                                  prev.dateTime.year,
                                  prev.dateTime.month,
                                  prev.dateTime.day,
                                );
                                final currDate = DateTime(
                                  transaction.dateTime.year,
                                  transaction.dateTime.month,
                                  transaction.dateTime.day,
                                );
                                if (prevDate != currDate) {
                                  header = _DateHeader(
                                    date: transaction.dateTime,
                                  );
                                }
                              }

                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (header != null) header,
                                  TransactionCard(
                                    transaction: transaction,
                                    onTap: () {
                                      // Navigasi ke detail screen
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DetailScreen(
                                            transaction: transaction,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                            childCount: _filteredTransactions.length,
                          ),
                        ),

                  // Extra padding di bawah
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 32),
                  ),
                ],
              ),
      ),

      floatingActionButton: null,
    );
  }
}

// ── Widget Header Tanggal ────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        Formatter.dateGroupHeader(date),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Widget Kartu Aksi Cepat (Quick Access Strip) ─────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

