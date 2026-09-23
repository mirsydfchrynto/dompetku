// ============================================================
// FILE: permission_screen.dart
//
// TUJUAN: Panduan step-by-step & aktivasi izin Android 24/7
//
// Meliputi:
//   1. Notification Access (Membaca notifikasi bank & QRIS)
//   2. Doze Mode / Battery Optimization Immunity (Bebas deep sleep 24 jam)
//   3. Autostart Xiaomi / HyperOS / MIUI (Keep-alive saat reboot & idle)
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_listener_service.dart';
import '../services/battery_optimization_service.dart';
import 'home_screen.dart';

class PermissionScreen extends StatefulWidget {
  final bool isFromSettings;

  const PermissionScreen({super.key, this.isFromSettings = false});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _hasNotificationPermission = false;
  bool _isIgnoringBattery = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final notif = await AppNotificationListenerService.hasPermission();
    final battery =
        await BatteryOptimizationService.isIgnoringBatteryOptimizations();

    if (mounted) {
      setState(() {
        _hasNotificationPermission = notif;
        _isIgnoringBattery = battery;
        _isLoading = false;
      });

      // Jika dibuka dari onboarding awal dan semua izin sudah beres, langsung arahkan ke Home
      if (!widget.isFromSettings && notif && battery) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: widget.isFromSettings
          ? AppBar(
              title: Text(
                'Panduan Izin & Standby 24 Jam',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0.5,
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── HEADER ─────────────────────────────────
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00796B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 32,
                        color: Color(0xFF00796B),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Kesiapan Layanan\n24 Jam Non-Stop',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Agar pembayaran web tidak pernah terlewat saat HP ditinggal tidur, aktifkan kedua izin krusial di bawah:',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade700,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── KARTU IZIN 1: NOTIFICATION ACCESS ──────
                    _PermissionCard(
                      icon: Icons.notifications_active_rounded,
                      title: '1. Akses Notifikasi Android',
                      subtitle:
                          'Membaca notifikasi pembayaran bank & QRIS secara real-time.',
                      isGranted: _hasNotificationPermission,
                      actionText: _hasNotificationPermission
                          ? 'Sudah Aktif'
                          : 'Aktifkan Akses Notifikasi',
                      onAction: () async {
                        await AppNotificationListenerService
                            .openPermissionSettings();
                      },
                    ),

                    const SizedBox(height: 14),

                    // ── KARTU IZIN 2: BATTERY OPTIMIZATION ─────
                    _PermissionCard(
                      icon: Icons.battery_charging_full_rounded,
                      title: '2. Bebaskan dari Hemat Baterai (Doze Mode)',
                      subtitle:
                          'Mencegah Android mematikan aplikasi saat layar mati (Standby 24/7).',
                      isGranted: _isIgnoringBattery,
                      actionText: _isIgnoringBattery
                          ? 'Bebas Standby 24 Jam'
                          : 'Bypass Hemat Baterai',
                      onAction: () async {
                        await BatteryOptimizationService
                            .requestIgnoreBatteryOptimizations();
                      },
                    ),

                    const SizedBox(height: 14),

                    // ── KARTU KHUSUS: XIAOMI / HYPEROS / MIUI ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.smartphone_rounded,
                                size: 20,
                                color: Colors.orange.shade900,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pengguna Xiaomi / HyperOS / MIUI:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Aktifkan "Autostart" dan setel Battery Saver ke "No restrictions" agar HP Xiaomi tidak membekukan service di malam hari.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await BatteryOptimizationService
                                    .openAutostartSettings();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade900,
                                side: BorderSide(color: Colors.orange.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                              ),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text(
                                'Buka Pengaturan Autostart Xiaomi',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── TOMBOL NAVIGASI LANJUT ───────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (widget.isFromSettings) {
                            Navigator.pop(context);
                          } else {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isFromSettings
                              ? 'Selesai'
                              : (_hasNotificationPermission
                                  ? 'Masuk ke Aplikasi'
                                  : 'Lewati — Gunakan Demo Mode'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Widget Kartu Izin Interaktif ─────────────────────────────
class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final String actionText;
  final VoidCallback onAction;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        isGranted ? const Color(0xFF00796B) : Colors.amber.shade800;
    final statusBg = isGranted ? const Color(0xFFE0F2F1) : Colors.amber.shade50;
    final statusText = isGranted ? 'AKTIF' : 'BELUM AKTIF';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted ? const Color(0xFFB2DFDB) : Colors.grey.shade300,
          width: 1.2,
        ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGranted
                      ? const Color(0xFF00796B).withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isGranted
                      ? const Color(0xFF00796B)
                      : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: isGranted
                    ? Colors.grey.shade200
                    : const Color(0xFF00796B),
                foregroundColor:
                    isGranted ? Colors.grey.shade800 : Colors.white,
                elevation: isGranted ? 0 : 1,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(
                isGranted ? Icons.check_circle_rounded : Icons.open_in_new_rounded,
                size: 16,
                color: isGranted ? const Color(0xFF00796B) : Colors.white,
              ),
              label: Text(
                actionText,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isGranted ? Colors.grey.shade800 : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
