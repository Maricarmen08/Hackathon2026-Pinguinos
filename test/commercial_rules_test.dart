import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_rules.dart';

void main() {
  final rules = LocalRules();
  for (final row in [
    ('Vendí 50 soles de arroz', 'VENTA', '5000'),
    ('Gasté 23 soles en azúcar', 'GASTO_OPERATIVO', '2300'),
    ('Compré 100 soles de mercadería', 'COMPRA_MERCADERIA', '10000'),
    ('Le fié 30 soles a Juan', 'VENTA', '3000'),
    ('Juan me abonó 15 soles', 'COBRO', '1500'),
    ('Pagué 40 soles a mi proveedor', 'PAGO', '4000'),
    ('vendi cincuenta soles de arroz', 'VENTA', '5000'),
    ('gasté diez soles en azúcar', 'GASTO_OPERATIVO', '1000'),
    ('gasté veinte soles en azúcar', 'GASTO_OPERATIVO', '2000'),
    ('compré ochenta soles de mercadería', 'COMPRA_MERCADERIA', '8000'),
    ('gaste veinti tres soles en azucar', 'GASTO_OPERATIVO', '2300'),
    ('gasté veinte y tres soles en azúcar', 'GASTO_OPERATIVO', '2300'),
    ('compre cien soles de mercaderia', 'COMPRA_MERCADERIA', '10000'),
    ('le fie treinta soles a juan', 'VENTA', '3000'),
    ('juan me abono quince soles', 'COBRO', '1500'),
    ('pague cuarenta soles a mi proveedor', 'PAGO', '4000'),
  ]) {
    test('voz comercial: ${row.$1}', () {
      final p = rules.interpret(row.$1, source: 'VOZ');
      expect(p['intencion'], row.$2);
      expect(p['monto_minor'], row.$3);
      expect(p['medio'], null);
      expect(p['fecha'], null);
      if (p['persona'] != null) expect(p['persona'], 'Juan');
      if (row.$1.contains('fié') || row.$1.contains('fie')) {
        expect(p['fiado'], true);
      }
    });
  }
  test('no convierte un error de transcripción en un importe o verbo inventado',
      () {
    for (final text in [
      'Gasté doscientos y 3 soles',
      'Gasté cien 20 soles',
      'Vendí un millón veinte soles'
    ]) {
      expect(rules.interpret(text)['monto_minor'], null, reason: text);
    }
    expect(rules.interpret('Casté 23 soles en azúcar')['intencion'],
        'DESCONOCIDO');
    expect(rules.interpret('vendí se encuentra suele de arroz')['monto_minor'],
        null);
    expect(rules.interpret('Vendí 50 soles o gasté 23 soles')['intencion'],
        'DESCONOCIDO');
    expect(rules.interpret('Gaste\u0301 23 soles')['intencion'],
        'GASTO_OPERATIVO');
  });
  test('boleta y ticket conservan solo las etiquetas explícitas legibles', () {
    final p = rules.interpret(
        'BOLETA FINKI PRUEBA\nSubtotal 42.37\nIGV 7.63\nTOTAL S/ 50.00\nFecha 2026-10-22\nConcepto: Arroz',
        source: 'IMAGEN');
    expect(p['monto_minor'], '5000');
    expect(p['fecha'], '2026-10-22');
    expect(p['concepto'], 'Arroz');
    expect(p['intencion'], 'DESCONOCIDO');
    final partial = rules.interpret('TICKET RECORTADO\nConcepto: Arroz\nTOT...',
        source: 'IMAGEN');
    expect(partial['monto_minor'], null);
    expect(
        rules.interpret('BOLETA RECORTADA\nSUBTOTAL S/ 42.37\nIGV S/ 7.63',
            source: 'IMAGEN')['monto_minor'],
        null);
    expect(partial['intencion'], 'DESCONOCIDO');
    expect(rules.interpret('imagen borrosa', source: 'IMAGEN')['monto_minor'],
        null);
  });
  for (final brand in ['Yape', 'Plin']) {
    test('$brand requiere propósito, conserva fecha y referencia explícitas',
        () {
      final text =
          '$brand\nS/ 40.00\n22 oct. 2026\nN° de operación: 0012345\nConcepto: Abono';
      final p = rules.interpret(text, source: 'IMAGEN');
      expect(p['intencion'], 'DESCONOCIDO');
      expect(p['es_pago'], true);
      expect(p['monto_minor'], '4000');
      expect(p['fecha'], '2026-10-22');
      expect(p['referencia'], '0012345');
      expect(p['concepto'], 'Abono');
      expect(rules.interpret(text, source: 'IMAGEN'), p);
    });
  }
  test('fechas contradictorias o inválidas no se sustituyen por hoy', () {
    expect(
        rules.interpret(
            'Hoy vendí 50 soles, del 22/10/2026 al 23/10/2026')['fecha'],
        null);
    expect(rules.interpret('Vendí 50 soles el 31 de febrero de 2026')['fecha'],
        null);
    expect(rules.interpret('Hoy o ayer vendí 50 soles')['fecha'], null);
  });
}
