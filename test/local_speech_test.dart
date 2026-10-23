import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_speech.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(LocalSpeech.channel, null));
  test('servicio ausente no promete voz offline', () async {
    expect((await LocalSpeech().capabilities())['onDevice'], false);
  });
  test('voz local devuelve transcripción editable y usa solo canal nativo',
      () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LocalSpeech.channel, (call) async {
      calls.add(call.method);
      return call.method == 'capabilities'
          ? {'onDevice': true, 'language': 'es-PE'}
          : call.method == 'listen'
              ? 'Vendí cincuenta soles de arroz'
              : null;
    });
    final voice = LocalSpeech();
    expect((await voice.capabilities())['language'], 'es-PE');
    expect(await voice.listen((_) {}), 'Vendí cincuenta soles de arroz');
    await voice.stop();
    await voice.cancel();
    expect(calls, ['capabilities', 'listen', 'stop', 'cancel']);
  });
  test('modelo incluido prepara Vosk y no necesita servicios de Google',
      () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LocalSpeech.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'prepare') {
        expect((call.arguments as Map)['preferNative'], false);
        return {'engine': 'vosk'};
      }
      return call.method == 'listen'
          ? 'gasté veintitrés soles en azúcar'
          : null;
    });
    final speech = LocalSpeech();
    await speech.prepare(preferNative: false);
    expect(speech.engine, 'vosk');
    expect(await speech.listen((_) {}), 'gasté veintitrés soles en azúcar');
    expect(calls, ['prepare', 'listen']);
  });
  test('idioma nativo ausente recurre solo a Vosk, no a Gemini', () async {
    var listens = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LocalSpeech.channel, (call) async {
      if (call.method == 'prepare') return {'engine': 'vosk'};
      if (call.method == 'listen') {
        if (++listens == 1) throw PlatformException(code: 'SPEECH_12');
        return 'vendí cincuenta soles';
      }
      return null;
    });
    final speech = LocalSpeech();
    expect(await speech.listen((_) {}), 'vendí cincuenta soles');
    expect(speech.engine, 'vosk');
    expect(listens, 2);
  });
  test('permiso denegado no inicia un segundo micrófono ni un proveedor',
      () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LocalSpeech.channel, (call) async {
      calls.add(call.method);
      throw PlatformException(code: 'PERMISSION_REQUIRED');
    });
    await expectLater(
        LocalSpeech().listen((_) {}), throwsA(isA<PlatformException>()));
    expect(calls, ['listen']);
  });
}
