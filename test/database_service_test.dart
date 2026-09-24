import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dompetku/models/transaction_model.dart';
import 'package:dompetku/models/webhook_preset.dart';
import 'package:dompetku/services/database_service.dart';
import 'package:dompetku/services/webhook_service.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dompetku_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }
    await Hive.openBox<TransactionModel>('transactions');
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('P0 DEDUPLICATION CORRECTNESS (Phase D3)', () {
    test('A -> same payment notification repeated = duplicate', () async {
      final now = DateTime.now();
      
      final txA1 = TransactionModel(
        id: 'tx_A1', amount: 50000, type: 'gopay_in', appSource: 'GoPay', payerName: 'Budi Santoso', 
        dateTime: now, rawMessage: 'GoPay: Pembayaran diterima Rp 50.000 dari Budi Santoso', appPackage: 'com.gojek.gopay',
        dedupeFingerprint: 'md5_same_fingerprint',
      );
      await DatabaseService.saveTransaction(txA1);

      final txA2 = TransactionModel(
        id: 'tx_A2', amount: 50000, type: 'gopay_in', appSource: 'GoPay', payerName: 'Budi Santoso', 
        dateTime: now.add(const Duration(seconds: 5)), rawMessage: 'GoPay: Pembayaran diterima Rp 50.000 dari Budi Santoso', appPackage: 'com.gojek.gopay',
        dedupeFingerprint: 'md5_same_fingerprint',
      );
      
      expect(await DatabaseService.isDuplicateTransaction(txA2), isTrue);
    });

    test('A and B -> same amount, same source, same payer = NOT duplicate when separate transactions', () async {
      final now = DateTime.now();
      
      final txA = TransactionModel(
        id: 'tx_A', amount: 50000, type: 'gopay_in', appSource: 'GoPay', payerName: 'Budi Santoso', 
        dateTime: now, rawMessage: 'GoPay: Pembayaran diterima Rp 50.000 dari Budi Santoso', appPackage: 'com.gojek.gopay',
        dedupeFingerprint: 'md5_fingerprint_A_key1',
      );
      await DatabaseService.saveTransaction(txA);

      final txB = TransactionModel(
        id: 'tx_B', amount: 50000, type: 'gopay_in', appSource: 'GoPay', payerName: 'Budi Santoso', 
        dateTime: now.add(const Duration(minutes: 5)), rawMessage: 'GoPay: Pembayaran diterima Rp 50.000 dari Budi Santoso', appPackage: 'com.gojek.gopay',
        dedupeFingerprint: 'md5_fingerprint_B_key2', // Different key because it's a new Android notification
      );
      
      expect(await DatabaseService.isDuplicateTransaction(txB), isFalse);
    });
  });

  group('DatabaseService Deduplication Tests', () {
    test('detects duplicate transaction within 90s window with same payer and amount', () async {
      final now = DateTime.now();
      final tx1 = TransactionModel(
        id: 'tx_1',
        amount: 50000,
        type: 'gopay_in',
        appSource: 'GoPay',
        payerName: 'Budi Santoso',
        dateTime: now,
        rawMessage: 'GoPay: Pembayaran diterima Rp 50.000 dari Budi Santoso',
        appPackage: 'com.gojek.gopay',
      );
      await DatabaseService.saveTransaction(tx1);

      final txDuplicate = TransactionModel(
        id: 'tx_2',
        amount: 50000,
        type: 'gopay_in',
        appSource: 'GoPay',
        payerName: 'Budi Santoso',
        dateTime: now.add(const Duration(seconds: 15)),
        rawMessage: 'GoPay: Pembayaran diterima Rp 50.000 dari Budi Santoso',
        appPackage: 'com.gojek.gopay',
      );

      final isDup = await DatabaseService.isDuplicateTransaction(txDuplicate);
      expect(isDup, isTrue);
    });

    test('allows same amount but different payerName (different buyers)', () async {
      final now = DateTime.now();
      final tx1 = TransactionModel(
        id: 'tx_1',
        amount: 75000,
        type: 'bca_in',
        appSource: 'BCA Mobile',
        payerName: 'Ahmad Dahlan',
        dateTime: now,
        rawMessage: 'BCA: Transfer Rp 75.000 dari Ahmad Dahlan',
        appPackage: 'com.bca',
      );
      await DatabaseService.saveTransaction(tx1);

      final txDifferentBuyer = TransactionModel(
        id: 'tx_2',
        amount: 75000,
        type: 'bca_in',
        appSource: 'BCA Mobile',
        payerName: 'Citra Kirana',
        dateTime: now.add(const Duration(seconds: 10)),
        rawMessage: 'BCA: Transfer Rp 75.000 dari Citra Kirana',
        appPackage: 'com.bca',
      );

      final isDup = await DatabaseService.isDuplicateTransaction(txDifferentBuyer);
      expect(isDup, isFalse);
    });

    test('P0 HARDENING: allows transaction outside time window (> 1 hour)', () async {
      final oldTime = DateTime.now().subtract(const Duration(minutes: 65));
      final tx1 = TransactionModel(
        id: 'tx_1',
        amount: 50000,
        type: 'gopay_in',
        appSource: 'GoPay',
        payerName: 'Budi Santoso',
        dateTime: oldTime,
        rawMessage: 'GoPay: Pembayaran diterima Rp 50.000 dari Budi Santoso',
        appPackage: 'com.gojek.gopay',
      );
      await DatabaseService.saveTransaction(tx1);

      final txNew = TransactionModel(
        id: 'tx_2',
        amount: 50000,
        type: 'gopay_in',
        appSource: 'GoPay',
        payerName: 'Budi Santoso',
        dateTime: DateTime.now(),
        rawMessage: 'GoPay: Pembayaran diterima Rp 50.000 dari Budi Santoso',
        appPackage: 'com.gojek.gopay',
      );

      final isDup = await DatabaseService.isDuplicateTransaction(txNew);
      expect(isDup, isFalse);
    });
  });

  group('DatabaseService Offline Buffer & Retry Queue Tests', () {
    test('getFailedOrPendingTransactions retrieves failed transactions FIFO', () async {
      final now = DateTime.now();
      final txFailed1 = TransactionModel(
        id: 'tx_f1',
        amount: 10000,
        type: 'dana_in',
        appSource: 'DANA',
        payerName: 'User A',
        dateTime: now.subtract(const Duration(minutes: 5)),
        rawMessage: 'DANA Rp 10.000',
        appPackage: 'id.dana',
        webhookStatus: 'failed',
      );
      final txFailed2 = TransactionModel(
        id: 'tx_f2',
        amount: 20000,
        type: 'dana_in',
        appSource: 'DANA',
        payerName: 'User B',
        dateTime: now.subtract(const Duration(minutes: 2)),
        rawMessage: 'DANA Rp 20.000',
        appPackage: 'id.dana',
        webhookStatus: 'failed',
      );
      final txSuccess = TransactionModel(
        id: 'tx_s1',
        amount: 30000,
        type: 'dana_in',
        appSource: 'DANA',
        payerName: 'User C',
        dateTime: now.subtract(const Duration(minutes: 1)),
        rawMessage: 'DANA Rp 30.000',
        appPackage: 'id.dana',
        webhookStatus: 'success',
      );

      await DatabaseService.saveTransaction(txFailed1);
      await DatabaseService.saveTransaction(txFailed2);
      await DatabaseService.saveTransaction(txSuccess);

      final failedCount = await DatabaseService.getFailedWebhookCount();
      expect(failedCount, equals(2));

      final queue = await DatabaseService.getFailedOrPendingTransactions();
      expect(queue.length, equals(2));
      expect(queue.first.id, equals('tx_f1')); // FIFO
      expect(queue.last.id, equals('tx_f2'));
    });

    test('retryFailedTransactions successfully dispatches queued items and updates status', () async {
      await DatabaseService.setWebhookUrl('http://127.0.0.1:8000/api/webhook/dompetku');
      await DatabaseService.setAutoForwardEnabled(true);

      final txFailed = TransactionModel(
        id: 'tx_retry_1',
        amount: 150000,
        type: 'bca_in',
        appSource: 'BCA Mobile',
        payerName: 'Doni',
        dateTime: DateTime.now(),
        rawMessage: 'BCA Rp 150.000 dari Doni',
        appPackage: 'com.bca',
        webhookStatus: 'failed',
      );
      await DatabaseService.saveTransaction(txFailed);

      final mockClient = MockClient((request) async {
        return http.Response('{"status":"ok"}', 200);
      });

      final result = await WebhookService.retryFailedTransactions(
        client: mockClient,
        delayBetweenRequests: Duration.zero,
      );

      expect(result.totalProcessed, equals(1));
      expect(result.successCount, equals(1));
      expect(result.failedCount, equals(0));

      final updatedTx = await DatabaseService.getTransaction('tx_retry_1');
      expect(updatedTx?.webhookStatus, equals('success'));
      expect(updatedTx?.webhookHttpCode, equals(200));

      final remainingFailed = await DatabaseService.getFailedWebhookCount();
      expect(remainingFailed, equals(0));
    });
  });

  group('Webhook Security & Automatic Failover Tests', () {
    test('stores and retrieves webhookSecret and fallbackWebhookUrl correctly', () async {
      expect(await DatabaseService.getWebhookSecret(), isEmpty);
      expect(await DatabaseService.getFallbackWebhookUrl(), isEmpty);

      await DatabaseService.setWebhookSecret('super_secret_hmac_key');
      await DatabaseService.setFallbackWebhookUrl('http://192.168.100.61:8000/api/webhook/dompetku');

      expect(await DatabaseService.getWebhookSecret(), equals('super_secret_hmac_key'));
      expect(
        await DatabaseService.getFallbackWebhookUrl(),
        equals('http://192.168.100.61:8000/api/webhook/dompetku'),
      );
    });

    test('sendTransaction attaches cryptographic HMAC headers when webhookSecret is configured', () async {
      await DatabaseService.setWebhookUrl('http://127.0.0.1:8000/api/webhook/dompetku');
      await DatabaseService.setAutoForwardEnabled(true);
      await DatabaseService.setWebhookSecret('gas_secret_production');

      final tx = TransactionModel(
        id: 'tx_sec_1',
        amount: 250000,
        type: 'bca_in',
        appSource: 'BCA Mobile',
        payerName: 'Hendra Setiawan',
        dateTime: DateTime.now(),
        rawMessage: 'BCA: Rp 250.000 dari Hendra Setiawan order: GAS-202609-0099',
        appPackage: 'com.bca',
      );
      await DatabaseService.saveTransaction(tx);

      final mockClient = MockClient((request) async {
        expect(request.headers.containsKey('x-dompetku-timestamp'), isTrue);
        expect(request.headers.containsKey('x-dompetku-signature'), isTrue);

        final ts = int.parse(request.headers['x-dompetku-timestamp']!);
        final sig = request.headers['x-dompetku-signature']!;
        final expectedSig = WebhookService.generateHmacSignature('gas_secret_production', request.body, ts);
        expect(sig, equals(expectedSig));

        return http.Response('{"status":"verified_and_processed"}', 200);
      });

      final result = await WebhookService.sendTransaction(tx, client: mockClient);
      expect(result.isSuccess, isTrue);
      expect(result.statusCode, equals(200));

      final updatedTx = await DatabaseService.getTransaction('tx_sec_1');
      expect(updatedTx?.webhookStatus, equals('success'));
    });

    test('sendTransaction executes automatic failover to fallbackWebhookUrl when primary fails with SocketException', () async {
      const primaryUrl = 'http://127.0.0.1:8000/api/webhook/dompetku';
      const fallbackUrl = 'http://192.168.100.61:8000/api/webhook/dompetku';

      await DatabaseService.setWebhookUrl(primaryUrl);
      await DatabaseService.setFallbackWebhookUrl(fallbackUrl);
      await DatabaseService.setAutoForwardEnabled(true);

      final tx = TransactionModel(
        id: 'tx_failover_1',
        amount: 75000,
        type: 'gopay_in',
        appSource: 'GoPay',
        payerName: 'Kevin Sanjaya',
        dateTime: DateTime.now(),
        rawMessage: 'GoPay: Pembayaran diterima Rp 75.000 dari Kevin Sanjaya',
        appPackage: 'com.gojek.gopay',
      );
      await DatabaseService.saveTransaction(tx);

      int primaryAttempts = 0;
      int fallbackAttempts = 0;

      final mockClient = MockClient((request) async {
        if (request.url.toString() == primaryUrl) {
          primaryAttempts++;
          throw const SocketException('Connection refused to primary ADB USB');
        } else if (request.url.toString() == fallbackUrl) {
          fallbackAttempts++;
          return http.Response('{"status":"failover_received"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final result = await WebhookService.sendTransaction(tx, client: mockClient);

      expect(primaryAttempts, equals(1));
      expect(fallbackAttempts, equals(1));
      expect(result.isSuccess, isTrue);
      expect(result.statusCode, equals(200));

      final updatedTx = await DatabaseService.getTransaction('tx_failover_1');
      expect(updatedTx?.webhookStatus, equals('success'));
      expect(updatedTx?.webhookHttpCode, equals(200));
    });

    test('sendTransaction executes automatic failover when primary returns HTTP 502 Bad Gateway', () async {
      const primaryUrl = 'http://127.0.0.1:8000/api/webhook/dompetku';
      const fallbackUrl = 'http://192.168.100.61:8000/api/webhook/dompetku';

      await DatabaseService.setWebhookUrl(primaryUrl);
      await DatabaseService.setFallbackWebhookUrl(fallbackUrl);
      await DatabaseService.setAutoForwardEnabled(true);

      final tx = TransactionModel(
        id: 'tx_failover_502',
        amount: 100000,
        type: 'bca_in',
        appSource: 'BCA Mobile',
        payerName: 'Fajar Alfian',
        dateTime: DateTime.now(),
        rawMessage: 'BCA: Rp 100.000 dari Fajar Alfian',
        appPackage: 'com.bca',
      );
      await DatabaseService.saveTransaction(tx);

      final mockClient = MockClient((request) async {
        if (request.url.toString() == primaryUrl) {
          return http.Response('Bad Gateway (Proxy Down)', 502);
        } else if (request.url.toString() == fallbackUrl) {
          return http.Response('{"status":"fallback_success"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final result = await WebhookService.sendTransaction(tx, client: mockClient);
      expect(result.isSuccess, isTrue);
      expect(result.statusCode, equals(200));

      final updatedTx = await DatabaseService.getTransaction('tx_failover_502');
      expect(updatedTx?.webhookStatus, equals('success'));
      expect(updatedTx?.webhookHttpCode, equals(200));
    });

    test('sendTransaction executes automatic failover when primary encounters TimeoutException', () async {
      const primaryUrl = 'http://127.0.0.1:8000/api/webhook/dompetku';
      const fallbackUrl = 'http://192.168.100.61:8000/api/webhook/dompetku';

      await DatabaseService.setWebhookUrl(primaryUrl);
      await DatabaseService.setFallbackWebhookUrl(fallbackUrl);
      await DatabaseService.setAutoForwardEnabled(true);

      final tx = TransactionModel(
        id: 'tx_failover_timeout',
        amount: 80000,
        type: 'dana_in',
        appSource: 'DANA',
        payerName: 'Jonatan Christie',
        dateTime: DateTime.now(),
        rawMessage: 'DANA: Rp 80.000 dari Jonatan Christie',
        appPackage: 'id.dana',
      );
      await DatabaseService.saveTransaction(tx);

      final mockClient = MockClient((request) async {
        if (request.url.toString() == primaryUrl) {
          throw TimeoutException('ADB tunnel hung');
        } else if (request.url.toString() == fallbackUrl) {
          return http.Response('{"status":"saved_via_fallback"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final result = await WebhookService.sendTransaction(tx, client: mockClient);
      expect(result.isSuccess, isTrue);
      expect(result.statusCode, equals(200));

      final updatedTx = await DatabaseService.getTransaction('tx_failover_timeout');
      expect(updatedTx?.webhookStatus, equals('success'));
    });

    test('activatePreset cleanly resets authHeader when target preset has no authHeader', () async {
      final presetWithAuth = WebhookPreset(
        id: 'preset_with_auth',
        name: 'Server Auth',
        url: 'https://auth.example.com',
        authHeader: 'Bearer old_secret_123',
      );
      final presetWithoutAuth = WebhookPreset(
        id: 'preset_no_auth',
        name: 'Server Gastonyk Clean',
        url: 'http://127.0.0.1:8000/api/webhook/dompetku',
        authHeader: null,
      );

      await DatabaseService.saveWebhookPresets([presetWithAuth, presetWithoutAuth]);

      await DatabaseService.activatePreset('preset_with_auth');
      expect(await DatabaseService.getAuthHeader(), equals('Bearer old_secret_123'));

      await DatabaseService.activatePreset('preset_no_auth');
      expect(await DatabaseService.getAuthHeader(), isEmpty);
    });
  });
}
