import 'package:flutter_test/flutter_test.dart';
import 'package:dompetku/services/battery_optimization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BatteryOptimizationService Tests', () {
    test('gracefully handles non-Android test environment', () async {
      final isIgnoring =
          await BatteryOptimizationService.isIgnoringBatteryOptimizations();
      expect(isIgnoring, isTrue);

      final requested =
          await BatteryOptimizationService.requestIgnoreBatteryOptimizations();
      expect(requested, isTrue);

      final openedAutostart =
          await BatteryOptimizationService.openAutostartSettings();
      expect(openedAutostart, isTrue);
    });
  });
}
