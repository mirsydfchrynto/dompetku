import 'package:flutter_test/flutter_test.dart';
import 'package:dompetku/models/webhook_preset.dart';

void main() {
  group('WebhookPreset Model Tests', () {
    test('creates WebhookPreset with default values', () {
      final preset = WebhookPreset(
        id: 'test_1',
        name: 'Server Marsha',
        url: 'https://webhook-server-sand.vercel.app/webhook',
      );

      expect(preset.id, 'test_1');
      expect(preset.name, 'Server Marsha');
      expect(preset.url, 'https://webhook-server-sand.vercel.app/webhook');
      expect(preset.payloadFormat, 'raw');
      expect(preset.isDefault, false);
      expect(preset.authHeader, isNull);
      expect(preset.lastHttpCode, isNull);
      expect(preset.lastTestedAt, isNull);
    });

    test('creates Gastonyk Official Webhook preset correctly', () {
      final preset = WebhookPreset(
        id: 'preset_gastonyk',
        name: 'Gastonyk Official Webhook',
        url: 'http://127.0.0.1:8000/api/webhook/dompetku',
        payloadFormat: 'json_string',
        isDefault: true,
      );

      expect(preset.id, equals('preset_gastonyk'));
      expect(preset.name, equals('Gastonyk Official Webhook'));
      expect(preset.url, equals('http://127.0.0.1:8000/api/webhook/dompetku'));
      expect(preset.payloadFormat, equals('json_string'));
      expect(preset.isDefault, isTrue);
    });

    test('serializes to and deserializes from JSON correctly', () {
      final now = DateTime.now();
      final original = WebhookPreset(
        id: 'preset_wili',
        name: 'Server Wili',
        url: 'https://d091-103-3-222-52.ngrok-free.app/api/notification',
        authHeader: 'Bearer wili_secret_123',
        payloadFormat: 'json_string',
        isDefault: true,
        lastHttpCode: 200,
        lastTestedAt: now,
      );

      final json = original.toJson();
      final reconstructed = WebhookPreset.fromJson(json);

      expect(reconstructed.id, original.id);
      expect(reconstructed.name, original.name);
      expect(reconstructed.url, original.url);
      expect(reconstructed.authHeader, original.authHeader);
      expect(reconstructed.payloadFormat, original.payloadFormat);
      expect(reconstructed.isDefault, original.isDefault);
      expect(reconstructed.lastHttpCode, 200);
      expect(reconstructed.lastTestedAt?.millisecondsSinceEpoch,
          original.lastTestedAt?.millisecondsSinceEpoch);
    });

    test('copyWith properly overrides specified properties', () {
      final preset = WebhookPreset(
        id: 'preset_1',
        name: 'Server Lama',
        url: 'https://old.com/api',
      );

      final updated = preset.copyWith(
        name: 'Server Baru',
        lastHttpCode: 201,
      );

      expect(updated.id, 'preset_1');
      expect(updated.name, 'Server Baru');
      expect(updated.url, 'https://old.com/api');
      expect(updated.lastHttpCode, 201);
    });
  });

  group('Smart Chat URL Extraction Logic', () {
    String extractSmartUrl(String chatText) {
      final urlRegex = RegExp(r'https?://[^\s<>"]+');
      final match = urlRegex.firstMatch(chatText);
      if (match == null) return '';
      var extracted = match.group(0)!;
      return extracted.replaceAll(RegExp(r'''[.,;:)\]"'\s]+$'''), '');
    }

    test('extracts raw ngrok URL from typical WhatsApp chat message', () {
      const chat =
          'bro ini endpoint server wili: https://d091-103-3-222-52.ngrok-free.app/api/notification ya tolong sambungin';
      final url = extractSmartUrl(chat);
      expect(url, 'https://d091-103-3-222-52.ngrok-free.app/api/notification');
    });

    test('strips trailing punctuation like dot, comma, or parenthesis', () {
      const chatWithDot =
          'Coba pasang di (https://api.fauzan.site/webhook/notification).';
      final url = extractSmartUrl(chatWithDot);
      expect(url, 'https://api.fauzan.site/webhook/notification');
    });

    test('extracts direct Vercel URL accurately', () {
      const chat =
          'https://webhook-server-sand.vercel.app/webhook';
      final url = extractSmartUrl(chat);
      expect(url, 'https://webhook-server-sand.vercel.app/webhook');
    });
  });
}
