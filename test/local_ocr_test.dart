import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_ocr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_text_recognizer');
  test('OCR usa el canal nativo y libera el reconocedor; no llama al backend',
      () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method.contains('start')
          ? {'text': 'TOTAL S/ 50.00', 'blocks': []}
          : null;
    });
    try {
      expect(await LocalOcr().read('/fixture.png'), 'TOTAL S/ 50.00');
      expect(calls.length, 2);
      expect(calls.last.toLowerCase(), contains('close'));
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
}
