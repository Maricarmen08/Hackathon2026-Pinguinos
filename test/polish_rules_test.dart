import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_rules.dart';

void main() {
  final rules = LocalRules();
  for (final row in [
    ('Compré mercadería por 80', 'COMPRA_MERCADERIA', '8000'),
    ('Compré mercadería por ochenta', 'COMPRA_MERCADERIA', '8000'),
    ('Dejé fiado 20 de pan', 'VENTA', '2000'),
    ('Dejé fiado veinte de pan', 'VENTA', '2000'),
    ('Me abonaron 15', 'COBRO', '1500'),
    ('Me abonaron quince', 'COBRO', '1500'),
  ]) {
    test('contexto comercial explícito: ${row.$1}', () {
      final p = rules.interpret(row.$1, source: 'VOZ');
      expect(p['intencion'], row.$2);
      expect(p['monto_minor'], row.$3);
      expect(p['medio'], null);
      expect(p['fecha'], null);
      expect(p['persona'], null);
      if (row.$1.startsWith('Dejé fiado')) {
        expect(p['concepto'], 'pan');
        expect(p['fiado'], true);
      }
    });
  }
  test('verbo perdido conserva azúcar y monto pero pide tipo', () {
    final p = rules.interpret('veintitrés soles son azúcar', source: 'VOZ');
    expect(p['monto_minor'], '2300');
    expect(p['concepto'], 'azucar');
    expect(p['intencion'], 'DESCONOCIDO');
    expect(p['pregunta'], isNotNull);
  });
  test('cantidades de productos y varios números no se convierten en dinero',
      () {
    expect(rules.interpret('Vendí 3 panes')['monto_minor'], null);
    expect(rules.interpret('Compré 3 productos por 80')['monto_minor'], null);
    expect(rules.interpret('20 de pan')['intencion'], 'DESCONOCIDO');
  });
}
