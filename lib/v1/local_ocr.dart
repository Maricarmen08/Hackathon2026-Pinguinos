import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ocr_layout.dart';

class LocalOcrResult {
  final String rawText, text;
  const LocalOcrResult(this.rawText, this.text);
}

class LocalOcr {
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<String> read(String path) async => (await readDetailed(path)).text;
  Future<LocalOcrResult> readDetailed(String path) async {
    if (!supported) {
      throw const FormatException(
          'La lectura en el celular está disponible en Android. Puedes escribir el texto.');
    }
    final reader = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await reader.processImage(InputImage.fromFilePath(path));
      final lines = [
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(line.text, line.boundingBox, line.angle ?? 0)
      ];
      return LocalOcrResult(result.text, orderOcrLines(lines, result.text));
    } finally {
      await reader.close();
    }
  }
}
