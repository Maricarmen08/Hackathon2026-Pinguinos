import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_rules.dart';

void main() {
  final rules = LocalRules();
  for (final row in [
    ['Gasté 23 soles en azúcar.', 'GASTO_OPERATIVO', '2300', 'azucar.'],
    ['Vendí 50 soles de arroz', 'VENTA', '5000', 'arroz'],
    ['Gasté 20 soles en luz', 'GASTO_OPERATIVO', '2000', 'luz'],
    [
      'Compré mercadería por 100 soles',
      'COMPRA_MERCADERIA',
      '10000',
      'Mercadería'
    ],
    ['Le fié 30 soles a Juan', 'VENTA', '3000', 'Fiado a Juan'],
    ['Juan me abonó 15 soles', 'COBRO', '1500', 'Abono de Juan'],
    ['Pagué 40 soles de deuda', 'PAGO', '4000', 'deuda'],
    ['Hoy vendí cincuenta soles de arroz', 'VENTA', '5000', 'arroz'],
    [
      'Gasté treinta y cinco soles con veinte céntimos en luz',
      'GASTO_OPERATIVO',
      '3520',
      null
    ],
  ]) {
    test('regla local: ${row[0]}', () {
      final p = rules.interpret(row[0]!);
      expect(p['intencion'], row[1]);
      expect(p['monto_minor'], row[2]);
      if (row[3] != null) expect(p['concepto'], row[3]);
    });
  }
  for (final row in [
    ['Gasté 23 soles en azúcar.', 'GASTO_OPERATIVO', '2300'],
    ['Vendí 50 soles de arroz', 'VENTA', '5000'],
    ['Compré mercadería por 100 soles', 'COMPRA_MERCADERIA', '10000'],
  ]) {
    test('audio alternativo reinterpreta localmente: ${row[0]}', () {
      final remote = {
        ...rules.interpret(row[0]),
        'intencion': 'DESCONOCIDO',
        'es_pago': true,
        'pregunta': '¿Fue una venta nueva, abono, pago o traslado?',
      };
      final result = rules.reconcileVoice(row[0], remote);
      expect(result['intencion'], row[1]);
      expect(result['monto_minor'], row[2]);
      expect(result['es_pago'], false);
      expect(result['pregunta'], null);
      expect(result['concepto'], remote['concepto']);
      expect(result['texto_visible'], remote['texto_visible']);
      expect(remote['intencion'], 'DESCONOCIDO');
    });
  }
  test('voz ambigua o importe discrepante conserva revisión sin forzar tipo',
      () {
    final remote = {
      ...rules.interpret('Yape 23 soles', source: 'IMAGEN'),
      'es_pago': true,
    };
    expect(rules.reconcileVoice('Recibí 23 soles', remote), same(remote));
    expect(
        rules.reconcileVoice('Gasté 24 soles en azúcar', remote), same(remote));
    expect(
        rules.interpret('Gasté 23 soles en azúcar',
            source: 'IMAGEN')['intencion'],
        'DESCONOCIDO');
  });
  test(
      'no inventa medio, fecha ni persona; importes ambiguos requieren revisión',
      () {
    final p = rules.interpret('Vendí 50 soles de arroz');
    expect(p['medio'], null);
    expect(p['fecha'], null);
    expect(p['persona'], null);
    expect(rules.interpret('Vendí 50 soles y gasté 20 soles')['monto_minor'],
        null);
    expect(rules.interpret('No vendí 50 soles')['intencion'], 'DESCONOCIDO');
    expect(rules.interpret('Vendi 2 arroz')['monto_minor'], null);
    expect(rules.interpret('Vendí -50 soles')['monto_minor'], null);
    expect(rules.interpret('Vendí cincuenta con veinte soles')['monto_minor'],
        '5020');
    expect(rules.interpret('Vendí 50 con 20 soles')['monto_minor'], '5020');
    expect(rules.interpret('Vendí S/ 1 500.50')['monto_minor'], '150050');
    expect(rules.interpret('Vendí 1 500.50 soles')['monto_minor'], '150050');
    expect(
        rules.interpret('Vendí 50 soles por Yape y Plin en efectivo')['medio'],
        null);
    expect(
        rules.interpret('Hoy vendí diez soles', today: '2026-10-22')['fecha'],
        '2026-10-22');
  });
  test(
      'boleta: total separado de subtotal; Yape/Plin nunca es venta automática',
      () {
    final receipt = rules.interpret(
        'BOLETA\nSUBTOTAL 42.37\nIGV 7.63\nTOTAL S/ 50.00\n22/10/2026',
        source: 'IMAGEN');
    expect(receipt['monto_minor'], '5000');
    expect(receipt['intencion'], 'DESCONOCIDO');
    for (final brand in ['Yape', 'Plin', 'Transferencia']) {
      final p = rules.interpret('$brand\nS/ 40.00\nReferencia: 0012345',
          source: 'IMAGEN');
      expect(p['es_pago'], true);
      expect(p['intencion'], 'DESCONOCIDO');
      expect(p['referencia'], '0012345');
    }
  });
}
