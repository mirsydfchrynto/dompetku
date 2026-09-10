// ============================================================
// FILE: webhook_preset.dart
//
// TUJUAN: Model data profil server webhook (Marsha, Wili, Fauzan, Custom)
//         Memungkinkan pengguna menambah, mengedit, menghapus,
//         dan beralih antar server backend secara instan.
// ============================================================

class WebhookPreset {
  final String id;
  final String name;
  final String url;
  final String? authHeader;
  final String payloadFormat; // 'raw' atau 'json_string'
  final bool isDefault;
  final int? lastHttpCode;
  final DateTime? lastTestedAt;

  WebhookPreset({
    required this.id,
    required this.name,
    required this.url,
    this.authHeader,
    this.payloadFormat = 'raw',
    this.isDefault = false,
    this.lastHttpCode,
    this.lastTestedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'authHeader': authHeader,
        'payloadFormat': payloadFormat,
        'isDefault': isDefault,
        'lastHttpCode': lastHttpCode,
        'lastTestedAt': lastTestedAt?.toIso8601String(),
      };

  factory WebhookPreset.fromJson(Map<String, dynamic> json) => WebhookPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        authHeader: json['authHeader'] as String?,
        payloadFormat: (json['payloadFormat'] as String?) ?? 'raw',
        isDefault: (json['isDefault'] as bool?) ?? false,
        lastHttpCode: json['lastHttpCode'] as int?,
        lastTestedAt: json['lastTestedAt'] != null
            ? DateTime.tryParse(json['lastTestedAt'] as String)
            : null,
      );

  WebhookPreset copyWith({
    String? id,
    String? name,
    String? url,
    String? authHeader,
    String? payloadFormat,
    bool? isDefault,
    int? lastHttpCode,
    DateTime? lastTestedAt,
  }) {
    return WebhookPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      authHeader: authHeader ?? this.authHeader,
      payloadFormat: payloadFormat ?? this.payloadFormat,
      isDefault: isDefault ?? this.isDefault,
      lastHttpCode: lastHttpCode ?? this.lastHttpCode,
      lastTestedAt: lastTestedAt ?? this.lastTestedAt,
    );
  }
}
