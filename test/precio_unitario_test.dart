import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_rules.dart';

void main() {
  final rules = LocalRules();
  listaDeRenglones();

  // Un precio por unidad nunca debe guardarse como si fuera el total.
  for (final text in [
    'Vendí 3 gaseosas a 2 soles',
    'Vendí dos aceites a 24 soles',
    'Vendí 2 panes a 1 sol',
    'Vendí 3 gaseosas, 2 soles cada una',
  ]) {
    test('pide el total cuando hay cantidad y precio: $text', () {
      final p = rules.interpret(text);
      expect(p['intencion'], 'VENTA');
      expect(p['monto_minor'], isNull);
      expect(p['pregunta'], '¿Cuánto fue en total?');
    });
  }

  test('una sola unidad o un total claro no se bloquea', () {
    expect(rules.interpret('Vendí 1 aceite a 24 soles')['monto_minor'], '2400');
    expect(rules.interpret('Vendí 50 soles de arroz')['monto_minor'], '5000');
  });

  test('pagar la luz es un gasto', () {
    final p = rules.interpret('Pagué la luz 45 soles');
    expect(p['intencion'], 'GASTO_OPERATIVO');
    expect(p['monto_minor'], '4500');
  });

  test('"me debe" en una venta la marca como fiada', () {
    final p = rules.interpret('Vendí 30 soles de arroz y me debe');
    expect(p['intencion'], 'VENTA');
    expect(p['fiado'], true);
  });

  test('la pregunta de aclaración es fácil de entender', () {
    expect(rules.interpret('hola buenas')['pregunta'],
        '¿Fue una venta, un gasto o un cobro?');
    expect(rules.interpret('Me yapearon 20 soles')['pregunta'],
        '¿Fue una venta nueva o te pagaron una deuda?');
  });
}

void listaDeRenglones() {
  final rules = LocalRules();
  group('lista de renglones con importe', () {
    test('importe primero y verbo repetido: Vendí 50 soles de arroz, vendí 10 soles de aceite', () {
      final p = rules.interpret('Vendí 50 soles de arroz, vendí 10 soles de aceite');
      expect(p['intencion'], 'VENTA');
      expect(p['monto_minor'], '6000');
      expect(p['concepto'], 'Arroz · Aceite');
    });
    test('importe primero con pesos', () {
      final p = rules.interpret('Vendí 500 pesos de arroz, vendí 100 pesos de jamón');
      expect(p['monto_minor'], '60000');
      expect(p['concepto'], 'Arroz · Jamón');
    });
    test('dos operaciones distintas siguen pidiendo el total', () {
      final p = rules.interpret('Vendí 50 soles y gasté 20 soles');
      expect(p['monto_minor'], isNull);
    });
    for (final row in [
      ['comida para perro 10 soles, hueso de juguete 15 soles', 'TEXTO'],
      ['comida para perro 10 soles, hueso de juguete 15 soles', 'IMAGEN'],
      ['comida para perro diez soles hueso de juguete quince soles', 'VOZ'],
    ]) {
      test('suma los renglones y arma el concepto (${row[1]}): ${row[0]}', () {
        final p = rules.interpret(row[0], source: row[1]);
        expect(p['monto_minor'], '2500');
        expect(p['concepto'], 'Comida para perro · Hueso de juguete');
      });
    }

    test('dos operaciones distintas siguen pidiendo aclaración', () {
      final p = rules.interpret('Vendí 50 soles y gasté 20 soles');
      expect(p['monto_minor'], isNull);
      expect(parseMoneyList('Vendí 50 soles y gasté 20 soles'), isEmpty);
    });

    test('un solo importe no es una lista', () {
      expect(parseMoneyList('Gasté 23 soles en azúcar'), isEmpty);
    });
  });
}
