// ============================================================
// FILE: battery_optimization_service.dart
//
// TUJUAN: Menjaga DompetKu tetap hidup 24/7 di Android OS.
//
// Mengakses Android PowerManager & Settings melalui MethodChannel
// agar terbebas dari Doze Mode (Deep Sleep) dan pembatasan baterai vendor
// seperti Xiaomi MIUI / HyperOS, Oppo ColorOS, dan Samsung OneUI.
// ============================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static const MethodChannel _channel =
      MethodChannel('com.belajarflutter.dompetku/battery_optimization');

  /// Cek apakah aplikasi sudah bebas dari batasan baterai (Doze Mode whitelist).
  /// Bernilai `true` jika bebas optimasi baterai, atau jika berjalan di non-Android (misal unit test).
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final isIgnoring =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return isIgnoring ?? false;
    } catch (e) {
      debugPrint('[DompetKu] Error checking battery optimizations: $e');
      return false;
    }
  }

  /// Memunculkan dialog native Android untuk meminta izin "Bebaskan dari Hemat Baterai".
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final success =
          await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return success ?? false;
    } catch (e) {
      debugPrint('[DompetKu] Error requesting ignore battery optimizations: $e');
      return false;
    }
  }

  /// Membuka menu pengaturan Autostart (khusus Xiaomi / HyperOS / MIUI atau App Details fallback).
  static Future<bool> openAutostartSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      final success =
          await _channel.invokeMethod<bool>('openAutostartSettings');
      return success ?? false;
    } catch (e) {
      debugPrint('[DompetKu] Error opening autostart settings: $e');
      return false;
    }
  }
}
