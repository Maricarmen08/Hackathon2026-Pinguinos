import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

Future<File> _file(String token) async {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
    throw const FormatException('Imagen local no válida.');
  }
  final root = Directory(
      '${(await getApplicationSupportDirectory()).path}/finki_evidence');
  await root.create(recursive: true);
  return File('${root.path}/$token');
}

Future<String> saveLocalMedia(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > 7 * 1024 * 1024) {
    throw const FormatException('Elige una foto de hasta 7 MB.');
  }
  final token = sha256.convert(bytes).toString(),
      file = await _file(sha256.convert(bytes).toString());
  if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
  return token;
}

Future<Uint8List> readLocalMedia(String token) async {
  final file = await _file(token);
  if (!await file.exists()) {
    throw const FormatException(
        'No se encontró la imagen guardada. Revisa el registro antes de sincronizar.');
  }
  if (await file.length() > 7 * 1024 * 1024) {
    throw const FormatException(
        'La imagen guardada no es válida. Revisa el registro.');
  }
  final bytes = await file.readAsBytes();
  if (sha256.convert(bytes).toString() != token) {
    throw const FormatException(
        'La imagen guardada cambió. Revisa el registro antes de sincronizar.');
  }
  return bytes;
}
