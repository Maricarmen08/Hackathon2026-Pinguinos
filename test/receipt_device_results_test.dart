import 'dart:convert';
import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_rules.dart';
import 'package:hackathon_pinguinos_mvp/v1/ocr_layout.dart';
import 'package:hackathon_pinguinos_mvp/v1/receipt_details.dart';

void main() {
  if (!const bool.fromEnvironment('CHECK_RECEIPT_DEVICE')) {
    test('OCR físico requiere reporte Android explícito', () {},
        skip:
            'Ejecutar test-receipt-ocr-android.ps1 y CHECK_RECEIPT_DEVICE=true');
    return;
  }
  final reports = jsonDecode(
          File('build/tooling/receipt-device-results.json').readAsStringSync())
      as List;
  final rules = LocalRules();
  Map<String, dynamic>? original;
  for (var i = 0; i < reports.length; i++) {
    final report = reports[i] as Map;
    test('ML Kit físico → parser: ${report['input']} #$i', () {
      expect(report['error'], null);
      expect(report['airplane_mode'], 1);
      final lines = (report['lines'] as List)
          .map((l) => OcrLine(
              l['text'] as String,
              Rect.fromLTRB(
                  (l['left'] as num).toDouble(),
                  (l['top'] as num).toDouble(),
                  (l['right'] as num).toDouble(),
                  (l['bottom'] as num).toDouble()),
              (l['angle'] as num).toDouble()))
          .toList();
      final ordered = orderOcrLines(lines, report['text'] as String);
      final p = rules.interpret(ordered, source: 'IMAGEN');
      final details = ReceiptDetails.parse(ordered);
      File('build/tooling/receipt-parsed-$i.json')
          .writeAsStringSync(jsonEncode({
        'input': report['input'],
        'ordered': ordered,
        'proposal': p,
        'merchant': details.merchant,
        'tax_id': details.taxId,
        'items': [
          for (final item in details.items)
            {'name': item.name, 'amount_minor': item.amountMinor}
        ]
      }));
      expect(p['intencion'], 'DESCONOCIDO');
      if (report['input'] == 'receipt-blurred.png' ||
          report['input'] == 'receipt-cropped.png') {
        expect(p['monto_minor'], null);
      } else {
        expect(p['monto_minor'], '2000', reason: ordered);
        expect(p['fecha'], '2026-10-23');
        expect(p['medio'], 'EFECTIVO');
        expect(details.taxId, '20123456789');
        expect(details.merchant, 'BODEGA PRUEBA');
        expect(
            details.items.map((p) => p.amountMinor).toList(), ['1200', '800'],
            reason: ordered);
        expect(details.items.first.name, matches(RegExp(r'ARR[O0]Z')));
        expect(details.items.last.name, 'AZUCAR');
      }
      if (report['input'] == 'receipt-source.png') {
        if (original == null) {
          original = p;
        } else {
          expect(p, original);
        }
      }
    });
  }
}
