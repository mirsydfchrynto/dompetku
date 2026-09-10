// ============================================================
// FILE: permission_screen.dart
//
// TUJUAN: Panduan step-by-step untuk aktifkan Notification Access
//
// Layar ini muncul otomatis saat pertama buka app
// jika izin belum diberikan.
//
// Untuk Xiaomi/MIUI ada langkah extra: aktifkan Autostart
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_listener_service.dart';
import 'home_screen.dart';

class PermissionScreen extends StatelessWidget {
  final bool isFromSettings;

  const PermissionScreen({super.key, this.isFromSettings = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: isFromSettings
          ? AppBar(
              title: Text(
                'Panduan Izin Android',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0.5,
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // ── HEADER ─────────────────────────────────
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          size: 34,
                          color: Color(0xFF00796B),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Aktifkan Izin\nNotifikasi',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'DompetKu perlu akses notifikasi untuk menangkap '
                        'pembayaran QRIS secara otomatis.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── LANGKAH-LANGKAH ─────────────────────────
                      Text(
                        'Cara Mengaktifkan:',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Langkah 1
                      const _StepItem(
                        number: '1',
                        title: 'Buka Settings',
                        subtitle:
                            'Tekan tombol di bawah untuk membuka Settings Android',
                        icon: Icons.settings,
                      ),

                      // Langkah 2
                      const _StepItem(
                        number: '2',
                        title: 'Cari "Notification Access"',
                        subtitle:
                            'Ketik "notification" di kolom pencarian Settings Android',
                        icon: Icons.search,
                      ),

                      // Langkah 3
                      const _StepItem(
                        number: '3',
                        title: 'Aktifkan DompetKu',
                        subtitle:
                            'Geser toggle di samping "DompetKu" ke posisi ON',
                        icon: Icons.toggle_on,
                      ),

                      // Khusus Xiaomi
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.smartphone_rounded,
                              size: 20,
                              color: Colors.orange.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pengguna Xiaomi / HyperOS / MIUI:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Juga aktifkan "Autostart" dan setel Battery Saver ke "No restrictions" di:\nSettings ➔ Apps ➔ DompetKu',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // ── TOMBOL AKSI ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await AppNotificationListenerService
                                .openPermissionSettings();

                            if (context.mounted && !isFromSettings) {
                              Future.delayed(const Duration(seconds: 2), () async {
                                final hasPermission =
                                    await AppNotificationListenerService.hasPermission();
                                if (hasPermission && context.mounted) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const HomeScreen(),
                                    ),
                                  );
                                }
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00897B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text(
                            'Buka Settings Sekarang',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Tombol skip atau kembali
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            if (isFromSettings) {
                              Navigator.pop(context);
                            } else {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const HomeScreen(),
                                ),
                              );
                            }
                          },
                          child: Text(
                            isFromSettings
                                ? 'Tutup Panduan'
                                : 'Lewati — Gunakan Demo Mode',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Widget helper untuk satu langkah ─────────────────────────
class _StepItem extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final IconData icon;

  const _StepItem({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nomor langkah (bulat)
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF00897B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
