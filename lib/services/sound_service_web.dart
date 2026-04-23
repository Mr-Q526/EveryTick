// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';

// ── Web Audio API bindings ──────────────────────────────────────────────────

@JS('AudioContext')
extension type _Ctx._(JSObject _) implements JSObject {
  external factory _Ctx();
  external JSNumber get currentTime;
  external JSObject get destination;
  external _Osc createOscillator();
  external _Gain createGain();
}

extension type _Osc._(JSObject _) implements JSObject {
  external set type(JSString t);
  external _Param get frequency;
  external void connect(JSObject dest);
  external void start(JSNumber when);
  external void stop(JSNumber when);
}

extension type _Gain._(JSObject _) implements JSObject {
  external _Param get gain;
  external void connect(JSObject dest);
}

extension type _Param._(JSObject _) implements JSObject {
  external void setValueAtTime(JSNumber v, JSNumber t);
  external void exponentialRampToValueAtTime(JSNumber v, JSNumber t);
  external void linearRampToValueAtTime(JSNumber v, JSNumber t);
}

// Singleton context — browsers cap the number of AudioContexts.
_Ctx? _ctx;
_Ctx _audioCtx() => _ctx ??= _Ctx();

// ── Synthesized sounds ──────────────────────────────────────────────────────

void _chime() {
  final ctx = _audioCtx();
  final t = ctx.currentTime.toDartDouble;
  final dest = ctx.destination;
  void tone(double freq, double at, double dur) {
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();
    osc.type = 'sine'.toJS;
    osc.frequency.setValueAtTime(freq.toJS, at.toJS);
    gain.gain.setValueAtTime(0.32.toJS, at.toJS);
    gain.gain.exponentialRampToValueAtTime(0.001.toJS, (at + dur).toJS);
    osc.connect(gain as JSObject);
    gain.connect(dest);
    osc.start(at.toJS);
    osc.stop((at + dur + 0.05).toJS);
  }
  tone(880, t, 0.50);
  tone(1108, t + 0.07, 0.44);
  tone(1320, t + 0.14, 0.38);
}

void _swoosh() {
  final ctx = _audioCtx();
  final t = ctx.currentTime.toDartDouble;
  final dest = ctx.destination;
  final osc = ctx.createOscillator();
  final gain = ctx.createGain();
  osc.type = 'sawtooth'.toJS;
  osc.frequency.setValueAtTime(680.toJS, t.toJS);
  osc.frequency.exponentialRampToValueAtTime(48.toJS, (t + 0.40).toJS);
  gain.gain.setValueAtTime(0.001.toJS, t.toJS);
  gain.gain.linearRampToValueAtTime(0.24.toJS, (t + 0.06).toJS);
  gain.gain.exponentialRampToValueAtTime(0.001.toJS, (t + 0.44).toJS);
  osc.connect(gain as JSObject);
  gain.connect(dest);
  osc.start(t.toJS);
  osc.stop((t + 0.50).toJS);
}

void _coin() {
  final ctx = _audioCtx();
  final t = ctx.currentTime.toDartDouble;
  final dest = ctx.destination;
  void hit(double freq, double at, double dur) {
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();
    osc.type = 'sine'.toJS;
    osc.frequency.setValueAtTime(freq.toJS, at.toJS);
    gain.gain.setValueAtTime(0.38.toJS, at.toJS);
    gain.gain.exponentialRampToValueAtTime(0.001.toJS, (at + dur).toJS);
    osc.connect(gain as JSObject);
    gain.connect(dest);
    osc.start(at.toJS);
    osc.stop((at + dur + 0.05).toJS);
  }
  hit(988, t, 0.12);
  hit(1319, t + 0.09, 0.20);
}

// ── Public: synthesized sounds ──────────────────────────────────────────────

Future<void> playWebSound(String type) async {
  try {
    switch (type) {
      case 'chime': _chime();
      case 'swoosh': _swoosh();
      case 'coin': _coin();
    }
  } catch (_) {}
}

// ── Public: local audio file ────────────────────────────────────────────────

/// Opens the native file picker and returns (filename, blobUrl).
/// Returns null if the user cancels.
Future<(String name, String url)?> pickLocalAudio() async {
  final completer = Completer<(String, String)?>();

  final input = html.FileUploadInputElement()..accept = 'audio/*';

  late html.EventListener onChangeFn;
  onChangeFn = (_) {
    input.removeEventListener('change', onChangeFn);
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      completer.complete(null);
    } else {
      final url = html.Url.createObjectUrlFromBlob(file);
      completer.complete((file.name, url));
    }
    input.remove();
  };
  input.addEventListener('change', onChangeFn);

  // Auto-cancel after 5 min to avoid leaking the completer.
  Future.delayed(const Duration(minutes: 5), () {
    if (!completer.isCompleted) completer.complete(null);
  });

  html.document.body?.append(input);
  input.click();
  return completer.future;
}

/// Plays an audio file at [url] (blob URL or HTTP URL).
Future<void> playLocalAudio(String url) async {
  try {
    final audio = html.AudioElement()..src = url;
    await audio.play();
  } catch (_) {}
}
