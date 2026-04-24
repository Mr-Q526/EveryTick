import 'dart:js_interop';

@JS('navigator')
external _Navigator? get _navigator;

extension type _Navigator(JSObject _) implements JSObject {
  external JSAny? vibrate(JSAny durationOrPattern);
}

Future<void> vibratePattern(List<int> pattern) async {
  final totalDuration = pattern.fold<int>(0, (sum, item) => sum + item);
  if (totalDuration <= 0) {
    return;
  }

  try {
    _navigator?.vibrate(totalDuration.toJS);
  } catch (_) {
    // Ignore unsupported browsers and IABs.
  }
}
