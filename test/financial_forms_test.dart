import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/forms.dart';
import 'widget_test.dart' show MemoryStore, session, json;

void main() {
  for (final kind in ['VENTA', 'COMPRA_MERCADERIA', 'GASTO_OPERATIVO']) {
    testWidgets('$kind usa General sin elegir la primera categoría específica',
        (tester) async {
      Json? sent;
      final api = ApiClient(
          store: MemoryStore(),
          client: MockClient((r) async {
            sent = jsonDecode(r.body) as Json;
            return json({'replayed': false}, 201);
          }))
        ..session = session();
      await tester.pumpWidget(MaterialApp(
          home: EntryForm(api: api, kind: kind, business: const {
        'id': 'b'
      }, accounts: const [
        {'id': 'cash', 'nombre': 'Caja'}
      ], categories: [
        {'id': 'specific', 'nombre': 'Específica', 'tipo': kind}
      ], people: const [])));
      await tester.enterText(find.byType(TextFormField).at(0), 'Prueba');
      await tester.enterText(find.byType(TextFormField).at(1), '12');
      await tester.scrollUntilVisible(find.text('General'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Categoría'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Revisar y guardar'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisar y guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(sent?['payload']['operacion']['categoria_id'], isNull);
      expect(sent?['payload']['operacion'].containsKey('tercero_id'), false);
      expect(sent?['payload']['operacion']['condicion'], 'CONTADO');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'gasto pendiente exige proveedor; pago completo elimina el requisito',
      (tester) async {
    Json? sent;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          sent = jsonDecode(r.body) as Json;
          return json({'replayed': false}, 201);
        }))
      ..session = session();
    await tester.pumpWidget(MaterialApp(
        home: EntryForm(api: api, kind: 'GASTO_OPERATIVO', row: const {
      'initial_mode': 'CREDITO'
    }, business: const {
      'id': 'b'
    }, accounts: const [
      {'id': 'cash', 'nombre': 'Caja'}
    ], categories: const [], people: const [])));
    expect(find.text('¿En qué gastaste?'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Luz');
    await tester.enterText(find.byType(TextFormField).at(1), '12');
    await tester.scrollUntilVisible(find.text('Revisar y guardar'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Revisar y guardar'));
    await tester.pumpAndSettle();
    expect(sent, isNull);
    await tester.scrollUntilVisible(
        find.text('Elige un proveedor para registrar lo que queda por pagar.'),
        -150,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.text('Elige un proveedor para registrar lo que queda por pagar.'),
        findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pendiente · sin pago'), -150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Pendiente · sin pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pago completo').last);
    await tester.pumpAndSettle();
    expect(find.text('Proveedor'), findsNothing);
    await tester.scrollUntilVisible(find.text('Revisar y guardar'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Revisar y guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(sent?['payload']['operacion']['condicion'], 'CONTADO');
    expect(sent?['payload']['pagos_iniciales'][0]['monto_minor'], '1200');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'venta parcial 100 con abono 40 conserva crédito y una sola venta',
      (tester) async {
    Json? sent;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          sent = jsonDecode(r.body) as Json;
          return json({'replayed': false}, 201);
        }));
    api.session = session();
    await tester.pumpWidget(MaterialApp(
        home: EntryForm(api: api, kind: 'VENTA', business: const {
      'id': 'b'
    }, accounts: const [
      {'id': 'cash', 'nombre': 'Caja'}
    ], categories: const [
      {'id': 'category', 'nombre': 'Ventas', 'tipo': 'VENTA'}
    ], people: const [
      {'id': 'person', 'nombre': 'Ana'}
    ])));
    await tester.enterText(find.byType(TextFormField).at(0), 'Arroz');
    await tester.enterText(find.byType(TextFormField).at(1), '100');
    await tester.tap(find.text('Pago completo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pago parcial').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Abono inicial'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Abono inicial'), '40');
    await tester.scrollUntilVisible(find.text('Revisar y guardar'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Revisar y guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(sent?['payload']['operacion']['total_minor'], '10000');
    expect(sent?['payload']['operacion']['condicion'], 'CREDITO');
    expect(sent?['payload']['pagos_iniciales'][0]['monto_minor'], '4000');
    expect(sent?['payload']['operacion']['tercero_id'], 'person');
  });
  for (final kind in ['VENTA', 'COMPRA_MERCADERIA', 'GASTO_OPERATIVO']) {
    testWidgets('$kind contado se confirma con pago inicial exacto',
        (tester) async {
      Json? sent;
      final api = ApiClient(
          store: MemoryStore(),
          client: MockClient((r) async {
            sent = jsonDecode(r.body) as Json;
            return json({'replayed': false}, 201);
          }));
      api.session = session();
      await tester.pumpWidget(MaterialApp(
          home: EntryForm(api: api, kind: kind, business: const {
        'id': 'b'
      }, accounts: const [
        {'id': 'cash', 'nombre': 'Caja'}
      ], categories: [
        {'id': 'category', 'nombre': 'General', 'tipo': kind}
      ], people: const [])));
      await tester.enterText(find.byType(TextFormField).at(0), 'Mostrador');
      await tester.enterText(find.byType(TextFormField).at(1), '10,40');
      await tester.scrollUntilVisible(find.text('Revisar y guardar'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisar y guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(sent?['payload']['operacion']['total_minor'], '1040');
      expect(sent?['payload']['operacion']['categoria_id'], 'category');
      expect(sent?['payload']['operacion']['condicion'], 'CONTADO');
      expect(sent?['payload']['pagos_iniciales'][0]['monto_minor'], '1040');
      expect(
          sent?['payload']['pagos_iniciales'][0]['aplicacion_id'], isNotEmpty);
      expect(sent?['dispositivo_id'], 'device');
    });
  }
  for (final kind in ['VENTA', 'COMPRA_MERCADERIA']) {
    testWidgets('abono de $kind asigna movimiento sin crear otra operación',
        (tester) async {
      Json? sent;
      String? path;
      final api = ApiClient(
          store: MemoryStore(),
          client: MockClient((r) async {
            sent = jsonDecode(r.body) as Json;
            path = r.url.path;
            return json({'replayed': false}, 201);
          }));
      api.session = session();
      await tester.pumpWidget(MaterialApp(
          home: EntryForm(api: api, kind: 'payment', business: const {
        'id': 'b'
      }, accounts: const [
        {'id': 'cash', 'nombre': 'Caja'}
      ], categories: const [], people: const [], row: {
        'id': 'op',
        'tipo': kind,
        'concepto': 'Pedido',
        'total_minor': '10000',
        'liquidado_minor': '0',
        'pendiente_minor': '10000'
      })));
      await tester.enterText(find.byType(TextFormField).first, '40');
      await tester.scrollUntilVisible(find.text('Revisar y guardar'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisar y guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(sent?['tipo'],
          kind == 'VENTA' ? 'REGISTRAR_COBRO' : 'REGISTRAR_PAGO');
      expect(
          path, '/api/v1/negocios/b/${kind == 'VENTA' ? 'cobros' : 'pagos'}');
      expect(sent?['payload']['movimiento']['monto_minor'], '4000');
      expect(sent?['payload']['aplicaciones'][0]['operacion_id'], 'op');
      expect(sent?['payload'].containsKey('operacion'), false);
    });
  }
  test('403 y 409 definitivos no intentan refresh ni repiten escrituras',
      () async {
    for (final status in [403, 409]) {
      var calls = 0;
      final api = ApiClient(
          store: MemoryStore(),
          client: MockClient((r) async {
            calls++;
            return json({
              'error': {
                'code':
                    status == 403 ? 'ROLE_FORBIDDEN' : 'EXCEEDS_OUTSTANDING',
                'message': 'Revisa tus datos'
              }
            }, status);
          }));
      api.session = session();
      await expectLater(
          api.command('/negocios/b/cobros', 'REGISTRAR_COBRO', {}),
          throwsA(
              isA<ApiException>().having((e) => e.status, 'status', status)));
      expect(calls, 1);
      expect(api.pending, isNull);
    }
  });
}
