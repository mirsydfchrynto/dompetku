// ============================================================
// FILE: qris_parser_test.dart
//
// TUJUAN: Unit test komprehensif untuk memverifikasi akurasi
//         deteksi seluruh notifikasi uang masuk dan QRIS:
//         ShopeePay, SeaBank, DANA, Bank Jago, OVO, BCA,
//         Mandiri, BRI, BNI, Neobank, Jenius, Permata,
//         CIMB Niaga, LinkAja, serta filter uang keluar dan OTP.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dompetku/services/qris_parser.dart';

void main() {
  group('QrisParser All Banks & E-Wallets', () {
    // ── 1. GOPAY & GOJEK ─────────────────────────────────────
    group('GoPay', () {
      test('parse notifikasi QRIS Rp50.000 dari GoPay', () {
        final result = QrisParser.parse(
          title: 'GoPay',
          body: 'Pembayaran QRIS Rp50.000 berhasil diterima dari Budi S.',
          package: 'com.gojek.gopay',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('GoPay'));
        expect(result.type, equals('gopay_in'));
        expect(result.payerName, contains('Budi'));
      });

      test('parse notifikasi dari com.gojek.app', () {
        final result = QrisParser.parse(
          title: 'GoPay',
          body: 'Pembayaran QRIS Rp25.000 berhasil diterima dari Siti',
          package: 'com.gojek.app',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(25000.0));
        expect(result.appSource, equals('GoPay'));
        expect(result.type, equals('gopay_in'));
        expect(result.payerName, contains('Siti'));
      });

      test('ignore notifikasi GoPay promo', () {
        final result = QrisParser.parse(
          title: 'GoPay',
          body: 'Promo cashback 20% untuk semua transaksi!',
          package: 'com.gojek.gopay',
        );

        expect(result, isNull);
      });
    });

    // ── 2. DANA ──────────────────────────────────────────────
    group('DANA', () {
      test('parse notifikasi QRIS Rp85.000 dari DANA', () {
        final result = QrisParser.parse(
          title: 'DANA',
          body: 'Pembayaran QRIS Rp85.000,00 sukses diterima.',
          package: 'id.dana',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(85000.0));
        expect(result.appSource, equals('DANA'));
        expect(result.type, equals('dana_in'));
        expect(result.payerName, equals('Pelanggan'));
      });

      test('parse notifikasi transfer Saldo DANA dengan nama pengirim', () {
        final result = QrisParser.parse(
          title: 'DANA',
          body: 'Kamu menerima Saldo DANA sebesar Rp 50.000 dari BUDI SANTOSO.',
          package: 'id.dana',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('DANA'));
        expect(result.type, equals('dana_in'));
        expect(result.payerName, contains('BUDI SANTOSO'));
      });

      test('parse notifikasi DANA saat nominal ada di judul', () {
        final result = QrisParser.parse(
          title: 'Saldo DANA Rp20.000 Berhasil Masuk',
          body: 'Uang masuk dari pengirim Andi.',
          package: 'id.dana',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(20000.0));
        expect(result.appSource, equals('DANA'));
        expect(result.type, equals('dana_in'));
        expect(result.payerName, contains('Andi'));
      });

      test('parse DANA dengan nominal besar Rp1.500.000', () {
        final result = QrisParser.parse(
          title: 'DANA',
          body: 'Transaksi QRIS Rp1.500.000,00 berhasil.',
          package: 'id.dana',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(1500000.0));
        expect(result.type, equals('dana_in'));
      });

      test('parse notifikasi transfer keluar DANA', () {
        final result = QrisParser.parse(
          title: 'DANA',
          body: 'Kamu berhasil transfer uang ke Budi sebesar Rp 50.000',
          package: 'id.dana',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('DANA'));
        expect(result.type, equals('dana_out'));
        expect(result.isIncoming, isFalse);
        expect(result.isOutgoing, isTrue);
        expect(result.payerName, equals('Budi'));
      });

      test('parse notifikasi tarik tunai DANA di Alfamart', () {
        final result = QrisParser.parse(
          title: 'DANA',
          body: 'Kamu berhasil menarik uang sebesar Rp 50.000 di Alfamart',
          package: 'id.dana',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('DANA'));
        expect(result.type, equals('dana_out'));
        expect(result.isIncoming, isFalse);
        expect(result.payerName, contains('Tarik Tunai'));
      });
    });

    // ── 3. OVO ───────────────────────────────────────────────
    group('OVO', () {
      test('parse notifikasi OVO QRIS', () {
        final result = QrisParser.parse(
          title: 'OVO',
          body: 'OVO QRIS Rp60.000 berhasil diterima.',
          package: 'ovo.id',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(60000.0));
        expect(result.appSource, equals('OVO'));
        expect(result.type, equals('ovo_in'));
      });

      test('parse notifikasi OVO transfer masuk dengan pengirim', () {
        final result = QrisParser.parse(
          title: 'OVO',
          body: 'Kamu menerima transfer sebesar Rp50.000 dari BUDI',
          package: 'ovo.id',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('OVO'));
        expect(result.type, equals('ovo_in'));
        expect(result.payerName, contains('BUDI'));
      });

      test('parse top up OVO masuk', () {
        final result = QrisParser.parse(
          title: 'OVO',
          body: 'Top up sebesar Rp 100.000 berhasil masuk',
          package: 'ovo.id',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(100000.0));
        expect(result.appSource, equals('OVO'));
        expect(result.type, equals('ovo_in'));
      });
    });

    // ── 4. SHOPEEPAY & SHOPEE ────────────────────────────────
    group('ShopeePay', () {
      test('parse notifikasi ShopeePay QRIS', () {
        final result = QrisParser.parse(
          title: 'ShopeePay',
          body: 'ShopeePay: Pembayaran QRIS Rp33.000 diterima.',
          package: 'com.shopeepay.id',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(33000.0));
        expect(result.appSource, equals('ShopeePay'));
        expect(result.type, equals('shopeepay_in'));
      });

      test('parse transfer masuk ShopeePay dengan nama pengirim', () {
        final result = QrisParser.parse(
          title: 'ShopeePay',
          body: 'Kamu menerima transfer saldo ShopeePay sebesar Rp 25.000 dari SITI',
          package: 'com.shopeepay.id',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(25000.0));
        expect(result.appSource, equals('ShopeePay'));
        expect(result.type, equals('shopeepay_in'));
        expect(result.payerName, equals('SITI'));
      });

      test('parse transfer masuk dari package Shopee utama (com.shopee.id)', () {
        final result = QrisParser.parse(
          title: 'ShopeePay',
          body: 'Transfer masuk sebesar Rp50.000 dari BUDI SANTOSO',
          package: 'com.shopee.id',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('ShopeePay'));
        expect(result.type, equals('shopeepay_in'));
        expect(result.payerName, contains('BUDI SANTOSO'));
      });

      test('parse transfer keluar ShopeePay', () {
        final result = QrisParser.parse(
          title: 'ShopeePay',
          body: 'Kamu berhasil transfer saldo sebesar Rp 25.000 ke Budi',
          package: 'com.shopeepay.id',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(25000.0));
        expect(result.appSource, equals('ShopeePay'));
        expect(result.type, equals('shopeepay_out'));
        expect(result.isIncoming, isFalse);
        expect(result.payerName, equals('Budi'));
      });
    });

    // ── 5. SEABANK ───────────────────────────────────────────
    group('SeaBank', () {
      test('parse notifikasi transfer masuk SeaBank dengan nama pengirim', () {
        final result = QrisParser.parse(
          title: 'SeaBank',
          body: 'Kamu menerima transfer masuk sebesar Rp 100.000 dari SITI RAHMAWATI',
          package: 'com.seabank.seabank',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(100000.0));
        expect(result.appSource, equals('SeaBank'));
        expect(result.type, equals('seabank_in'));
        expect(result.payerName, equals('SITI RAHMAWATI'));
      });

      test('parse notifikasi transfer sebesar dari SeaBank', () {
        final result = QrisParser.parse(
          title: 'SeaBank',
          body: 'Kamu menerima transfer sebesar Rp50.000 dari BUDI',
          package: 'com.seabank.seabank',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('SeaBank'));
        expect(result.type, equals('seabank_in'));
        expect(result.payerName, equals('BUDI'));
      });

      test('parse notifikasi transaksi QRIS SeaBank', () {
        final result = QrisParser.parse(
          title: 'SeaBank',
          body: 'Transaksi QRIS sebesar Rp 75.000 berhasil diterima.',
          package: 'com.seabank.seabank',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(75000.0));
        expect(result.appSource, equals('SeaBank'));
        expect(result.type, equals('seabank_in'));
      });

      test('parse notifikasi SeaBank alias package (com.bancodesul.seabank)', () {
        final result = QrisParser.parse(
          title: 'SeaBank',
          body: 'Transfer masuk sebesar Rp 250.000 dari AHMAD',
          package: 'com.bancodesul.seabank',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(250000.0));
        expect(result.appSource, equals('SeaBank'));
        expect(result.type, equals('seabank_in'));
        expect(result.payerName, equals('AHMAD'));
      });

      test('parse transfer keluar SeaBank', () {
        final result = QrisParser.parse(
          title: 'SeaBank',
          body: 'Kamu berhasil transfer ke rekening BCA sebesar Rp 100.000',
          package: 'com.seabank.seabank',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(100000.0));
        expect(result.appSource, equals('SeaBank'));
        expect(result.type, equals('seabank_out'));
        expect(result.isIncoming, isFalse);
        expect(result.payerName, equals('Rekening BCA'));
      });
    });

    // ── 6. BANK JAGO ─────────────────────────────────────────
    group('Bank Jago', () {
      test('parse notifikasi uang masuk ke Kantong dengan nama pengirim bersih', () {
        final result = QrisParser.parse(
          title: 'Bank Jago',
          body: 'Kamu menerima Rp50.000 dari AHMAD ke Kantong Utama',
          package: 'com.jago.digitalBanking',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('Jago'));
        expect(result.type, equals('jago_in'));
        expect(result.payerName, equals('AHMAD')); // Harus terpotong bersih tanpa 'ke Kantong Utama'
      });

      test('parse notifikasi ada uang masuk Jago', () {
        final result = QrisParser.parse(
          title: 'Bank Jago',
          body: 'Ada uang masuk sebesar Rp 250.000 dari BUDI SANTOSO',
          package: 'com.jago.digitalBanking',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(250000.0));
        expect(result.appSource, equals('Jago'));
        expect(result.type, equals('jago_in'));
        expect(result.payerName, equals('BUDI SANTOSO'));
      });

      test('parse QRIS Jago', () {
        final result = QrisParser.parse(
          title: 'Bank Jago',
          body: 'QRIS Rp250.000 diterima dari Siti R.',
          package: 'com.jago.digitalBanking',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(250000.0));
        expect(result.appSource, equals('Jago'));
        expect(result.type, equals('jago_in'));
        expect(result.payerName, contains('Siti'));
      });

      test('parse transfer keluar Bank Jago', () {
        final result = QrisParser.parse(
          title: 'Bank Jago',
          body: 'Transfer ke BUDI sebesar Rp 50.000 berhasil',
          package: 'com.jago.digitalBanking',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('Jago'));
        expect(result.type, equals('jago_out'));
        expect(result.isIncoming, isFalse);
        expect(result.payerName, equals('BUDI'));
      });
    });

    // ── 7. BCA MOBILE & myBCA ────────────────────────────────
    group('BCA', () {
      test('parse notifikasi m-Transfer masuk dengan nama dan rekening delimiter', () {
        final result = QrisParser.parse(
          title: 'm-BCA',
          body: 'm-Transfer: Rp 500.000,00 dari BUDI SANTOSO telah masuk ke rek 1234567890',
          package: 'com.bca',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(500000.0));
        expect(result.appSource, equals('BCA Mobile'));
        expect(result.type, equals('bca_in'));
        expect(result.payerName, equals('BUDI SANTOSO'));
      });

      test('parse notifikasi QRIS BCA Mobile', () {
        final result = QrisParser.parse(
          title: 'm-BCA',
          body: 'Pembayaran QRIS Rp75.000 BERHASIL ke Toko Berkah',
          package: 'com.bca',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(75000.0));
        expect(result.appSource, equals('BCA Mobile'));
        expect(result.type, equals('bca_in'));
      });

      test('parse notifikasi myBCA QRIS', () {
        final result = QrisParser.parse(
          title: 'myBCA',
          body: 'Transaksi QRIS Rp120.000 berhasil dari Joko',
          package: 'id.co.bca.mybca',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(120000.0));
        expect(result.appSource, equals('myBCA'));
        expect(result.type, equals('bca_in'));
        expect(result.payerName, contains('Joko'));
      });

      test('parse notifikasi myBCA transfer masuk', () {
        final result = QrisParser.parse(
          title: 'myBCA',
          body: 'Transfer Masuk sebesar Rp 250.000 dari SITI RAHMAWATI',
          package: 'id.co.bca.mybca',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(250000.0));
        expect(result.appSource, equals('myBCA'));
        expect(result.type, equals('bca_in'));
        expect(result.payerName, equals('SITI RAHMAWATI'));
      });

      test('parse m-Transfer transfer keluar BCA', () {
        final result = QrisParser.parse(
          title: 'm-BCA',
          body: 'm-Transfer: Berhasil transfer ke Budi sebesar Rp 50.000',
          package: 'com.bca',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('BCA Mobile'));
        expect(result.type, equals('bca_out'));
        expect(result.isIncoming, isFalse);
        expect(result.payerName, equals('Budi'));
      });
    });

    // ── 8. LIVIN BY MANDIRI ──────────────────────────────────
    group('Livin Mandiri', () {
      test('parse notifikasi transfer masuk Livin dengan delimiter telah masuk', () {
        final result = QrisParser.parse(
          title: 'Livin',
          body: 'Transfer Masuk: Dana sebesar Rp 300.000,00 dari SITI RAHMAWATI telah masuk ke rekening Anda',
          package: 'id.co.mandiri.livin',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(300000.0));
        expect(result.appSource, equals('Livin Mandiri'));
        expect(result.type, equals('mandiri_in'));
        expect(result.payerName, equals('SITI RAHMAWATI'));
      });

      test('parse notifikasi QRIS Livin', () {
        final result = QrisParser.parse(
          title: 'Livin',
          body: 'Pembayaran QRIS Rp150.000 berhasil diterima dari Rudi',
          package: 'id.co.mandiri.livin',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(150000.0));
        expect(result.appSource, equals('Livin Mandiri'));
        expect(result.type, equals('mandiri_in'));
        expect(result.payerName, contains('Rudi'));
      });

      test('parse pembayaran tagihan di Livin', () {
        final result = QrisParser.parse(
          title: 'Livin',
          body: 'Pembayaran tagihan listrik Rp 150.000 berhasil',
          package: 'id.co.mandiri.livin',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(150000.0));
        expect(result.appSource, equals('Livin Mandiri'));
        expect(result.type, equals('mandiri_out'));
        expect(result.isIncoming, isFalse);
        expect(result.payerName, contains('Tagihan'));
      });
    });

    // ── 9. BRIMO (BRI) ───────────────────────────────────────
    group('BRImo', () {
      test('parse notifikasi transfer masuk BRImo dengan delimiter ke rek', () {
        final result = QrisParser.parse(
          title: 'BRImo',
          body: 'Transfer Masuk: Rp 150.000 dari BUDI ke rek 9876***',
          package: 'id.co.bri.brimo',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(150000.0));
        expect(result.appSource, equals('BRImo'));
        expect(result.type, equals('bri_in'));
        expect(result.payerName, equals('BUDI'));
      });

      test('parse notifikasi QRIS BRImo', () {
        final result = QrisParser.parse(
          title: 'BRImo',
          body: 'Transaksi QRIS Rp45.000 sukses diterima',
          package: 'id.co.bri.brimo',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(45000.0));
        expect(result.appSource, equals('BRImo'));
        expect(result.type, equals('bri_in'));
      });

      test('parse tarik tunai BRImo', () {
        final result = QrisParser.parse(
          title: 'BRImo',
          body: 'Tarik tunai Rp 100.000 berhasil di ATM BRI',
          package: 'id.co.bri.brimo',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(100000.0));
        expect(result.appSource, equals('BRImo'));
        expect(result.type, equals('bri_out'));
        expect(result.isIncoming, isFalse);
        expect(result.payerName, contains('Tarik Tunai'));
      });
    });

    // ── 10. WONDR BY BNI & BNI MOBILE ────────────────────────
    group('wondr by BNI', () {
      test('parse notifikasi transfer masuk wondr by BNI', () {
        final result = QrisParser.parse(
          title: 'wondr by BNI',
          body: 'Transfer Masuk: Rp 100.000 dari AHMAD ke rekening 1234***',
          package: 'id.co.bni.mobilebanking',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(100000.0));
        expect(result.appSource, equals('wondr by BNI'));
        expect(result.type, equals('bni_in'));
        expect(result.payerName, equals('AHMAD'));
      });

      test('parse notifikasi QRIS wondr by BNI', () {
        final result = QrisParser.parse(
          title: 'wondr by BNI',
          body: 'Transaksi QRIS Rp50.000 berhasil diterima',
          package: 'id.co.bni.mobilebanking',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('wondr by BNI'));
        expect(result.type, equals('bni_in'));
      });
    });

    // ── 11. NEOBANK, JENIUS, PERMATA, OCTO, LINKAJA ──────────
    group('Bank Digital Lainnya', () {
      test('parse transfer masuk Neobank', () {
        final result = QrisParser.parse(
          title: 'Neobank',
          body: 'Transfer Masuk: Kamu menerima uang sebesar Rp 100.000 dari BUDI',
          package: 'com.bnc.finance',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(100000.0));
        expect(result.appSource, equals('Neobank'));
        expect(result.type, equals('neobank_in'));
        expect(result.payerName, equals('BUDI'));
      });

      test('parse Jenius Money In', () {
        final result = QrisParser.parse(
          title: 'Jenius',
          body: 'Money In: Uang sebesar Rp 500.000 dari BUDI telah masuk ke Saldo Aktif',
          package: 'com.btpn.dc',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(500000.0));
        expect(result.appSource, equals('Jenius'));
        expect(result.type, equals('jenius_in'));
        expect(result.payerName, equals('BUDI'));
      });

      test('parse Permata ME transfer masuk', () {
        final result = QrisParser.parse(
          title: 'Permata ME',
          body: 'Transfer Masuk: Rp 100.000 dari BUDI',
          package: 'com.permatabank.mobile',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(100000.0));
        expect(result.appSource, equals('Permata ME'));
        expect(result.type, equals('permata_in'));
        expect(result.payerName, equals('BUDI'));
      });

      test('parse OCTO Mobile transfer masuk', () {
        final result = QrisParser.parse(
          title: 'OCTO Mobile',
          body: 'Transfer Masuk: Dana Rp 200.000 dari BUDI telah masuk',
          package: 'id.co.cimbniaga.mobile.android',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(200000.0));
        expect(result.appSource, equals('OCTO Mobile'));
        expect(result.type, equals('octo_in'));
        expect(result.payerName, equals('BUDI'));
      });

      test('parse LinkAja uang masuk', () {
        final result = QrisParser.parse(
          title: 'LinkAja',
          body: 'Kamu menerima saldo sebesar Rp 50.000 dari BUDI',
          package: 'com.telkom.mwallet',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(50000.0));
        expect(result.appSource, equals('LinkAja'));
        expect(result.type, equals('linkaja_in'));
        expect(result.payerName, equals('BUDI'));
      });
    });

    // ── 12. SIMULATOR INTERNAL & SMART FALLBACK ──────────────
    group('Simulator & Smart Fallback', () {
      test('parse notifikasi dari Simulator internal', () {
        final result = QrisParser.parse(
          title: 'Test App',
          body: 'Pembayaran QRIS Rp99.000 berhasil',
          package: 'com.dompetku.simulator',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(99000.0));
        expect(result.appSource, equals('Simulator'));
        expect(result.type, equals('simulator_in'));
      });

      test('fallback otomatis mendeteksi QRIS dari app baru', () {
        final result = QrisParser.parse(
          title: 'Bank Digital Baru',
          body: 'Transaksi QRIS Rp500.000 sukses dari pengirim Andi',
          package: 'com.bankdigital.baru',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(500000.0));
        expect(result.appSource, equals('Bank Digital Baru'));
        expect(result.type, equals('bank_digital_baru_in'));
        expect(result.payerName, contains('Andi'));
      });

      test('fallback otomatis mendeteksi transfer masuk dari app bank baru', () {
        final result = QrisParser.parse(
          title: 'Bank Aladin',
          body: 'Transfer masuk sebesar Rp 300.000 dari KURNIAWAN ke rekening anda',
          package: 'com.bankaladin.app',
        );

        expect(result, isNotNull);
        expect(result!.amount, equals(300000.0));
        expect(result.type, equals('bank_aladin_in'));
        expect(result.payerName, equals('KURNIAWAN'));
      });
    });

    // ── 13. FILTER KEAMANAN / OTP & NON-TRANSAKSI ─────────────
    group('Filter Keamanan & Non-Finansial', () {
      test('ignore notifikasi kode OTP / verifikasi', () {
        final result = QrisParser.parse(
          title: 'DANA',
          body: 'KODE OTP: 849201. JANGAN BERIKAN KODE INI KEPADA SIAPAPUN termasuk pihak DANA.',
          package: 'id.dana',
        );

        expect(result, isNull);
      });

      test('ignore notifikasi promo voucher diskon Shopee meski ada nominal Rp 50.000', () {
        final result = QrisParser.parse(
          title: 'Shopee',
          body: 'Dapatkan voucher diskon 50% hingga Rp 50.000 untuk belanja hari ini!',
          package: 'com.shopee.id',
        );

        expect(result, isNull);
      });

      test('ignore notifikasi promo cashback DANA Deals', () {
        final result = QrisParser.parse(
          title: 'DANA',
          body: 'Promo cashback 20% menantimu untuk semua transaksi DANA Deals!',
          package: 'id.dana',
        );

        expect(result, isNull);
      });

      test('ignore notifikasi klaim koin dan promo flash sale', () {
        final result = QrisParser.parse(
          title: 'ShopeePay',
          body: 'Klaim koin Shopee gratis dan nikmati promo flash sale!',
          package: 'com.shopeepay.id',
        );

        expect(result, isNull);
      });

      test('ignore notifikasi chat WhatsApp', () {
        final result = QrisParser.parse(
          title: 'WhatsApp',
          body: 'Budi: Halo apa kabar?',
          package: 'com.whatsapp',
        );

        expect(result, isNull);
      });

      test('ignore notifikasi dari app tidak dikenal tanpa kata kunci', () {
        final result = QrisParser.parse(
          title: 'Game Store',
          body: 'Promo game diskon 70% hanya hari ini!',
          package: 'com.game.store',
        );

        expect(result, isNull);
      });
    });
  });
}
