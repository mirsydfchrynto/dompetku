// ============================================================
// FILE: transaction_card.dart
//
// TUJUAN: Widget kartu untuk menampilkan SATU transaksi
//
// FITUR:
//   - Monogram inisial fintech bersih (tanpa emot lingkaran amatir)
//   - 100% responsif & anti-overflow (FittedBox, Flexible, ConstrainedBox)
//   - Badge status webhook ringkas
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../utils/formatter.dart';
import 'app_logo_widget.dart';

// Warna identitas per e-wallet & bank
const Map<String, Color> kAppColors = {
  'GoPay': Color(0xFF00897B), // Hijau GoPay
  'DANA': Color(0xFF118EEA), // Biru DANA
  'OVO': Color(0xFF4C3494), // Ungu OVO
  'ShopeePay': Color(0xFFEE4D2D), // Oranye Shopee
  'SeaBank': Color(0xFFFF5722), // Oranye Merah SeaBank
  'Jago': Color(0xFF00BCD4), // Cyan Jago
  'BCA Mobile': Color(0xFF003688), // Biru BCA
  'myBCA': Color(0xFF003688), // Biru BCA
  'Livin Mandiri': Color(0xFF0A3960), // Biru Mandiri
  'BRImo': Color(0xFF00529C), // Biru BRI
  'wondr by BNI': Color(0xFF005E5D), // Toska BNI
  'BNI Mobile': Color(0xFFE55300), // Oranye BNI
  'Neobank': Color(0xFFFFB300), // Kuning Amber BNC
  'Jenius': Color(0xFF00A3E0), // Biru Muda Jenius
  'Permata ME': Color(0xFF86BC25), // Hijau Permata
  'OCTO Mobile': Color(0xFFED1C24), // Merah CIMB Niaga
  'LinkAja': Color(0xFFE31B23), // Merah LinkAja
  'Simulator': Color(0xFF00897B), // Hijau Simulator
};

/// Monogram inisial fintech bersih (menggantikan emot lingkaran)
String getAppMonogram(String source) {
  switch (source) {
    case 'GoPay':
      return 'GP';
    case 'DANA':
      return 'DA';
    case 'OVO':
      return 'OVO';
    case 'ShopeePay':
      return 'SP';
    case 'SeaBank':
      return 'SEA';
    case 'Jago':
      return 'JAGO';
    case 'BCA Mobile':
    case 'myBCA':
      return 'BCA';
    case 'Livin Mandiri':
      return 'LIV';
    case 'BRImo':
      return 'BRI';
    case 'wondr by BNI':
    case 'BNI Mobile':
      return 'BNI';
    case 'Neobank':
      return 'BNC';
    case 'Jenius':
      return 'JEN';
    case 'Permata ME':
      return 'PER';
    case 'OCTO Mobile':
      return 'OCTO';
    case 'LinkAja':
      return 'LA';
    case 'Simulator':
      return 'SIM';
    default:
      if (source.length >= 3) {
        return source.substring(0, 3).toUpperCase();
      }
      return 'QR';
  }
}

class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  Widget _buildWebhookBadge() {
    if (transaction.webhookStatus == 'success') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.shade200, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done, size: 9, color: Colors.green.shade700),
            const SizedBox(width: 2),
            Text(
              '${transaction.webhookHttpCode ?? 200}',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      );
    } else if (transaction.webhookStatus == 'failed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade200, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 9, color: Colors.red.shade700),
            const SizedBox(width: 2),
            Text(
              'Gagal',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      );
    } else if (transaction.webhookStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue.shade200, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync, size: 9, color: Colors.blue.shade700),
            const SizedBox(width: 2),
            Text(
              'Kirim',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ── KOLOM KIRI: Logo Resmi Fintech / Bank ──
              AppLogoWidget(
                appSource: transaction.appSource,
                size: 44,
                borderRadius: 10,
              ),

              const SizedBox(width: 12),

              // ── KOLOM TENGAH: Info Transaksi ───────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            transaction.appSource,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: transaction.isIncoming
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: transaction.isIncoming
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            transaction.isIncoming ? 'MASUK' : 'KELUAR',
                            style: TextStyle(
                              fontSize: 8,
                              color: transaction.isIncoming
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (transaction.type == 'demo' ||
                            transaction.type.startsWith('demo') ||
                            transaction.type.startsWith('simulator')) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              transaction.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 7.5,
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.isIncoming
                                ? (transaction.payerName != 'Pelanggan'
                                    ? 'Dari: ${transaction.payerName}'
                                    : 'Pembayar: Pelanggan')
                                : (transaction.payerName.startsWith('Tarik Tunai')
                                    ? transaction.payerName
                                    : 'Ke: ${transaction.payerName}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (transaction.orderCode != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFA5D6A7),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              transaction.orderCode!,
                              style: const TextStyle(
                                fontSize: 8,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── KOLOM KANAN: Nominal + Status ──────────
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 135),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            transaction.isIncoming
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
                            size: 13,
                            color: transaction.isIncoming
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            transaction.displayAmount,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: transaction.isIncoming
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildWebhookBadge(),
                        if (transaction.webhookStatus != 'none')
                          const SizedBox(width: 4),
                        Text(
                          Formatter.time(transaction.dateTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
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
