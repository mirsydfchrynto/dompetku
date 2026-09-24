// ============================================================
// FILE: main.dart
//
// TUJUAN: Titik awal (entry point) aplikasi Flutter
//
// Ini adalah file PERTAMA yang dijalankan ketika app dibuka.
//
// URUTAN STARTUP:
//   1. main() dipanggil oleh sistem Android
//   2. WidgetsFlutterBinding.ensureInitialized() → siapkan Flutter
//   3. Inisialisasi Hive (database lokal)
//   4. Daftarkan adapter Hive untuk TransactionModel
//   5. Inisialisasi format lokal Indonesia (intl)
//   6. runApp(DompetKuApp()) → jalankan aplikasi!
//
// KENAPA ada await di main()?
//   Karena beberapa operasi (buka database, dll) butuh waktu.
//   "async/await" = tunggu sampai selesai sebelum lanjut.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dompetku/services/database_service.dart' as dompetku_db;
import 'models/transaction_model.dart';
import 'screens/permission_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_listener_service.dart';

// Fungsi main() HARUS ada — ini entry point Dart
// "async" karena kita butuh await untuk inisialisasi
void main() async {
  // WAJIB! Harus dipanggil sebelum kode async lainnya di main()
  // Memastikan binding Flutter sudah siap
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci orientasi ke portrait saja (tidak putar)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inisialisasi Hive di folder dokumen aplikasi
  // Hive.initFlutter() sudah otomatis pilih folder yang benar
  await Hive.initFlutter();

  // Daftarkan "adapter" — cara Hive tahu bagaimana
  // menyimpan dan membaca TransactionModel ke/dari disk
  // TransactionModelAdapter di-generate otomatis oleh build_runner
  Hive.registerAdapter(TransactionModelAdapter());

  // Inisialisasi format tanggal bahasa Indonesia
  // Agar "September" bisa muncul dalam Bahasa Indonesia
  await initializeDateFormatting('id_ID', null);

  // P1 HARDENING: Panggil pembersihan rawMessage pada saat startup
  try {
    await dompetku_db.DatabaseService.cleanupOldTransactions();
  } catch (e) {
    debugPrint('Cleanup failed: $e');
  }

  // Jalankan aplikasi!
  runApp(const DompetKuApp());
}

// ── ROOT WIDGET ───────────────────────────────────────────────
// DompetKuApp adalah "akar" dari semua widget di aplikasi ini.
// Semua widget lain ada di dalamnya.
class DompetKuApp extends StatefulWidget {
  const DompetKuApp({super.key});

  @override
  State<DompetKuApp> createState() => _DompetKuAppState();
}

class _DompetKuAppState extends State<DompetKuApp> {
  // Apakah izin notifikasi sudah dicek?
  bool _permissionChecked = false;
  // Apakah izin sudah diberikan?
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasPermission =
        await AppNotificationListenerService.hasPermission();
    setState(() {
      _hasPermission = hasPermission;
      _permissionChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Nama aplikasi (muncul di Recent Apps)
      title: 'DompetKu',

      // Sembunyikan banner "DEBUG" di pojok kanan atas
      debugShowCheckedModeBanner: false,

      // ── TEMA APLIKASI ──────────────────────────────────
      // Theme.of(context) di mana saja bisa ambil nilai ini
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          // Warna utama: teal (warna "uang")
          seedColor: const Color(0xFF00897B),
          brightness: Brightness.light,
        ),
        // Gunakan Material 3 (desain modern Google)
        useMaterial3: true,
        // Font utama seluruh aplikasi
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Colors.grey.shade900,
          ),
        ),
      ),

      // ── HALAMAN PERTAMA ────────────────────────────────
      home: !_permissionChecked
          // Masih mengecek izin: tampilkan loading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _hasPermission
              // Izin OK → langsung ke HomeScreen
              ? const HomeScreen()
              // Belum ada izin → tampilkan panduan dulu
              : const PermissionScreen(),
    );
  }
}
