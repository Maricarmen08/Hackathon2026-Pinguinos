import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/insights_page.dart';
import 'widget_test.dart' show MemoryStore, json, session;

void main() {
  testWidgets(
      'consulta libre, chips compactos, respuesta visible y caché solo del negocio',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = MemoryStore();
    var offline = false, calls = 0;
    final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, contains('/consultas'));
          if (offline) throw http.ClientException('offline');
          return json({'respuesta': 'Ventas S/ 100.00. Cobros S/ 40.00.'});
        }))
      ..session = {
        ...session(),
        'usuario': {'id': 'user'}
      };
    await t
        .pumpWidget(MaterialApp(home: InsightsPage(api: api, businessId: 'a')));
    expect(find.byType(ActionChip), findsNWidgets(9));
    await t.enterText(find.byType(TextField), 'Dime mis ventas hoy');
    await t.pump();
    await t.tap(find.text('Consultar mis registros'));
    await t.pumpAndSettle();
    expect(find.text('Ventas S/ 100.00. Cobros S/ 40.00.'), findsOneWidget);
    final rect = t.getRect(find.text('Ventas S/ 100.00. Cobros S/ 40.00.'));
    expect(rect.top, lessThan(800));
    expect(rect.bottom, greaterThan(0));
    expect(store.values.keys.any((k) => k.startsWith('insights:v2:user:a:')),
        true);
    offline = true;
    await t.ensureVisible(find.text('Consultar mis registros'));
    await Scrollable.ensureVisible(
        t.element(find.text('Consultar mis registros')),
        alignment: 0.4);
    await t.pumpAndSettle();
    await t.tap(find.text('Consultar mis registros'));
    await t.pumpAndSettle();
    expect(find.textContaining('Respuesta histórica'), findsOneWidget);
    expect(calls, 2);
    await t.pumpWidget(MaterialApp(
        home:
            InsightsPage(key: const ValueKey('b'), api: api, businessId: 'b')));
    await t.enterText(find.byType(TextField), 'Dime mis ventas hoy');
    await t.pump();
    await t.tap(find.text('Consultar mis registros'));
    await t.pumpAndSettle();
    expect(
        find.textContaining('no tengo una respuesta guardada'), findsOneWidget);
    expect(find.text('Ventas S/ 100.00. Cobros S/ 40.00.'), findsNothing);
    api.client.close();
  });
  testWidgets(
      'errores útiles, pregunta vacía bloqueada y sin respuestas inventadas',
      (t) async {
    var requests = 0;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          requests++;
          return json({
            'error': {
              'code': 'QUESTION_UNSUPPORTED',
              'message': 'No puedo predecir ventas.'
            }
          }, 422);
        }));
    await t
        .pumpWidget(MaterialApp(home: InsightsPage(api: api, businessId: 'a')));
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, null);
    await t.enterText(find.byType(TextField), '¿Cuánto venderé mañana?');
    await t.pump();
    await t.tap(find.text('Consultar mis registros'));
    await t.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('No puedo predecir ventas.'), findsOneWidget);
  });
}
