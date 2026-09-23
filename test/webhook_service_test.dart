import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dompetku/models/transaction_model.dart';
import 'package:dompetku/services/webhook_service.dart';

void main() {
  group('WebhookService Formatting & Payload', () {
    final sampleTx = TransactionModel(
      id: '1700000000000',
      amount: 50000.0,
      type: 'gopay_in',
      appSource: 'GoPay',
      payerName: 'Budi S.',
      dateTime: DateTime(2026, 9, 9, 14, 30),
      rawMessage: 'Pembayaran QRIS Rp50.000 berhasil diterima dari Budi S.',
      appPackage: 'com.gojek.gopay',
    );

    test('formatMessage with raw format returns proper raw string', () {
      final msg = WebhookService.formatMessage(sampleTx, 'raw');
      expect(
        msg,
        equals('GoPay: Pembayaran QRIS Rp50.000 berhasil diterima dari Budi S.'),
      );
    });

    test('formatMessage with json_string format returns valid serialized JSON', () {
      final jsonMsg = WebhookService.formatMessage(sampleTx, 'json_string');
      final decoded = jsonDecode(jsonMsg) as Map<String, dynamic>;

      expect(decoded['id'], equals('1700000000000'));
      expect(decoded['amount'], equals(50000.0));
      expect(decoded['appSource'], equals('GoPay'));
      expect(decoded['payerName'], equals('Budi S.'));
    });

    test('extracts orderCode GAS- format from rawMessage and includes in json_string', () {
      final gasTx = TransactionModel(
        id: '1700000000001',
        amount: 150000.0,
        type: 'bca_in',
        appSource: 'BCA Mobile',
        payerName: 'Rina',
        dateTime: DateTime.now(),
        rawMessage: 'BCA: Transfer Rp 150.000 dari Rina ket: GAS-202609-0042',
        appPackage: 'com.bca',
      );

      expect(gasTx.orderCode, equals('GAS-202609-0042'));

      final jsonMsg = WebhookService.formatMessage(gasTx, 'json_string');
      final decoded = jsonDecode(jsonMsg) as Map<String, dynamic>;
      expect(decoded['order_code'], equals('GAS-202609-0042'));
    });
  });

  group('WebhookService testConnection with MockClient', () {
    test('returns success when server responds 200 OK', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.headers['content-type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['message'], isNotEmpty);
        expect(body['action'], equals('ping'));
        expect(body['event'], equals('ping'));
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      });

      final result = await WebhookService.testConnection(
        'https://example.com/api/webhook',
        client: mockClient,
      );

      expect(result.isSuccess, isTrue);
      expect(result.statusCode, equals(200));
      expect(result.errorMessage, isNull);
    });

    test('returns success when server responds 201 Created (Vercel standard)', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.headers['content-type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['message'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Webhook berhasil diterima dan disimpan!',
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final result = await WebhookService.testConnection(
        'https://webhook-server-sand.vercel.app/webhook',
        client: mockClient,
      );

      expect(result.isSuccess, isTrue);
      expect(result.statusCode, equals(201));
      expect(result.errorMessage, isNull);
    });

    test('returns failure when server responds 400 Bad Request', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Invalid column', 400);
      });

      final result = await WebhookService.testConnection(
        'https://example.com/api/webhook',
        client: mockClient,
      );

      expect(result.isSuccess, isFalse);
      expect(result.statusCode, equals(400));
      expect(result.errorMessage, contains('400'));
    });

    test('returns failure when server responds 500 Internal Server Error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Database error', 500);
      });

      final result = await WebhookService.testConnection(
        'https://example.com/api/webhook',
        client: mockClient,
      );

      expect(result.isSuccess, isFalse);
      expect(result.statusCode, equals(500));
    });

    test('handles custom authorization header properly', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['authorization'], equals('Bearer secret_token'));
        return http.Response('OK', 200);
      });

      final result = await WebhookService.testConnection(
        'https://example.com/api/webhook',
        authHeader: 'Bearer secret_token',
        client: mockClient,
      );

      expect(result.isSuccess, isTrue);
    });

    test('handles custom key-value header with colon', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['x-api-key'], equals('my_secret_key'));
        return http.Response('OK', 200);
      });

      final result = await WebhookService.testConnection(
        'https://example.com/api/webhook',
        authHeader: 'X-API-Key: my_secret_key',
        client: mockClient,
      );

      expect(result.isSuccess, isTrue);
    });

    test('returns failure when URL is empty', () async {
      final result = await WebhookService.testConnection('');
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('kosong'));
    });

    test('handles timeout gracefully', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Connection timed out');
      });

      final result = await WebhookService.testConnection(
        'https://timeout.com/webhook',
        client: mockClient,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('timeout'));
    });

    test('auto-attaches bypass-tunnel-reminder header for loca.lt URLs', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['bypass-tunnel-reminder'], equals('true'));
        return http.Response('OK', 200);
      });

      final result = await WebhookService.testConnection(
        'https://happy-foxes-sell.loca.lt/webhook',
        client: mockClient,
      );

      expect(result.isSuccess, isTrue);
    });
  });
}
