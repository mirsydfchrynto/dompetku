// ============================================================
// FILE: empty_state.dart
//
// TUJUAN: Tampilan "kosong" ketika belum ada transaksi
//         Memberikan panduan ke user apa yang harus dilakukan
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyState extends StatelessWidget {
  final VoidCallback? onDemoPressed;

  const EmptyState({super.key, this.onDemoPressed});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ilustrasi vektor modern & konsisten
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 36,
                    color: Color(0xFF00796B),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Belum ada transaksi',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Notifikasi pembayaran QRIS & transfer bank\nakan tercatat otomatis saat transaksi masuk.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 16),

              // Tombol Demo untuk coba tanpa transaksi nyata
              OutlinedButton.icon(
                onPressed: onDemoPressed,
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: const Text('Coba Demo Sekarang'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00796B),
                  side: const BorderSide(color: Color(0xFF00796B), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),

              const SizedBox(height: 12),

              // Panduan aktifkan notifikasi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pastikan izin Notification Access sudah aktif di Settings HP',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
