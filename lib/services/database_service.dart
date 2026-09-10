// ============================================================
// FILE: database_service.dart
//
// TUJUAN: Menyimpan & mengambil transaksi dari memori HP
//
// Menggunakan HIVE — database key-value lokal yang cepat.
// Bayangkan Hive seperti "laci" (Box) di HP yang bisa
// menyimpan objek Dart secara permanen.
//
// OPERASI CRUD:
//   CREATE → saveTransaction()
//   READ   → getAllTransactions(), getTodayTransactions()
//   UPDATE → (tidak diperlukan, notifikasi tidak diedit)
//   DELETE → deleteTransaction(), clearAll()
// ============================================================

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction_model.dart';
import '../models/webhook_preset.dart';

class DatabaseService {
  // Nama "laci" Hive kita
  static const String _boxName = 'transactions';

  static bool _isInitialized = false;

  /// Memastikan Flutter binding dan Hive sudah siap sebelum operasi database,
  /// sangat krusial saat dipanggil dari background isolate/engine Android.
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    try {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(TransactionModelAdapter());
      }
      _isInitialized = true;
    } catch (_) {
      _isInitialized = true;
    }
  }

  // Getter helper untuk buka laci
  // "async" karena membuka file di disk butuh waktu
  static Future<Box<TransactionModel>> get _box async {
    await ensureInitialized();
    // openBox: buka laci; jika belum ada, buat baru
    return await Hive.openBox<TransactionModel>(_boxName);
  }

  // ── CREATE ───────────────────────────────────────────────

  /// Simpan satu transaksi baru ke database.
  /// Pakai transaction.id sebagai key agar tidak duplikat.
  static Future<void> saveTransaction(TransactionModel transaction) async {
    final box = await _box;
    await box.put(transaction.id, transaction);
    // put(key, value) = simpan dengan key tertentu
    // Jika key sudah ada, data lama akan ditimpa
  }

  // ── READ ─────────────────────────────────────────────────

  /// Ambil semua transaksi, diurutkan dari yang terbaru.
  static Future<List<TransactionModel>> getAllTransactions() async {
    final box = await _box;
    // box.values = semua nilai yang tersimpan (tanpa key)
    final list = box.values.toList();
    // Urutkan: dateTime terbesar (terbaru) di posisi pertama
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  /// Ambil hanya transaksi hari ini.
  static Future<List<TransactionModel>> getTodayTransactions() async {
    final all = await getAllTransactions();
    final now = DateTime.now();
    // Filter: hanya yang tanggal, bulan, tahunnya sama dengan hari ini
    return all.where((t) {
      return t.dateTime.year == now.year &&
          t.dateTime.month == now.month &&
          t.dateTime.day == now.day;
    }).toList();
  }

  /// Hitung total nominal semua transaksi masuk hari ini.
  static Future<double> getTodayIncome() async {
    final todayList = await getTodayTransactions();
    return todayList
        .where((t) => t.isIncoming)
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Hitung total nominal semua transaksi keluar hari ini.
  static Future<double> getTodayExpense() async {
    final todayList = await getTodayTransactions();
    return todayList
        .where((t) => t.isOutgoing)
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Hitung total nominal semua transaksi hari ini (bersih = masuk - keluar).
  static Future<double> getTodayTotal() async {
    final income = await getTodayIncome();
    final expense = await getTodayExpense();
    return income - expense;
  }

  /// Hitung jumlah transaksi hari ini.
  static Future<int> getTodayCount() async {
    return (await getTodayTransactions()).length;
  }

  /// Hitung jumlah transaksi masuk hari ini.
  static Future<int> getTodayIncomeCount() async {
    final todayList = await getTodayTransactions();
    return todayList.where((t) => t.isIncoming).length;
  }

  /// Hitung jumlah transaksi keluar hari ini.
  static Future<int> getTodayExpenseCount() async {
    final todayList = await getTodayTransactions();
    return todayList.where((t) => t.isOutgoing).length;
  }

  // ── UPDATE ───────────────────────────────────────────────

  /// Update transaksi yang sudah ada (misal: update status webhook).
  static Future<void> updateTransaction(TransactionModel transaction) async {
    final box = await _box;
    await box.put(transaction.id, transaction);
  }

  /// Ambil satu transaksi berdasarkan ID.
  static Future<TransactionModel?> getTransaction(String id) async {
    final box = await _box;
    return box.get(id);
  }

  // ── DELETE ───────────────────────────────────────────────

  /// Hapus satu transaksi berdasarkan ID.
  static Future<void> deleteTransaction(String id) async {
    final box = await _box;
    await box.delete(id);
  }

  /// Hapus semua transaksi (untuk reset demo).
  static Future<void> clearAll() async {
    final box = await _box;
    await box.clear();
    // clear() = hapus semua data di laci, tapi lacinya tetap ada
  }

  // ── SETTINGS (PENGATURAN WEBHOOK) ─────────────────────────
  static const String _settingsBoxName = 'settings';

  static Future<Box> get _settingsBox async {
    return await Hive.openBox(_settingsBoxName);
  }

  /// Default webhook endpoint (Marsha Vercel 24/7 backend)
  static const String defaultWebhookUrl =
      'https://webhook-server-sand.vercel.app/webhook';

  /// Ambil URL endpoint webhook yang tersimpan.
  static Future<String> getWebhookUrl() async {
    final box = await _settingsBox;
    final saved = box.get('webhook_url') as String?;
    if (saved != null && saved.isNotEmpty) {
      // Otomatis migrasi endpoint lokal/sementara yang sudah tidak aktif
      if (saved.contains('loca.lt') || saved.contains('787e-103-3-222-52.ngrok-free.app')) {
        await box.put('webhook_url', defaultWebhookUrl);
        return defaultWebhookUrl;
      }
      return saved;
    }
    return defaultWebhookUrl;
  }

  /// Simpan URL endpoint webhook.
  static Future<void> setWebhookUrl(String url) async {
    final box = await _settingsBox;
    await box.put('webhook_url', url.trim());
  }

  /// Cek apakah pengiriman otomatis aktif.
  static Future<bool> isAutoForwardEnabled() async {
    final box = await _settingsBox;
    return box.get('is_auto_forward_enabled', defaultValue: true) as bool;
  }

  /// Set status pengiriman otomatis.
  static Future<void> setAutoForwardEnabled(bool enabled) async {
    final box = await _settingsBox;
    await box.put('is_auto_forward_enabled', enabled);
  }

  /// Cek apakah hanya kirim notifikasi finansial / QRIS.
  static Future<bool> isForwardFinancialOnly() async {
    final box = await _settingsBox;
    return box.get('forward_financial_only', defaultValue: true) as bool;
  }

  /// Set opsi filter hanya finansial.
  static Future<void> setForwardFinancialOnly(bool enabled) async {
    final box = await _settingsBox;
    await box.put('forward_financial_only', enabled);
  }

  /// Ambil Custom Header / Auth Token (opsional).
  static Future<String> getAuthHeader() async {
    final box = await _settingsBox;
    return box.get('auth_header', defaultValue: '') as String;
  }

  /// Simpan Custom Header / Auth Token.
  static Future<void> setAuthHeader(String header) async {
    final box = await _settingsBox;
    await box.put('auth_header', header.trim());
  }

  /// Ambil format payload ('raw' atau 'json_string').
  static Future<String> getPayloadFormat() async {
    final box = await _settingsBox;
    return box.get('payload_format', defaultValue: 'raw') as String;
  }

  /// Simpan format payload ('raw' atau 'json_string').
  static Future<void> setPayloadFormat(String format) async {
    final box = await _settingsBox;
    await box.put('payload_format', format);
  }

  // ── SERVER PRESETS (MARSHA, WILI, FAUZAN, DLL) ────────────
  static const String _presetsBoxName = 'webhook_presets';

  static Future<Box> get _presetsBox async {
    return await Hive.openBox(_presetsBoxName);
  }

  /// Ambil semua preset server webhook. Jika kosong, buatkan preset bawaan.
  static Future<List<WebhookPreset>> getWebhookPresets() async {
    final box = await _presetsBox;
    final rawList = box.get('presets_list');

    if (rawList == null || (rawList is List && rawList.isEmpty)) {
      final initial = _defaultPresets();
      await saveWebhookPresets(initial);
      return initial;
    }

    try {
      final list = (rawList as List)
          .map((item) => WebhookPreset.fromJson(
              Map<String, dynamic>.from(jsonDecode(item as String))))
          .toList();
      return list;
    } catch (_) {
      final initial = _defaultPresets();
      await saveWebhookPresets(initial);
      return initial;
    }
  }

  /// Preset awal bawaan tim (Marsha, Wili, Fauzan)
  static List<WebhookPreset> _defaultPresets() {
    return [
      WebhookPreset(
        id: 'preset_marsha',
        name: 'Marsha (Vercel Cloud 24/7)',
        url: defaultWebhookUrl,
        isDefault: true,
      ),
      WebhookPreset(
        id: 'preset_wili',
        name: 'Wili (Ngrok Server)',
        url: 'https://d091-103-3-222-52.ngrok-free.app/api/notification',
        isDefault: false,
      ),
      WebhookPreset(
        id: 'preset_fauzan',
        name: 'Fauzan (Ngrok Server)',
        url: 'https://amber-eardrum-mothproof.ngrok-free.dev/api/webhook-notif',
        isDefault: false,
      ),
    ];
  }

  /// Simpan seluruh daftar preset.
  static Future<void> saveWebhookPresets(List<WebhookPreset> presets) async {
    final box = await _presetsBox;
    final encoded = presets.map((p) => jsonEncode(p.toJson())).toList();
    await box.put('presets_list', encoded);
  }

  /// Tambah atau perbarui satu preset server.
  static Future<void> saveOrUpdatePreset(WebhookPreset preset) async {
    final list = await getWebhookPresets();
    final index = list.indexWhere((p) => p.id == preset.id);
    if (index >= 0) {
      list[index] = preset;
    } else {
      list.add(preset);
    }
    await saveWebhookPresets(list);
  }

  /// Hapus satu preset berdasarkan ID.
  static Future<bool> deletePreset(String id) async {
    final list = await getWebhookPresets();
    final currentActiveUrl = await getWebhookUrl();
    final target = list.firstWhere((p) => p.id == id, orElse: () => list.first);

    // Jangan biarkan kosong tanpa server aktif
    if (target.url == currentActiveUrl && list.length > 1) {
      final alternative = list.firstWhere((p) => p.id != id);
      await activatePreset(alternative.id);
    }

    list.removeWhere((p) => p.id == id);
    await saveWebhookPresets(list);
    return true;
  }

  /// Aktifkan satu preset sebagai server yang sedang digunakan.
  static Future<void> activatePreset(String id) async {
    final list = await getWebhookPresets();
    final target = list.firstWhere((p) => p.id == id, orElse: () => list.first);
    await setWebhookUrl(target.url);
    if (target.authHeader != null) {
      await setAuthHeader(target.authHeader!);
    }
    await setPayloadFormat(target.payloadFormat);
  }
}
