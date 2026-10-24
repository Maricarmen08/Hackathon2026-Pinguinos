import 'dart:js_interop';
import 'dart:typed_data';

// Usa web/finki_ocr.js (Tesseract.js servido desde este mismo sitio).
@JS('finkiOcr.supported')
external bool _supported();

@JS('finkiOcr.read')
external JSPromise<JSString> _read(JSUint8Array bytes);

bool webOcrSupported() {
  try {
    return _supported();
  } catch (_) {
    return false;
  }
}

/// Texto leído de la imagen, o cadena vacía si no se pudo leer.
Future<String> webOcrRead(Uint8List bytes) async {
  try {
    final result = (await _read(bytes.toJS).toDart).toDart;
    return result.startsWith('OK:') ? result.substring(3) : '';
  } catch (_) {
    return '';
  }
}
