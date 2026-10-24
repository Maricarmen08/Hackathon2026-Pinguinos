import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'web_voice.dart';

/// Native on-device recognition or bundled Vosk. No cloud fallback.
/// En la web usa el reconocimiento de voz del navegador (Chrome/Edge).
class LocalSpeech {
  static const channel = MethodChannel('finki/local_speech');
  String _engine = 'native';
  String get engine => _engine;
  Future<Map<String, dynamic>> capabilities() async {
    if (kIsWeb) {
      return webVoiceSupported()
          ? {'onDevice': true, 'spanishInstalled': true, 'offlineModel': false}
          : {'onDevice': false};
    }
    try {
      return Map<String, dynamic>.from(
          await channel.invokeMapMethod<String, dynamic>('capabilities') ?? {});
    } on MissingPluginException {
      return {'onDevice': false};
    } on PlatformException {
      return {'onDevice': false};
    }
  }

  Future<void> prepare({required bool preferNative}) async {
    if (kIsWeb) {
      if (!webVoiceSupported()) {
        throw PlatformException(code: 'OFFLINE_MODEL_UNAVAILABLE');
      }
      _engine = 'native';
      return;
    }
    final prepared = await channel.invokeMapMethod<String, dynamic>(
        'prepare', {'preferNative': preferNative});
    final selected = prepared?['engine'];
    if (selected != 'native' && selected != 'vosk') {
      throw PlatformException(code: 'OFFLINE_MODEL_UNAVAILABLE');
    }
    _engine = selected as String;
  }

  Future<String> listen(void Function(String) partial,
      {void Function()? onReady, void Function()? onProcessing}) async {
    if (kIsWeb) {
      final raw = await webVoiceListen(partial, () => onReady?.call());
      if (raw.startsWith('OK:')) return raw.substring(3);
      throw PlatformException(
          code: raw.startsWith('ERR:') ? raw.substring(4) : 'FAILED');
    }
    channel.setMethodCallHandler((call) async {
      if (call.method == 'partial' && call.arguments is String) {
        partial(call.arguments as String);
      }
      if (call.method == 'ready') onReady?.call();
      if (call.method == 'processing') onProcessing?.call();
    });
    try {
      try {
        return await channel.invokeMethod<String>('listen') ?? '';
      } on PlatformException catch (e) {
        if (_engine != 'native' ||
            !['UNAVAILABLE', 'SPEECH_12', 'SPEECH_13'].contains(e.code)) {
          rethrow;
        }
        await prepare(preferNative: false);
        return await channel.invokeMethod<String>('listen') ?? '';
      }
    } finally {
      channel.setMethodCallHandler(null);
    }
  }

  Future<void> stop() async {
    if (kIsWeb) {
      webVoiceStop();
      return;
    }
    await channel.invokeMethod<void>('stop');
  }

  Future<void> cancel() async {
    if (kIsWeb) {
      webVoiceCancel();
      return;
    }
    try {
      await channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // Unsupported platforms still support manual entry and the existing flow.
    } on PlatformException {
      // Activity shutdown must not leave an unhandled platform error.
    }
  }
}
