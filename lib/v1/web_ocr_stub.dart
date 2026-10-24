import 'dart:typed_data';

// Fuera del navegador la lectura de fotos la hace el celular (local_ocr.dart).
bool webOcrSupported() => false;

Future<String> webOcrRead(Uint8List bytes) async => '';
