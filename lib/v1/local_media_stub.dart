import 'dart:typed_data';

Future<String> saveLocalMedia(Uint8List bytes) async =>
    throw const FormatException(
        'Conservar una imagen sin conexión requiere Android.');
Future<Uint8List> readLocalMedia(String token) async =>
    throw const FormatException(
        'Esta imagen necesita el celular donde se guardó.');
