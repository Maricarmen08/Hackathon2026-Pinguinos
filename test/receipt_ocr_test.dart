import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/ocr_layout.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_rules.dart';
import 'package:hackathon_pinguinos_mvp/v1/receipt_details.dart';

void main() {
  final rows = [
    const OcrLine('BODEGA PRUEBA', Rect.fromLTWH(30, 0, 200, 30)),
    const OcrLine('BOLETA DE VENTA', Rect.fromLTWH(30, 50, 200, 30)),
    const OcrLine('RUC: 20123456789', Rect.fromLTWH(30, 100, 200, 30)),
    const OcrLine('Fecha: 23/10/2026', Rect.fromLTWH(30, 150, 200, 30)),
    const OcrLine('1 ARROZ', Rect.fromLTWH(30, 200, 180, 30)),
    const OcrLine('1 AZUCAR', Rect.fromLTWH(30, 250, 180, 30)),
    const OcrLine('SUBTOTAL', Rect.fromLTWH(30, 300, 180, 30)),
    const OcrLine('TOTAL', Rect.fromLTWH(30, 350, 180, 30)),
    const OcrLine('MEDIO DE PAGO: EFECTIVO', Rect.fromLTWH(30, 400, 400, 30)),
    const OcrLine('S/ 12.00', Rect.fromLTWH(400, 210, 100, 30)),
    const OcrLine('S/ 8.00', Rect.fromLTWH(400, 260, 100, 30)),
    const OcrLine('S/ 20.00', Rect.fromLTWH(400, 310, 100, 30)),
    const OcrLine('S/ 20.00', Rect.fromLTWH(400, 360, 100, 30)),
  ];
  test('columnas OCR se reconstruyen por posición y no por orden de bloques',
      () {
    final text = orderOcrLines(rows, 'raw');
    expect(text, contains('TOTAL S/ 20.00'));
    final p = LocalRules().interpret(text, source: 'IMAGEN');
    final receipt = ReceiptDetails.parse(text);
    expect(p['monto_minor'], '2000');
    expect(p['concepto'], 'ARROZ · AZUCAR');
    expect(p['fecha'], '2026-10-23');
    expect(p['medio'], 'EFECTIVO');
    expect(p['intencion'], 'DESCONOCIDO');
    expect(p['referencia'], null);
    expect(receipt.merchant, 'BODEGA PRUEBA');
    expect(receipt.taxId, '20123456789');
    expect(receipt.items.map((i) => i.amountMinor), ['1200', '800']);
  });
  test(
      'total explícito gana a importe parcial y subtotal; conflictos no se resuelven inventando',
      () {
    final rules = LocalRules();
    expect(
        rules.interpret(
            'BOLETA\nSUBTOTAL S/ 18.00\nIMPORTE S/12.00\nTOTAL: S / 20.00',
            source: 'IMAGEN')['monto_minor'],
        '2000');
    expect(
        rules.interpret('BOLETA\nTOTAL S/20.00\nTOTAL S/30.00',
            source: 'IMAGEN')['monto_minor'],
        null);
    expect(
        rules.interpret(
            'BOLETA\nRUC:20123456789\nFecha:23/10/2026\n1 ARROZ S/12.00\nSUBTOTAL S/20.00',
            source: 'IMAGEN')['monto_minor'],
        null);
    expect(rules.interpret('', source: 'IMAGEN')['monto_minor'], null);
  });
  test(
      'líneas sin geometría mantienen todo el texto y no mezclan filas apiladas',
      () {
    expect(orderOcrLines([], 'texto completo'), 'texto completo');
    expect(
        orderOcrLines([
          const OcrLine('SUBTOTAL', Rect.fromLTWH(0, 0, 100, 20)),
          const OcrLine('TOTAL', Rect.fromLTWH(0, 15, 100, 20)),
        ], ''),
        'SUBTOTAL\nTOTAL');
  });
}
