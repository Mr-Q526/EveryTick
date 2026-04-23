import 'package:flutter/services.dart';

import 'haptic_service_stub.dart'
    if (dart.library.html) 'haptic_service_web.dart' as web_haptics;

class HapticService {
  static Future<void> checkInTap() async {
    await Future.wait([
      HapticFeedback.selectionClick(),
      web_haptics.vibratePattern(const [10]),
    ]);
  }

  static Future<void> celebrateCheckIn() async {
    await Future.wait([
      HapticFeedback.heavyImpact(),
      web_haptics.vibratePattern(const [18, 28, 48]),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.mediumImpact();
  }

  static Future<void> recordSaved() async {
    await Future.wait([
      HapticFeedback.mediumImpact(),
      web_haptics.vibratePattern(const [16, 18, 34]),
    ]);
  }
}
