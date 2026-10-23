import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_rules.dart';

// Exact engine outputs from the physical Android in airplane mode, 22/10/2026.
// These are parser regressions, not substitutes for live camera/microphone tests.
void main() {
  final rules = LocalRules();
  test('OCR físico une TOTAL y moneda: conserva total y no subtotal', () {
    final p = rules.interpret(
        'FINKI PRUEBA - SIN VALIDEZ\nBOLETA DE ENSAYO\nFecha: 22/10/2026\nConcepto: Arroz\nSUBTOTAL S/ 42.37\nIGV S/ 7.63\nTOTALS/ 50.00',
        source: 'IMAGEN');
    expect(p['monto_minor'], '5000');
    expect(p['fecha'], '2026-10-22');
    expect(p['concepto'], 'Arroz');
    expect(p['intencion'], 'DESCONOCIDO');
  });
  test('OCR físico recortado y borroso no inventa total', () {
    final p = rules.interpret(
        'FINKI PRUEBA - SIN VALIDEZ\nBOLETA DE ENSAYO\nFecha: 22/10/2026\nConcepto: Arroz\nSUBTOTAL S/ 42.37\nIGV S/ 7.63',
        source: 'IMAGEN');
    expect(p['monto_minor'], null);
    expect(rules.interpret('', source: 'IMAGEN')['monto_minor'], null);
  });
  test('transcripción física incorrecta no se convierte en gasto inventado',
      () {
    final p =
        rules.interpret('este veintitrés ofrecen en azúcar', source: 'VOZ');
    expect(p['intencion'], 'DESCONOCIDO');
    expect(p['monto_minor'], null);
  });
}
