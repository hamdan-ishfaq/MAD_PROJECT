import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps the pedometer plugin with permission handling and daily persistence.
class StepCounterService {
  static int _steps = 0;
  static StreamSubscription<StepCount>? _subscription;
  static final ValueNotifier<int> stepsNotifier = ValueNotifier(0);

  static int get steps => _steps;

  /// Request ACTIVITY_RECOGNITION permission and start counting.
  /// Safe to call multiple times — will skip if already running.
  static Future<void> start() async {
    if (kIsWeb) return;
    if (_subscription != null) return; // Already started

    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) return;

    // Restore persisted baseline
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('step_date');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (savedDate != today) {
      // New day — reset baseline
      await prefs.setString('step_date', today);
      await prefs.setInt('step_baseline', -1); // -1 means not yet set
      await prefs.setInt('step_count', 0);
    }
    _steps = prefs.getInt('step_count') ?? 0;
    stepsNotifier.value = _steps;

    _subscription = Pedometer.stepCountStream.listen(
      (event) async {
        final prefs = await SharedPreferences.getInstance();
        final baseline = prefs.getInt('step_baseline') ?? -1;
        if (baseline < 0) {
          // First event of the day — record the hardware baseline
          await prefs.setInt('step_baseline', event.steps);
        }
        final base = prefs.getInt('step_baseline') ?? event.steps;
        _steps = event.steps - base;
        if (_steps < 0) _steps = 0;
        stepsNotifier.value = _steps;
        await prefs.setInt('step_count', _steps);
      },
      onError: (_) {}, // Gracefully handle unavailable sensor
    );
  }

  static void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Format step count as human-readable (e.g. 1200 → "1.2k")
  static String format(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
