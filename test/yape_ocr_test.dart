import 'dart:convert';
import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_rules.dart';
import 'package:hackathon_pinguinos_mvp/v1/ocr_layout.dart';

void main() {
  for (var i = 0; i < 2; i++) {
    test('Yape formato ${i == 0 ? 'ficticio' : 'habitual sintético'}: filas sintéticas y reglas',
        () {
      // Synthetic payment layouts; no personal screenshot or transaction. No network.
      final fixture =
          jsonDecode(File('test/fixtures/yape-ocr-$i.json').readAsStringSync())
              as Map;
      expect(fixture['synthetic'], true);
      final lines = (fixture['lines'] as List)
          .map((l) => OcrLine(
                l['text'] as String,
                Rect.fromLTRB(
                    (l['left'] as num).toDouble(),
                    (l['top'] as num).toDouble(),
                    (l['right'] as num).toDouble(),
                    (l['bottom'] as num).toDouble()),
                (l['angle'] as num).toDouble(),
              ))
          .toList();
      final text = orderOcrLines(lines, fixture['text'] as String);
      final p = LocalRules().interpret(text, source: 'IMAGEN');
      expect(p['monto_minor'], i == 0 ? '3500' : '1700', reason: text);
      expect(p['medio'], 'YAPE', reason: text);
      expect(p['referencia'], i == 0 ? '00458291' : '00000042', reason: text);
      expect(p['fecha'], i == 0 ? '2026-10-23' : '2026-01-15');
      expect(p['intencion'], 'DESCONOCIDO');
      expect(p['es_pago'], true);
    });
  }
  test('medio explícito, ambigüedad y referencia sin inventar', () {
    final rules = LocalRules();
    for (final marker in ['N°', 'Nº', 'Nro.', 'Número']) {
      final p = rules.interpret(
          'Transferencia exitosa\nS/35.00\nDesde tu saldo Yape\nN° de operación $marker 00458291',
          source: 'IMAGEN');
      expect(p['medio'], 'YAPE');
      expect(p['referencia'], '00458291');
    }
    expect(rules.interpret('Transferencia S/35', source: 'IMAGEN')['medio'],
        'TRANSFERENCIA');
    expect(rules.interpret('Yape Plin S/35', source: 'IMAGEN')['medio'], null);
    expect(
        rules.interpret('Yape S/35\nCódigo de seguridad 000',
            source: 'IMAGEN')['referencia'],
        null);
    expect(
        rules.interpret('Yape S/35\nN° de operación N°',
            source: 'IMAGEN')['referencia'],
        null);
  });
}
