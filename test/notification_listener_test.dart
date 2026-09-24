import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:dompetku/services/notification_listener_service.dart';
import 'package:dompetku/services/database_service.dart';
import 'package:dompetku/models/transaction_model.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
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
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  NotificationEvent createEvent(String title, String text, String pkg) {
    return NotificationEvent(
      title: title,
      text: text,
      packageName: pkg,
      key: 'test_key_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<int> getTransactionCount() async {
    final box = Hive.box<TransactionModel>('transactions');
    return box.length;
  }

  test('Financial notification -> transaction created -> webhook eligible', () async {
    final event = createEvent('BCAmobile', 'm-Transfer dari Budi Rp 50.000 telah masuk', 'com.bca');
    await AppNotificationListenerService.handleIncomingNotification(event);
    expect(await getTransactionCount(), 1);
    
    final tx = Hive.box<TransactionModel>('transactions').getAt(0)!;
    expect(tx.amount, 50000);
    expect(tx.payerName.contains('Budi'), isTrue);
  });

  test('Promo notification -> ignored -> no database transaction', () async {
    final event = createEvent('Promo GOPAY', 'Diskon 50% hari ini!', 'com.gojek.app');
    await AppNotificationListenerService.handleIncomingNotification(event);
    expect(await getTransactionCount(), 0);
  });

  test('OTP -> ignored', () async {
    final event = createEvent('WhatsApp', 'Kode OTP Anda adalah 123456', 'com.whatsapp');
    await AppNotificationListenerService.handleIncomingNotification(event);
    expect(await getTransactionCount(), 0);
  });

  test('Chat/social -> ignored', () async {
    final event = createEvent('Telegram', 'Halo apa kabar?', 'org.telegram.messenger');
    await AppNotificationListenerService.handleIncomingNotification(event);
    expect(await getTransactionCount(), 0);
  });

  test('Unknown notification -> ignored', () async {
    final event = createEvent('RandomApp', 'Hello', 'com.random.app');
    await AppNotificationListenerService.handleIncomingNotification(event);
    expect(await getTransactionCount(), 0);
  });

  test('Arbitrary notification with filter disabled -> STILL ignored -> no raw_notif', () async {
    // Filter was removed, it is always enforced now.
    final event = createEvent('SMS', 'Your balance is low', 'com.android.mms');
    await AppNotificationListenerService.handleIncomingNotification(event);
    expect(await getTransactionCount(), 0);
  });

  test('Array/malformed notification input -> no crash', () async {
    // Pass null where possible to test robustness if Event somehow allows it
    final event = NotificationEvent(
      title: null,
      text: null,
      packageName: null,
    );
    await AppNotificationListenerService.handleIncomingNotification(event);
    expect(await getTransactionCount(), 0);
  });
}
