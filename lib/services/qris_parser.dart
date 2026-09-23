// ============================================================
// FILE: qris_parser.dart
//
// TUJUAN: "Detektif Pintar" yang membaca push notifikasi finansial
//         UANG MASUK (QRIS Merchant & Transfer Masuk) dari seluruh
//         ekosistem bank dan e-wallet di Indonesia, sekaligus memfilter
//         dan menolak promosi, voucher, OTP, dan SEMUA PENGELUARAN /
//         UANG KELUAR.
//
// FITUR UNGGULAN:
//   1. Deteksi Akurat Uang Masuk (_in):
//      - QRIS merchant, transfer masuk, saldo masuk, top-up.
//      - Menolak / mengabaikan semua transaksi keluar / pengeluaran.
//   2. Filter & Blokir Notifikasi Promosi & Non-Finansial:
//      - Menolak notifikasi promo, voucher, diskon, koin, cashback promo,
//        flash sale, kode OTP/keamanan, pesan chat sosial, dan sistem.
//   3. Universal Amount Parser:
//      - Mendukung format Rupiah Rp, IDR, ribuan titik, desimal koma/titik.
//   4. Smart Party Extractor:
//      - Ekstraksi nama pengirim / pembayar (Uang Masuk).
//   5. 15+ Ekosistem Bank & E-Wallet Resmi + Smart Fallback.
// ============================================================

import '../models/transaction_model.dart';

// ── CLASS KONFIGURASI PER BANK & E-WALLET ────────────────────
class _AppParser {
  final String name;
  final String baseCode;
  final List<String> keywords;
  final RegExp amountPattern;
  final RegExp? payerPattern;

  _AppParser({
    required this.name,
    required this.baseCode,
    required this.keywords,
    required this.amountPattern,
    this.payerPattern,
  });
}

// ── CLASS UTAMA ───────────────────────────────────────────────
class QrisParser {
  // Regex universal untuk nominal rupiah & IDR
  // Cocok: "Rp50.000", "Rp 50.000,00", "Rp1.500.000", "IDR 50.000", "Rp 25.000,-"
  static final RegExp _universalAmountPattern = RegExp(
    r'(?:[Rr][Pp]\.?|IDR)\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?|\d+)',
  );

  // Regex universal untuk mengekstrak nama pembayar / pengirim (Uang Masuk)
  static final RegExp _universalPayerPattern = RegExp(
    r'(?:dari\s+pengirim|dikirim\s+oleh|dari|pengirim|oleh)\s+([A-Za-z0-9\s\.\&]+?)(?=\s+(?:ke|telah|sebesar|pada|sudah|rek|rekening)|[.,;\n]|$)',
    caseSensitive: false,
  );

  // Regex khusus BCA yang mendukung format "ke Toko Berkah" (merchant)
  static final RegExp _bcaPayerPattern = RegExp(
    r'(?:dari\s+pengirim|dikirim\s+oleh|dari|pengirim|oleh|ke)\s+([A-Za-z0-9\s\.\&]+?)(?=\s+(?:telah|sebesar|pada|sudah|rek|rekening)|[.,;\n]|$)',
    caseSensitive: false,
  );

  // Regex khusus DANA Bisnis — tangkap nama pembeli/pengirim dari notifikasi merchant QRIS
  // Format: "Pembayaran diterima Rp xxx dari BUDI SANTOSO"
  //         "Pelanggan ANDI membayar Rp xxx"
  //         "DANA Bisnis: Rp xxx dari SITI RAHMAWATI"
  //         "Ada yang bayar - KURNIAWAN"
  static final RegExp _danaBisnisPayerPattern = RegExp(
    r'(?:dari\s+pengirim|dikirim\s+oleh|pelanggan\s+|pembeli\s+|dari\s+|dari)([A-Z][A-Za-z0-9\s\.&]+?)(?=\s+(?:ke|telah|sebesar|pada|sudah|rek|rekening|membayar)|[.,;\n]|$)',
    caseSensitive: false,
  );

  // ── FILTER PROMO, SPAM, KEAMANAN & NON-FINANSIAL ────────────
  static final List<RegExp> _promoAndSpamPatterns = [
    // Promosi, diskon, kupon, voucher, flash sale
    RegExp(r'\b(?:promo|promosi|diskon|discount|voucher|kupon|flash\s*sale)\b', caseSensitive: false),
    RegExp(r'\b(?:dapatkan|klaim|nikmati|hemat|serbu|menangkan|menang\s+undian)\b', caseSensitive: false),
    RegExp(r'\b(?:cashback\s+(?:hingga|s/?d|s\.d\.|menantimu|spesial|\d+%|\d+))\b', caseSensitive: false),
    RegExp(r'\b(?:koin\s+shopee|koin\s+gratis|gratis\s+ongkir|spesial\s+(?:untukmu|hari\s+ini))\b', caseSensitive: false),
    RegExp(r'\b(?:ajak\s+teman|spin\s*(?:&|dan)\s*win|hadiah\s+menarik|bonus\s+poin)\b', caseSensitive: false),
    RegExp(r'\b(?:penawaran\s+terbatas|ekstra\s+diskon)\b', caseSensitive: false),
    // Keamanan, OTP, PIN, Akun
    RegExp(r'\b(?:kode\s+otp|otp|kode\s+verifikasi|kode\s+rahasia|verification\s+code)\b', caseSensitive: false),
    RegExp(r'\b(?:jangan\s+(?:beritahu|berikan|bagikan)|rahasia|pin\s+anda|ganti\s+pin)\b', caseSensitive: false),
    RegExp(r'\b(?:login\s+baru|perangkat\s+baru|akses\s+mencurigakan|security\s+alert)\b', caseSensitive: false),
    // Chat sosial / interaksi
    RegExp(r'\b(?:mengirim\s+pesan|mengirimkan\s+stiker|mengomentari|menandai\s+anda)\b', caseSensitive: false),
    // Sistem & Pemeliharaan
    RegExp(r'\b(?:pembaruan\s+aplikasi|update\s+aplikasi|maintenance|pemeliharaan\s+sistem)\b', caseSensitive: false),
  ];

  // Package aplikasi sosial / chat yang langsung diblacklist
  static final Set<String> _blacklistedPackages = {
    'com.whatsapp',
    'com.whatsapp.w4b',
    'org.telegram.messenger',
    'com.instagram.android',
    'com.facebook.katana',
    'com.facebook.orca',
    'com.zhiliaoapp.musically',
    'com.twitter.android',
    'com.google.android.youtube',
    'com.tiktok.android',
  };

  // ── POLA TRANSAKSI KELUAR (OUTGOING) ────────────────────────
  static final List<RegExp> _outgoingPatterns = [
    // Tarik tunai & penarikan
    RegExp(r'\b(?:tarik\s+tunai|tarik\s+saldo|tarik\s+uang|menarik\s+uang|menarik\s+saldo|penarikan\s+(?:dana|saldo|uang)|cash\s*out)\b', caseSensitive: false),
    // Transfer keluar & kirim uang
    RegExp(r'\b(?:transfer\s+keluar|uang\s+keluar|dana\s+keluar)\b', caseSensitive: false),
    RegExp(r'\b(?:berhasil\s+|telah\s+|sudah\s+)?(?:transfer|kirim|mengirim)\s+(?:uang|saldo|dana)?\s*(?:sebesar\s+[^k]+)?\s*ke\b', caseSensitive: false),
    RegExp(r'\bkamu\s+(?:berhasil\s+|telah\s+|sudah\s+)?(?:transfer|kirim|mengirim)\b', caseSensitive: false),
    RegExp(r'\btransfer\s+ke\s+[a-z0-9]', caseSensitive: false),
    // Pembayaran merchant / debit / belanja
    RegExp(r'\bkamu\s+(?:berhasil\s+|telah\s+|sudah\s+)?(?:membayar|bayar)\b', caseSensitive: false),
    RegExp(r'\b(?:telah|berhasil|sukses)\s+membayar\b', caseSensitive: false),
    RegExp(r'\bpembayaran\s+di\s+[a-z0-9]', caseSensitive: false),
    RegExp(r'\bpembayaran\s+(?:tagihan|pulsa|paket|token)\b', caseSensitive: false),
    RegExp(r'\bpembelian\s+(?:pulsa|paket|token)\b', caseSensitive: false),
    RegExp(r'\btagihan\s+(?:berhasil\s+)?(?:di)?bayar\b', caseSensitive: false),
    RegExp(r'\b(?:debit\s+rekening|transaksi\s+debit)\b', caseSensitive: false),
    RegExp(r'\bmoney\s+out\b', caseSensitive: false),
  ];

  // Daftar konfigurasi parser per package Android
  static final Map<String, _AppParser> _parsers = _initParsers();

  static Map<String, _AppParser> _initParsers() {
    final parsers = <String, _AppParser>{};

    // ── GOPAY & GOJEK ─────────────────────────────────────────
    final gopayParser = _AppParser(
      name: 'GoPay',
      baseCode: 'gopay',
      keywords: [
        'qris',
        'gopay',
        'pembayaran qr',
        'bayar qr',
        'scan qr',
        'pembayaran',
        'berhasil diterima',
        'kamu menerima',
        'transfer masuk',
        'uang masuk',
        'saldo masuk',
        'transfer ke',
        'tarik tunai',
        'uang keluar',
        'kirim uang',
        'berhasil transfer',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );
    parsers['com.gojek.gopay'] = gopayParser;
    parsers['com.gojek.app'] = gopayParser;

    // ── DANA (Personal) ───────────────────────────────────────
    // Notifikasi DANA personal: "Kamu menerima Saldo DANA", "QRIS berhasil!"
    parsers['id.dana'] = _AppParser(
      name: 'DANA',
      baseCode: 'dana',
      keywords: [
        'qris',
        'saldo dana',
        'kamu menerima',
        'diterima',
        'berhasil',
        'transfer',
        'uang masuk',
        'kiriman uang',
        'isi saldo',
        'transaksi qr',
        'qr code',
        'pembayaran',
        'saldo masuk',
        'tarik tunai',
        'menarik uang',
        'tarik saldo',
        'penarikan dana',
        'uang keluar',
        'transfer ke',
        'berhasil transfer',
        'kirim uang',
        // DANA Bisnis keywords (pakai package yang sama id.dana)
        'dana bisnis',
        'dana for business',
        'pembayaran diterima',
        'transaksi berhasil diterima',
        'merchant',
        'toko kamu',
        'ada yang bayar',
        'pelanggan membayar',
        'pembeli membayar',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _danaBisnisPayerPattern, // lebih pintar: tangkap nama pembeli juga
    );

    // ── OVO ───────────────────────────────────────────────────
    parsers['ovo.id'] = _AppParser(
      name: 'OVO',
      baseCode: 'ovo',
      keywords: [
        'qris',
        'ovo pay',
        'pembayaran',
        'scan & pay',
        'berhasil',
        'diterima',
        'transfer',
        'uang masuk',
        'kamu menerima',
        'top up',
        'saldo masuk',
        'tarik tunai',
        'uang keluar',
        'transfer ke',
        'berhasil transfer',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );

    // ── SHOPEEPAY & SHOPEE ────────────────────────────────────
    final shopeePayParser = _AppParser(
      name: 'ShopeePay',
      baseCode: 'shopeepay',
      keywords: [
        'qris',
        'shopeepay',
        'pembayaran',
        'scan qr',
        'berhasil',
        'diterima',
        'transfer masuk',
        'uang masuk',
        'kamu menerima',
        'saldo masuk',
        'ke tokomu',
        'tarik dana',
        'penarikan dana',
        'tarik tunai',
        'transfer ke',
        'uang keluar',
        'berhasil transfer',
        'telah membayar',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );
    parsers['com.shopeepay.id'] = shopeePayParser;
    parsers['com.shopee.id'] = shopeePayParser;

    // ── SEABANK ───────────────────────────────────────────────
    final seabankParser = _AppParser(
      name: 'SeaBank',
      baseCode: 'seabank',
      keywords: [
        'seabank',
        'transfer masuk',
        'uang masuk',
        'dana masuk',
        'kamu menerima',
        'menerima transfer',
        'qris',
        'transaksi qr',
        'pembayaran qr',
        'berhasil diterima',
        'sukses diterima',
        'masuk ke rekening',
        'saldo bertambah',
        'berhasil',
        'transfer ke',
        'penarikan dana',
        'tarik tunai',
        'uang keluar',
        'berhasil transfer',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );
    parsers['com.seabank.seabank'] = seabankParser;
    parsers['com.bancodesul.seabank'] = seabankParser;
    parsers['com.seabank.id'] = seabankParser;

    // ── BANK JAGO ─────────────────────────────────────────────
    parsers['com.jago.digitalBanking'] = _AppParser(
      name: 'Jago',
      baseCode: 'jago',
      keywords: [
        'jago',
        'qris',
        'pembayaran',
        'transfer masuk',
        'uang masuk',
        'kamu menerima',
        'berhasil',
        'diterima',
        'kantong',
        'dana masuk',
        'sudah masuk',
        'ada uang masuk',
        'transfer ke',
        'tarik tunai',
        'uang keluar',
        'berhasil transfer',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );

    // ── BCA MOBILE & myBCA ────────────────────────────────────
    parsers['com.bca'] = _AppParser(
      name: 'BCA Mobile',
      baseCode: 'bca',
      keywords: [
        'm-transfer',
        'qris',
        'pembayaran qr',
        'transaksi qr',
        'm-bca',
        'berhasil',
        'telah masuk',
        'transfer masuk',
        'uang masuk',
        'transfer ke',
        'berhasil transfer',
        'tarik tunai',
        'uang keluar',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _bcaPayerPattern,
    );
    parsers['id.co.bca.mybca'] = _AppParser(
      name: 'myBCA',
      baseCode: 'bca',
      keywords: [
        'qris',
        'transaksi qr',
        'pembayaran qr',
        'berhasil',
        'transfer masuk',
        'uang masuk',
        'telah masuk',
        'transfer ke',
        'berhasil transfer',
        'tarik tunai',
        'uang keluar',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );

    // ── LIVIN BY MANDIRI ──────────────────────────────────────
    final mandiriParser = _AppParser(
      name: 'Livin Mandiri',
      baseCode: 'mandiri',
      keywords: [
        'livin',
        'transfer masuk',
        'dana masuk',
        'uang masuk',
        'qris',
        'pembayaran qr',
        'transaksi qr',
        'berhasil',
        'masuk ke rekening',
        'telah masuk',
        'tagihan',
        'pembayaran tagihan',
        'transfer ke',
        'tarik tunai',
        'uang keluar',
        'berhasil transfer',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );
    parsers['id.co.mandiri.livin'] = mandiriParser;
    parsers['com.bankmandiri.mandiriglobal'] = mandiriParser;

    // ── BRIMO (BRI) ───────────────────────────────────────────
    parsers['id.co.bri.brimo'] = _AppParser(
      name: 'BRImo',
      baseCode: 'bri',
      keywords: [
        'brimo',
        'transfer masuk',
        'uang masuk',
        'dana masuk',
        'qris',
        'transaksi qr',
        'pembayaran',
        'sukses',
        'berhasil',
        'masuk ke rek',
        'tarik tunai',
        'transfer ke',
        'uang keluar',
        'berhasil transfer',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );

    // ── WONDR BY BNI & BNI MOBILE ─────────────────────────────
    final bniParser = _AppParser(
      name: 'wondr by BNI',
      baseCode: 'bni',
      keywords: [
        'wondr',
        'bni',
        'transfer masuk',
        'uang masuk',
        'dana masuk',
        'qris',
        'transaksi qr',
        'berhasil',
        'sukses',
        'kamu menerima',
        'transfer ke',
        'tarik tunai',
        'uang keluar',
        'berhasil transfer',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );
    parsers['id.co.bni.mobilebanking'] = bniParser;
    parsers['src.mobi.bni'] = _AppParser(
      name: 'BNI Mobile',
      baseCode: 'bni',
      keywords: [
        'bni',
        'transfer masuk',
        'uang masuk',
        'dana masuk',
        'qris',
        'transaksi qr',
        'berhasil',
        'sukses',
        'transfer ke',
        'tarik tunai',
        'uang keluar',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );
    parsers['id.bni.wondr'] = bniParser;

    // ── BANK NEO COMMERCE (NEOBANK) ───────────────────────────
    final neoParser = _AppParser(
      name: 'Neobank',
      baseCode: 'neobank',
      keywords: [
        'neobank',
        'neo',
        'transfer masuk',
        'uang masuk',
        'kamu menerima',
        'qris',
        'berhasil',
        'sukses',
        'transfer ke',
        'tarik tunai',
        'uang keluar',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );
    parsers['com.bnc.finance'] = neoParser;
    parsers['com.bankneocommerce.bunc'] = neoParser;

    // ── JENIUS (BTPN / SMBC) ──────────────────────────────────
    parsers['com.btpn.dc'] = _AppParser(
      name: 'Jenius',
      baseCode: 'jenius',
      keywords: [
        'jenius',
        'money in',
        'money out',
        'transfer masuk',
        'uang masuk',
        'kamu menerima',
        'qris',
        'saldo aktif',
        'telah masuk',
        'berhasil',
        'transfer ke',
        'tarik tunai',
        'uang keluar',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );

    // ── PERMATA ME ────────────────────────────────────────────
    final permataParser = _AppParser(
      name: 'Permata ME',
      baseCode: 'permata',
      keywords: [
        'permata',
        'transfer masuk',
        'uang masuk',
        'dana masuk',
        'qris',
        'berhasil',
        'transfer ke',
        'tarik tunai',
        'uang keluar',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );
    parsers['com.permatabank.mobile'] = permataParser;
    parsers['net.myinfosys.permata'] = permataParser;

    // ── OCTO MOBILE (CIMB NIAGA) ──────────────────────────────
    parsers['id.co.cimbniaga.mobile.android'] = _AppParser(
      name: 'OCTO Mobile',
      baseCode: 'octo',
      keywords: [
        'octo',
        'cimb',
        'transfer masuk',
        'uang masuk',
        'qris',
        'telah masuk',
        'berhasil',
        'transfer ke',
        'tarik tunai',
        'uang keluar',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );

    // ── LINKAJA ───────────────────────────────────────────────
    parsers['com.telkom.mwallet'] = _AppParser(
      name: 'LinkAja',
      baseCode: 'linkaja',
      keywords: [
        'linkaja',
        'kamu menerima',
        'uang masuk',
        'saldo masuk',
        'qris',
        'pembayaran',
        'berhasil',
        'transfer ke',
        'tarik tunai',
        'uang keluar',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );

    // ── SIMULATOR INTERNAL DOMPETKU ───────────────────────────
    parsers['com.dompetku.simulator'] = _AppParser(
      name: 'Simulator',
      baseCode: 'simulator',
      keywords: [
        'qris',
        'pembayaran',
        'qr',
        'transfer',
        'sukses',
        'berhasil',
        'uang masuk',
        'uang keluar',
        'tarik tunai',
        'tarik saldo',
      ],
      amountPattern: _universalAmountPattern,
      payerPattern: _universalPayerPattern,
    );

    return parsers;
  }

  // ── FUNGSI UTAMA ────────────────────────────────────────────
  /// Analisis notifikasi dan kembalikan TransactionModel.
  /// Kembalikan null jika terdeteksi promosi, voucher, diskon, OTP, atau bukan finansial.
  static TransactionModel? parse({
    required String title,
    required String body,
    required String package,
  }) {
    final fullText = '$title $body'.toLowerCase();

    // LANGKAH 0: Cek apakah ini promosi / spam / OTP / chat non-finansial
    if (_isPromoOrSpam(fullText, package)) {
      return null;
    }

    // LANGKAH 0.5: Tolak semua pengeluaran / transaksi keluar (DompetKu murni mencatat uang masuk / QRIS)
    if (_isOutgoingTransaction(fullText)) {
      return null;
    }

    // LANGKAH 1: Cari parser spesifik berdasarkan package Android
    final parser = _parsers[package];

    if (parser != null) {
      // Cek apakah ada kata kunci yang relevan
      final hasKeyword =
          parser.keywords.any((keyword) => fullText.contains(keyword));
      if (!hasKeyword) {
        return null;
      }

      // Ekstrak nominal uang dari body atau title
      final amount = _extractAmount(body, parser.amountPattern) ??
          _extractAmount(title, parser.amountPattern);
      if (amount == null || amount <= 0) {
        return null;
      }

      // ── Deteksi DANA Bisnis secara otomatis ──────────────
      // Jika package id.dana DAN title/body mengandung kata kunci bisnis,
      // tampilkan sebagai "DANA Bisnis" dengan baseCode 'dana_bisnis'
      final bool isDanaBisnis = package == 'id.dana' &&
          (fullText.contains('dana bisnis') ||
              fullText.contains('dana for business') ||
              fullText.contains('pembayaran diterima') ||
              fullText.contains('merchant') ||
              fullText.contains('toko kamu') ||
              fullText.contains('ada yang bayar') ||
              fullText.contains('pelanggan membayar') ||
              fullText.contains('pembeli membayar') ||
              title.toLowerCase().contains('dana bisnis') ||
              title.toLowerCase().contains('dana for business'));

      final String resolvedName = isDanaBisnis ? 'DANA Bisnis' : parser.name;
      final String resolvedBaseCode = isDanaBisnis ? 'dana_bisnis' : parser.baseCode;
      final RegExp resolvedPayerPattern = isDanaBisnis
          ? _danaBisnisPayerPattern
          : (parser.payerPattern ?? _universalPayerPattern);

      // Ekstrak nama pembayar / pengirim (Uang Masuk)
      String partyName = 'Pelanggan';

      final fromBody = _extractPayer(body, resolvedPayerPattern);
      if (fromBody != 'Pelanggan') {
        partyName = fromBody;
      } else {
        final fromTitle = _extractPayer(title, resolvedPayerPattern);
        if (fromTitle != 'Pelanggan') {
          partyName = fromTitle;
        }
      }

      final typeCode = '${resolvedBaseCode}_in';

      return TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        type: typeCode,
        appSource: resolvedName,
        payerName: partyName,
        dateTime: DateTime.now(),
        rawMessage: '$title\n$body',
        appPackage: package,
      );
    }

    // ── LANGKAH 2: Fallback Pintar (Generic In Detector) ──────
    // Untuk bank atau fintech baru yang belum terdaftar di daftar spesifik
    final generalKeywords = [
      'qris',
      'transaksi qr',
      'pembayaran qr',
      'scan qr',
      'qr code',
      'uang masuk',
      'saldo masuk',
      'saldo dana',
      'berhasil diterima',
      'transfer masuk',
      'dana masuk',
      'kamu menerima',
      'telah masuk ke rekening',
      'masuk ke rekening',
      'saldo bertambah',
      'ada uang masuk',
      'kiriman uang',
    ];

    final isGeneralFinancial =
        generalKeywords.any((keyword) => fullText.contains(keyword));

    if (!isGeneralFinancial) {
      return null;
    }

    final amount = _extractAmount(body, _universalAmountPattern) ??
        _extractAmount(title, _universalAmountPattern);

    if (amount == null || amount <= 0) {
      return null;
    }

    final sourceName = title.isNotEmpty ? title : 'Pembayaran';
    final fallbackBase = _formatBaseCode(sourceName);
    final fallbackType = '${fallbackBase}_in';

    final partyName = _extractPayer(body, _universalPayerPattern) != 'Pelanggan'
        ? _extractPayer(body, _universalPayerPattern)
        : _extractPayer(title, _universalPayerPattern);

    return TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      type: fallbackType,
      appSource: sourceName,
      payerName: partyName,
      dateTime: DateTime.now(),
      rawMessage: '$title\n$body',
      appPackage: package,
    );
  }

  // ── DETEKSI PROMOSI & SPAM NON-FINANSIAL ─────────────────────
  static bool _isPromoOrSpam(String fullText, String package) {
    if (_blacklistedPackages.contains(package)) {
      return true;
    }

    for (final pattern in _promoAndSpamPatterns) {
      if (pattern.hasMatch(fullText)) {
        return true;
      }
    }

    return false;
  }

  // ── DETEKSI TRANSAKSI UANG KELUAR (OUTGOING) ─────────────────
  static bool _isOutgoingTransaction(String fullText) {
    // Kata kunci penegas bahwa dana adalah transaksi masuk (QRIS merchant/transfer masuk)
    final explicitIncoming = [
      'transfer masuk',
      'uang masuk',
      'dana masuk',
      'saldo masuk',
      'kamu menerima',
      'menerima transfer',
      'menerima saldo',
      'berhasil diterima',
      'sukses diterima',
      'masuk ke rekening',
      'telah masuk ke',
      'telah masuk',
      'sudah masuk',
      'berhasil ditambahkan',
      'ke tokomu',
      'money in',
      'isi saldo',
      'top up',
      'ada uang masuk',
      'saldo bertambah',
      'kiriman uang',
    ];

    // Jika mengandung penegas uang masuk dan tidak mengandung verba penarikan tunai
    final isClearIncoming = explicitIncoming.any((kw) => fullText.contains(kw));
    final hasWithdrawal = fullText.contains('tarik tunai') ||
        fullText.contains('menarik uang') ||
        fullText.contains('menarik saldo') ||
        fullText.contains('tarik saldo') ||
        fullText.contains('penarikan dana');

    if (isClearIncoming && !hasWithdrawal) {
      return false;
    }

    for (final pattern in _outgoingPatterns) {
      if (pattern.hasMatch(fullText)) {
        return true;
      }
    }

    return false;
  }

  // ── HELPER: Ekstrak Angka Nominal ────────────────────────────
  static double? _extractAmount(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    if (match == null) return null;

    final raw = match.group(1);
    if (raw == null) return null;

    var clean = raw.trim();
    if (clean.endsWith(',-') || clean.endsWith('.-')) {
      clean = clean.substring(0, clean.length - 2);
    }

    if (clean.contains('.') && clean.contains(',')) {
      final dotIndex = clean.lastIndexOf('.');
      final commaIndex = clean.lastIndexOf(',');
      if (dotIndex < commaIndex) {
        // Format Indonesia/Eropa: 50.000,00 -> 50000.00
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Format Anglo/US: 50,000.00 -> 50000.00
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains('.')) {
      final parts = clean.split('.');
      if (parts.length > 1 && parts.last.length == 3) {
        // 50.000 atau 1.500.000 (ribuan)
        clean = clean.replaceAll('.', '');
      } else if (parts.length == 2 && parts.last.length <= 2) {
        // 50000.00 (desimal)
      } else {
        clean = clean.replaceAll('.', '');
      }
    } else if (clean.contains(',')) {
      final parts = clean.split(',');
      if (parts.length > 1 && parts.last.length == 3) {
        clean = clean.replaceAll(',', '');
      } else if (parts.length == 2 && parts.last.length <= 2) {
        clean = clean.replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    }

    return double.tryParse(clean);
  }

  // ── HELPER: Ekstrak Nama Pembayar / Pengirim (Uang Masuk) ─────
  static String _extractPayer(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    if (match == null) return 'Pelanggan';

    var name = match.group(1)?.trim() ?? 'Pelanggan';
    name = name.replaceAll(RegExp(r'[\.\,\:\;\-]+$'), '').trim();

    final lower = name.toLowerCase();
    if (lower.isEmpty ||
        lower == 'pelanggan' ||
        lower == 'pengirim' ||
        lower == 'rekening' ||
        lower == 'kantong' ||
        lower == 'saldo' ||
        RegExp(r'^\d+$').hasMatch(name)) {
      return 'Pelanggan';
    }

    return name.length > 22 ? '${name.substring(0, 19)}...' : name;
  }

  // ── HELPER: Format Nama Bank Menjadi Base Code Dinamis ────────
  // Contoh: "Bank Aladin" -> "bank_aladin"
  static String _formatBaseCode(String name) {
    final clean = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return clean.isNotEmpty ? clean : 'transfer';
  }
}
