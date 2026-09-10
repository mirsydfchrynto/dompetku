// ============================================================
// FILE: app_logo_widget.dart
//
// TUJUAN: Menampilkan logo resmi bank & e-wallet Indonesia
//         (DANA, SeaBank, ShopeePay, GoPay, OVO, Bank Jago,
//          BCA, Mandiri, BRI, BNI, Neobank, Jenius, dll)
//         dengan fallback mulus ke monogram jika gambar tidak tersedia.
// ============================================================

import 'package:flutter/material.dart';

class AppLogoWidget extends StatelessWidget {
  final String appSource;
  final double size;
  final double borderRadius;

  const AppLogoWidget({
    super.key,
    required this.appSource,
    this.size = 44,
    this.borderRadius = 10,
  });

  static String? getAssetPath(String source) {
    final lower = source.toLowerCase().trim();
    if (lower.contains('dana')) return 'assets/logos/dana.png';
    if (lower.contains('seabank')) return 'assets/logos/seabank.png';
    if (lower.contains('shopee')) return 'assets/logos/shopeepay.png';
    if (lower.contains('gopay') || lower.contains('gojek')) {
      return 'assets/logos/gopay.png';
    }
    if (lower.contains('ovo')) return 'assets/logos/ovo.png';
    if (lower.contains('jago')) return 'assets/logos/jago.png';
    if (lower.contains('bca')) return 'assets/logos/bca.png';
    if (lower.contains('mandiri') || lower.contains('livin')) {
      return 'assets/logos/mandiri.png';
    }
    if (lower.contains('brimo') || lower.contains('bri')) {
      return 'assets/logos/bri.png';
    }
    if (lower.contains('bni') || lower.contains('wondr')) {
      return 'assets/logos/bni.png';
    }
    if (lower.contains('neobank') || lower.contains('bnc')) {
      return 'assets/logos/neobank.png';
    }
    if (lower.contains('jenius') || lower.contains('btpn')) {
      return 'assets/logos/jenius.png';
    }
    if (lower.contains('permata')) return 'assets/logos/permata.png';
    if (lower.contains('octo') || lower.contains('cimb')) {
      return 'assets/logos/octo.png';
    }
    if (lower.contains('linkaja')) return 'assets/logos/linkaja.png';
    return null;
  }

  static Color getBrandColor(String source) {
    final lower = source.toLowerCase().trim();
    if (lower.contains('dana')) return const Color(0xFF118EEA);
    if (lower.contains('seabank')) return const Color(0xFFFF5722);
    if (lower.contains('shopee')) return const Color(0xFFEE4D2D);
    if (lower.contains('gopay') || lower.contains('gojek')) {
      return const Color(0xFF00AED6);
    }
    if (lower.contains('ovo')) return const Color(0xFF4C2A86);
    if (lower.contains('jago')) return const Color(0xFFF37021);
    if (lower.contains('bca')) return const Color(0xFF005DAA);
    if (lower.contains('mandiri') || lower.contains('livin')) {
      return const Color(0xFF003876);
    }
    if (lower.contains('brimo') || lower.contains('bri')) {
      return const Color(0xFF00529C);
    }
    if (lower.contains('bni') || lower.contains('wondr')) {
      return const Color(0xFFF15A24);
    }
    if (lower.contains('neobank') || lower.contains('bnc')) {
      return const Color(0xFFFFD500);
    }
    if (lower.contains('jenius') || lower.contains('btpn')) {
      return const Color(0xFF00A3E0);
    }
    if (lower.contains('permata')) return const Color(0xFF86BC25);
    if (lower.contains('octo') || lower.contains('cimb')) {
      return const Color(0xFFED1C24);
    }
    if (lower.contains('linkaja')) return const Color(0xFFED1C24);
    return const Color(0xFF00897B);
  }

  static String getMonogram(String source) {
    final lower = source.toLowerCase().trim();
    if (lower.contains('dana')) return 'DA';
    if (lower.contains('seabank')) return 'SEA';
    if (lower.contains('shopee')) return 'SP';
    if (lower.contains('gopay') || lower.contains('gojek')) return 'GP';
    if (lower.contains('ovo')) return 'OVO';
    if (lower.contains('jago')) return 'JAGO';
    if (lower.contains('bca')) return 'BCA';
    if (lower.contains('mandiri') || lower.contains('livin')) return 'LIV';
    if (lower.contains('brimo') || lower.contains('bri')) return 'BRI';
    if (lower.contains('bni') || lower.contains('wondr')) return 'BNI';
    if (lower.contains('neobank') || lower.contains('bnc')) return 'BNC';
    if (lower.contains('jenius')) return 'JEN';
    if (lower.contains('permata')) return 'PER';
    if (lower.contains('octo') || lower.contains('cimb')) return 'OCTO';
    if (lower.contains('linkaja')) return 'LINK';
    if (source.length <= 4) return source.toUpperCase();
    return source.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = getAssetPath(appSource);
    final brandColor = getBrandColor(appSource);
    final monogram = getMonogram(appSource);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.18),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 0.8),
        child: assetPath != null
            ? Image.asset(
                assetPath,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) {
                  return _buildFallback(brandColor, monogram);
                },
              )
            : _buildFallback(brandColor, monogram),
      ),
    );
  }

  Widget _buildFallback(Color color, String text) {
    return Container(
      color: color,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.32,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
