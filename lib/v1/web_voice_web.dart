import 'dart:js_interop';

// Usa web/finki_voice.js (reconocimiento de voz de Chrome/Edge).
@JS('finkiVoice.supported')
external bool _supported();

@JS('finkiVoice.listen')
external JSPromise<JSString> _listen(JSFunction onPartial, JSFunction onReady);

@JS('finkiVoice.stop')
external void _stop();

@JS('finkiVoice.cancel')
external void _cancel();

bool webVoiceSupported() {
  try {
    return _supported();
  } catch (_) {
    return false;
  }
}

/// Devuelve "OK:texto" o "ERR:CODIGO".
Future<String> webVoiceListen(
    void Function(String) partial, void Function() ready) async {
  try {
    final result = await _listen(
      ((JSString text) => partial(text.toDart)).toJS,
      (() => ready()).toJS,
    ).toDart;
    return result.toDart;
  } catch (_) {
    return 'ERR:FAILED';
  }
}

void webVoiceStop() {
  try {
    _stop();
  } catch (_) {}
}

void webVoiceCancel() {
  try {
    _cancel();
  } catch (_) {}
}
