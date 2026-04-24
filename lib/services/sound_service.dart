import 'package:shared_preferences/shared_preferences.dart';

import 'sound_service_stub.dart'
    if (dart.library.html) 'sound_service_web.dart' as platform;

enum CheckInSound {
  none('none', '静音'),
  chime('chime', '叮 · 钟声'),
  swoosh('swoosh', '嗖 · 旋风'),
  coin('coin', '叮当 · 金币');

  final String key;
  final String label;
  const CheckInSound(this.key, this.label);

  static CheckInSound fromKey(String k) => CheckInSound.values.firstWhere(
    (s) => s.key == k,
    orElse: () => CheckInSound.chime,
  );
}

class SoundService {
  static const _prefix = '@everytick_sound/';

  // ── Per-event synthesized sound ─────────────────────────────────────────

  static Future<CheckInSound> loadEventSound(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final k = prefs.getString('$_prefix$eventId');
    return k == null ? CheckInSound.chime : CheckInSound.fromKey(k);
  }

  static Future<void> saveEventSound(
    String eventId,
    CheckInSound sound,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$eventId', sound.key);
  }

  static Future<void> play(CheckInSound sound) async {
    if (sound == CheckInSound.none) return;
    await platform.playWebSound(sound.key);
  }

  // ── Local audio file (session-lifetime blob URL) ─────────────────────────

  static Future<(String name, String url)?> pickLocalAudio() =>
      platform.pickLocalAudio();

  static Future<void> playLocalAudio(String url) =>
      platform.playLocalAudio(url);

  // ── Session-level local audio store (cleared on page refresh) ────────────
  // Shared between HomeScreen and EditEventScreen without a provider.

  static final Map<String, (String name, String url)> _localAudio = {};

  static (String name, String url)? getLocalAudio(String eventId) =>
      _localAudio[eventId];

  static void setLocalAudio(String eventId, String name, String url) =>
      _localAudio[eventId] = (name, url);

  static void clearLocalAudio(String eventId) => _localAudio.remove(eventId);
}
