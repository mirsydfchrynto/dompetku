// ============================================================
// FILE: webhook_settings_screen.dart
//
// TUJUAN: Halaman manajemen server webhook multi-profil
//         dengan fitur "Tempel Pintar dari Chat" yang otomatis
//         mendeteksi link ngrok/Vercel, menguji koneksi, dan memasangnya.
//
// FITUR UNGGULAN:
//   1. Multi-Server Profile: Simpan server Marsha, Wili, Fauzan,
//      atau server kustom lainnya; tambah, edit, hapus, dan beralih.
//   2. Tempel Pintar (Smart Paste): Membaca teks chat WhatsApp/Telegram,
//      mengekstrak URL webhook, menguji ping otomatis, dan meminta API Key
//      secara ramah hanya jika server mengembalikan HTTP 401/403.
//   3. Status & Ping Visual: Menampilkan respons HTTP (200/201/401/dll).
//   4. Opsi Format Payload: Raw string vs JSON string.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/webhook_preset.dart';
import '../services/database_service.dart';
import '../services/webhook_service.dart';

class WebhookSettingsScreen extends StatefulWidget {
  const WebhookSettingsScreen({super.key});

  @override
  State<WebhookSettingsScreen> createState() => _WebhookSettingsScreenState();
}

class _WebhookSettingsScreenState extends State<WebhookSettingsScreen> {
  List<WebhookPreset> _presets = [];
  String _activeUrl = '';
  String _payloadFormat = 'raw';
  bool _isAutoForward = true;
  bool _forwardFinancialOnly = true;
  String _fallbackUrl = '';
  String _webhookSecret = '';
  bool _isTestingFallback = false;
  WebhookResult? _fallbackTestResult;

  bool _isLoading = true;
  String? _testingPresetId;
  final Map<String, WebhookResult?> _testResults = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final presets = await DatabaseService.getWebhookPresets();
    final url = await DatabaseService.getWebhookUrl();
    final format = await DatabaseService.getPayloadFormat();
    final isAuto = await DatabaseService.isAutoForwardEnabled();
    final financialOnly = await DatabaseService.isForwardFinancialOnly();
    final fallbackUrl = await DatabaseService.getFallbackWebhookUrl();
    final secret = await DatabaseService.getWebhookSecret();

    if (mounted) {
      setState(() {
        _presets = presets;
        _activeUrl = url;
        _payloadFormat = format;
        _isAutoForward = isAuto;
        _forwardFinancialOnly = financialOnly;
        _fallbackUrl = fallbackUrl;
        _webhookSecret = secret;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchActivePreset(WebhookPreset preset) async {
    await DatabaseService.activatePreset(preset.id);
    await _loadAll();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Server aktif: ${preset.name}'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00897B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testPreset(WebhookPreset preset) async {
    setState(() {
      _testingPresetId = preset.id;
    });

    final result = await WebhookService.testConnection(
      preset.url,
      authHeader: preset.authHeader?.isNotEmpty == true ? preset.authHeader : null,
      secret: preset.webhookSecret?.isNotEmpty == true ? preset.webhookSecret : null,
    );

    // Update last test code on preset
    final updated = preset.copyWith(
      lastHttpCode: result.statusCode,
      lastTestedAt: DateTime.now(),
    );
    await DatabaseService.saveOrUpdatePreset(updated);

    if (mounted) {
      setState(() {
        _testingPresetId = null;
        _testResults[preset.id] = result;
      });
      _loadAll();
    }
  }

  // ── FITUR UTAMA: TEMPEL PINTAR DARI CHAT ────────────────────
  Future<void> _handleSmartPaste() async {
    // 1. Ambil teks dari clipboard
    final clipData = await Clipboard.getData('text/plain');
    final rawText = clipData?.text?.trim() ?? '';

    if (!mounted) return;

    // Dialog untuk konfirmasi atau paste manual jika clipboard kosong
    final textToProcess = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: rawText);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF00897B)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tempel Pintar Chat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Salin chat dari Wili, Fauzan, atau teman Anda, lalu tempel di sini. Aplikasi akan otomatis mencari link server dan langsung menghubungkannya:',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Contoh: "bro ini url wili https://d091-xxx.ngrok-free.app/api/notification ya"',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.flash_on, size: 16),
              label: const Text('Ekstrak & Hubungkan'),
            ),
          ],
        );
      },
    );

    if (textToProcess == null || textToProcess.isEmpty) return;

    // 2. Ekstrak URL menggunakan Regex
    final urlRegex = RegExp(r'https?://[^\s<>"{}|\^~\[\]`]+', caseSensitive: false);
    final match = urlRegex.firstMatch(textToProcess);

    if (match == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ditemukan link URL (http/https) dalam teks tersebut.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    var extractedUrl = match.group(0)!;
    // Bersihkan tanda baca di akhir URL (titik, koma, kurung)
    extractedUrl = extractedUrl.replaceAll(RegExp(r'''[.,;:)\]"'\s]+$'''), '');

    // 3. Tentukan nama server pintar dari teks chat
    String serverName = 'Server Kustom';
    final lower = textToProcess.toLowerCase();
    if (lower.contains('wili') || lower.contains('willi')) {
      serverName = 'Server Wili';
    } else if (lower.contains('fauzan') || lower.contains('ojan')) {
      serverName = 'Server Fauzan';
    } else if (lower.contains('marsha')) {
      serverName = 'Server Marsha';
    } else {
      try {
        final host = Uri.parse(extractedUrl).host;
        serverName = 'Server $host';
      } catch (_) {
        serverName = 'Server Baru';
      }
    }

    // 4. Uji koneksi awal tanpa auth
    if (!mounted) return;
    _showTestingDialog(serverName, extractedUrl);

    final result = await WebhookService.testConnection(extractedUrl);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Tutup loading

    // Kasus A: Berhasil Terhubung (200 / 201)
    if (result.isSuccess) {
      final newPreset = WebhookPreset(
        id: 'preset_${DateTime.now().millisecondsSinceEpoch}',
        name: serverName,
        url: extractedUrl,
        lastHttpCode: result.statusCode,
        lastTestedAt: DateTime.now(),
      );
      await DatabaseService.saveOrUpdatePreset(newPreset);
      await DatabaseService.activatePreset(newPreset.id);
      await _loadAll();

      if (mounted) {
        _showSuccessDialog(serverName, extractedUrl, result.statusCode);
      }
    }
    // Kasus B: Butuh Otorisasi (401 / 403) -> Tampilkan Dialog Ramah Minta API Key
    else if (result.statusCode == 401 || result.statusCode == 403) {
      final apiKey = await _promptApiKeyDialog(serverName, extractedUrl);
      if (apiKey != null && apiKey.isNotEmpty) {
        // Uji lagi dengan API Key
        final secondResult = await WebhookService.testConnection(
          extractedUrl,
          authHeader: apiKey,
        );

        final newPreset = WebhookPreset(
          id: 'preset_${DateTime.now().millisecondsSinceEpoch}',
          name: serverName,
          url: extractedUrl,
          authHeader: apiKey,
          lastHttpCode: secondResult.statusCode,
          lastTestedAt: DateTime.now(),
        );
        await DatabaseService.saveOrUpdatePreset(newPreset);
        await DatabaseService.activatePreset(newPreset.id);
        await _loadAll();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kunci API disimpan! Server $serverName aktif.'),
              backgroundColor: const Color(0xFF00897B),
            ),
          );
        }
      }
    }
    // Kasus C: Server Belum Aktif / Error
    else {
      final shouldSave = await _promptFailedDialog(
        serverName,
        extractedUrl,
        result.errorMessage ?? 'HTTP ${result.statusCode}',
      );
      if (shouldSave == true) {
        final newPreset = WebhookPreset(
          id: 'preset_${DateTime.now().millisecondsSinceEpoch}',
          name: serverName,
          url: extractedUrl,
          lastHttpCode: result.statusCode,
          lastTestedAt: DateTime.now(),
        );
        await DatabaseService.saveOrUpdatePreset(newPreset);
        await DatabaseService.activatePreset(newPreset.id);
        await _loadAll();
      }
    }
  }

  void _showTestingDialog(String name, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF00897B)),
            const SizedBox(height: 16),
            Text(
              'Menghubungi $name...',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              url,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String name, String url, int? code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        title: Text('Berhasil Terhubung! (HTTP ${code ?? 200})'),
        content: Text(
          '$name telah disimpan dan langsung aktif sebagai endpoint penerima notifikasi di DompetKu:\n\n$url',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptApiKeyDialog(String name, String url) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('Perlu API Key / Token', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Server $name merespons HTTP 401/403 (Memerlukan izin otentikasi). Silakan masukkan API Key atau Bearer Token jika ada:',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: 'Bearer secret_token_anda',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Lewati'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan & Pasang'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _promptFailedDialog(String name, String url, String error) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Server Belum Menjawab', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Endpoint: $url\n\nPesan: $error\n\nServer teman Anda mungkin belum dinyalakan atau tunnel ngrok sedang offline. Apakah ingin tetap menyimpannya agar siap digunakan nanti?',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tetap Simpan & Pasang'),
          ),
        ],
      ),
    );
  }

  // ── TAMBAH / EDIT PRESET MANUAL ─────────────────────────────
  Future<void> _openEditPresetDialog([WebhookPreset? existing]) async {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    final authCtrl = TextEditingController(text: existing?.authHeader ?? '');
    final secretCtrl = TextEditingController(text: existing?.webhookSecret ?? '');
    String format = existing?.payloadFormat ?? 'raw';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEditing ? 'Edit Server Webhook' : 'Tambah Server Webhook Baru',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Server (Contoh: Server Wili)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    labelText: 'URL Endpoint (POST)',
                    hintText: 'https://...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: authCtrl,
                  decoration: InputDecoration(
                    labelText: 'API Key / Auth Header (Opsional)',
                    hintText: 'Bearer token...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: secretCtrl,
                  decoration: InputDecoration(
                    labelText: 'Webhook Secret / HMAC Key (Opsional)',
                    hintText: 'Secret untuk tanda tangan HMAC-SHA256...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Format: ', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Raw Text'),
                      selected: format == 'raw',
                      onSelected: (val) {
                        if (val) setDialogState(() => format = 'raw');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('JSON String'),
                      selected: format == 'json_string',
                      onSelected: (val) {
                        if (val) setDialogState(() => format = 'json_string');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final url = urlCtrl.text.trim();
                if (url.isEmpty) return;

                final secret = secretCtrl.text.trim();
                final updated = WebhookPreset(
                  id: existing?.id ?? 'preset_${DateTime.now().millisecondsSinceEpoch}',
                  name: name.isNotEmpty ? name : 'Server Kustom',
                  url: url,
                  authHeader: authCtrl.text.trim().isNotEmpty ? authCtrl.text.trim() : null,
                  webhookSecret: secret.isNotEmpty ? secret : null,
                  payloadFormat: format,
                  isDefault: existing?.isDefault ?? false,
                );

                await DatabaseService.saveOrUpdatePreset(updated);
                if (existing?.url == _activeUrl) {
                  await DatabaseService.setWebhookSecret(secret);
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _loadAll();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
              ),
              child: Text(isEditing ? 'Simpan Perubahan' : 'Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePreset(WebhookPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${preset.name}?'),
        content: Text('Server ${preset.url} akan dihapus dari daftar simpanan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.deletePreset(preset.id);
      await _loadAll();
    }
  }

  Future<void> _openEditFallbackDialog() async {
    final ctrl = TextEditingController(text: _fallbackUrl);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Endpoint Failover / Cadangan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jika endpoint utama (misal: ADB USB 127.0.0.1:8000) gagal terhubung, DompetKu langsung mengalihkan pengiriman ke endpoint cadangan (misal: IP Wi-Fi 192.168.100.61:8000) sebelum masuk ke antrean offline.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: 'URL Endpoint Failover',
                hintText: 'http://192.168.100.61:8000/api/webhook/dompetku',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = ctrl.text.trim();
              await DatabaseService.setFallbackWebhookUrl(newUrl);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _testFallbackUrl() async {
    if (_fallbackUrl.isEmpty) return;
    setState(() {
      _isTestingFallback = true;
      _fallbackTestResult = null;
    });

    final authHeader = await DatabaseService.getAuthHeader();
    final result = await WebhookService.testConnection(
      _fallbackUrl,
      authHeader: authHeader.isNotEmpty ? authHeader : null,
      secret: _webhookSecret.isNotEmpty ? _webhookSecret : null,
    );

    if (mounted) {
      setState(() {
        _isTestingFallback = false;
        _fallbackTestResult = result;
      });
    }
  }

  Future<void> _openEditSecretDialog() async {
    final ctrl = TextEditingController(text: _webhookSecret);
    bool obscure = true;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Webhook Secret (HMAC-SHA256)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kunci rahasia untuk menandatangani setiap notifikasi dengan header X-Dompetku-Signature dan X-Dompetku-Timestamp. Wajib cocok dengan config services.dompetku.webhook_secret di server Gastonyk.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'HMAC Secret Key',
                  hintText: 'Masukkan secret key backend...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setDialogState(() => obscure = !obscure);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newSecret = ctrl.text.trim();
                await DatabaseService.setWebhookSecret(newSecret);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan Secret'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          'Integrasi Webhook Server',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00897B)),
            tooltip: 'Tambah Server Manual',
            onPressed: () => _openEditPresetDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── HERO BANNER: TEMPEL PINTAR DARI CHAT ────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF004D40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00897B).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.flash_on, color: Colors.amber, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Punya Link dari Chat WhatsApp / Telegram?',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tinggal salin chat dari Wili atau Fauzan, lalu klik tombol di bawah. DompetKu otomatis membedah URL, menguji ping server, dan memasang endpoint-nya secara instan!',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _handleSmartPaste,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF00695C),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.paste_rounded, size: 18),
                          label: Text(
                            'Tempel Pintar dari Chat',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── HEADER DAFTAR SERVER TERSIMPAN ──────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Server Webhook Aktif:',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openEditPresetDialog(),
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF00897B)),
                      label: const Text(
                        'Tambah',
                        style: TextStyle(
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── LIST PRESETS ────────────────────────────
                RadioGroup<String>(
                  groupValue: _activeUrl,
                  onChanged: (val) {
                    if (val != null) {
                      final p = _presets.where((e) => e.url == val).firstOrNull;
                      if (p != null) {
                        _switchActivePreset(p);
                      }
                    }
                  },
                  child: Column(
                    children: _presets.map((preset) {
                      final isActive = preset.url == _activeUrl;
                      final isTestingThis = _testingPresetId == preset.id;
                      final testRes = _testResults[preset.id];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF00897B)
                                : Colors.grey.shade200,
                            width: isActive ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isActive
                                  ? const Color(0xFF00897B).withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Radio<String>(
                                    value: preset.url,
                                    activeColor: const Color(0xFF00897B),
                                  ),
                                  const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            preset.name,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isActive) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.green.shade300,
                                              ),
                                            ),
                                            child: Text(
                                              'AKTIF',
                                              style: TextStyle(
                                                color: Colors.green.shade800,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      preset.url,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade600,
                                        fontFamily: 'monospace',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _openEditPresetDialog(preset);
                                  } else if (val == 'delete') {
                                    _deletePreset(preset);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 16),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  if (!preset.isDefault)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Hapus', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Status badge
                              if (preset.lastHttpCode != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (preset.lastHttpCode == 200 || preset.lastHttpCode == 201)
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Status: HTTP ${preset.lastHttpCode}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: (preset.lastHttpCode == 200 || preset.lastHttpCode == 201)
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  'Belum diuji',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),

                              // Test Button
                              SizedBox(
                                height: 32,
                                child: OutlinedButton.icon(
                                  onPressed: isTestingThis ? null : () => _testPreset(preset),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  icon: isTestingThis
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 1.5),
                                        )
                                      : const Icon(Icons.sensors, size: 14),
                                  label: Text(
                                    isTestingThis ? 'Menguji...' : 'Test Ping',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (testRes != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              testRes.isSuccess
                                  ? '✅ Berhasil merespons HTTP ${testRes.statusCode}'
                                  : '❌ Gagal: ${testRes.errorMessage}',
                              style: TextStyle(
                                fontSize: 11,
                                color: testRes.isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

                const SizedBox(height: 16),

                // ── KEAMANAN KERAS & REDUNDANSI JARINGAN ───────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF00897B).withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00897B).withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              size: 18,
                              color: Color(0xFF00897B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Keamanan Keras & Redundansi (24/7)',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fitur otomatis untuk menjamin DompetKu berjalan non-stop sebagai Payment Gateway Gastonyk tanpa terputus kabel USB atau dipalsukan peretas.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      const Divider(height: 22),

                      // ITEM 1: HMAC SECRET KEY
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _webhookSecret.isNotEmpty ? Icons.lock_rounded : Icons.lock_open_rounded,
                            size: 18,
                            color: _webhookSecret.isNotEmpty ? Colors.green.shade700 : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'HMAC-SHA256 Signature',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _webhookSecret.isNotEmpty ? Colors.green.shade50 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _webhookSecret.isNotEmpty ? Colors.green.shade300 : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        _webhookSecret.isNotEmpty ? 'AKTIF' : 'NONAKTIF',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: _webhookSecret.isNotEmpty ? Colors.green.shade800 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _webhookSecret.isNotEmpty
                                      ? 'Setiap payload ditandatangani dengan X-Dompetku-Signature & Timestamp anti-replay.'
                                      : 'Belum diatur. Gastonyk mode ketat mewajibkan secret ini.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _openEditSecretDialog,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(50, 32),
                            ),
                            child: Text(
                              _webhookSecret.isNotEmpty ? 'Ubah' : 'Atur',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 22),

                      // ITEM 2: FAILOVER ENDPOINT
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.alt_route_rounded,
                            size: 18,
                            color: _fallbackUrl.isNotEmpty ? const Color(0xFF00897B) : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Endpoint Failover (Wi-Fi/LAN)',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _fallbackUrl.isNotEmpty ? Colors.teal.shade50 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _fallbackUrl.isNotEmpty ? Colors.teal.shade300 : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        _fallbackUrl.isNotEmpty ? 'TERPASANG' : 'KOSONG',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: _fallbackUrl.isNotEmpty ? const Color(0xFF00695C) : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _fallbackUrl.isNotEmpty
                                      ? _fallbackUrl
                                      : 'Jika kabel USB ADB putus, kirim ke IP LAN cadangan.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _fallbackUrl.isNotEmpty ? Colors.grey.shade800 : Colors.grey.shade600,
                                    fontFamily: _fallbackUrl.isNotEmpty ? 'monospace' : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _openEditFallbackDialog,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(50, 32),
                            ),
                            child: Text(
                              _fallbackUrl.isNotEmpty ? 'Ubah' : 'Atur',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),

                      if (_fallbackUrl.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 30,
                              child: OutlinedButton.icon(
                                onPressed: _isTestingFallback ? null : _testFallbackUrl,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                icon: _isTestingFallback
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 1.5),
                                      )
                                    : const Icon(Icons.sensors, size: 14),
                                label: Text(
                                  _isTestingFallback ? 'Menguji Failover...' : 'Test Ping Failover',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_fallbackTestResult != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _fallbackTestResult!.isSuccess
                                ? '✅ Failover berhasil merespons HTTP ${_fallbackTestResult!.statusCode}'
                                : '❌ Gagal: ${_fallbackTestResult!.errorMessage}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _fallbackTestResult!.isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── PREFERENSI & PENGATURAN UMUM ─────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 18, color: Color(0xFF00897B)),
                          const SizedBox(width: 8),
                          Text(
                            'Pengaturan Pengiriman',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Kirim Otomatis ke Backend',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Setiap notifikasi uang masuk langsung diteruskan tanpa konfirmasi manual.',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        value: _isAutoForward,
                        activeTrackColor: const Color(0xFF00897B),
                        onChanged: (val) async {
                          setState(() => _isAutoForward = val);
                          await DatabaseService.setAutoForwardEnabled(val);
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Hanya Notifikasi Finansial',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Memblokir kode OTP, pesan chat biasa, dan promo non-transaksi.',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        value: _forwardFinancialOnly,
                        activeTrackColor: const Color(0xFF00897B),
                        onChanged: (val) async {
                          setState(() => _forwardFinancialOnly = val);
                          await DatabaseService.setForwardFinancialOnly(val);
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 6),
                      Text(
                        'Format Pesan Kolom message:',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: 'raw',
                              label: Text('Teks Raw'),
                              icon: Icon(Icons.text_fields, size: 16),
                            ),
                            ButtonSegment(
                              value: 'json_string',
                              label: Text('JSON String'),
                              icon: Icon(Icons.data_object, size: 16),
                            ),
                          ],
                          selected: {_payloadFormat},
                          onSelectionChanged: (set) async {
                            final val = set.first;
                            setState(() => _payloadFormat = val);
                            await DatabaseService.setPayloadFormat(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
