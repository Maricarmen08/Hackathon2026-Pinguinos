import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/insights_page.dart';
import 'widget_test.dart' show MemoryStore, json, session;

void main() {
  testWidgets(
      'saludo sin autorización y aclaración con opciones conserva el periodo',
      (t) async {
    final posted = <Map<String, dynamic>>[];
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          posted.add(body);
          if (body['pregunta'] == 'qué tal') {
            return json({
              'respuesta': '¡Hola! Soy Finki. ¿Qué quieres revisar?',
              'fuente': 'ORIENTACION'
            });
          }
          if (body['pregunta'] == 'cuánta plata hice ayer') {
            return json({
              'respuesta': '¿Quieres ver ventas o cobros?',
              'fuente': 'ACLARACION',
              'opciones': [
                {
                  'titulo': 'Ventas',
                  'pregunta': 'ventas del 2026-10-22 al 2026-10-22'
                },
                {
                  'titulo': 'Dinero cobrado',
                  'pregunta': 'cobros del 2026-10-22 al 2026-10-22'
                }
              ]
            });
          }
          return json(
              {'respuesta': 'S/ 50.00 en cobros', 'fuente': 'REGISTROS'});
        }))
      ..session = session();
    await t
        .pumpWidget(MaterialApp(home: InsightsPage(api: api, businessId: 'a')));
    await t.enterText(find.byType(TextField), 'qué tal');
    await t.pump();
    await t.tap(find.text('Consultar mis registros'));
    await t.pumpAndSettle();
    expect(find.text('Ayudarme a entender mi pregunta'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    await t.ensureVisible(find.byType(TextField));
    await t.enterText(find.byType(TextField), 'cuánta plata hice ayer');
    await t.pump();
    await t.ensureVisible(find.text('Consultar mis registros'));
    await t.pumpAndSettle();
    await t.tap(find.text('Consultar mis registros'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Dinero cobrado'));
    await t.pumpAndSettle();
    await t.tap(find.text('Dinero cobrado'));
    await t.pumpAndSettle();
    expect(posted.last['pregunta'], 'cobros del 2026-10-22 al 2026-10-22');
    expect(posted.any((b) => b['consentimiento_externo'] == true), false);
    expect(t.takeException(), isNull);
    api.client.close();
  });
  testWidgets(
      'ayuda externa requiere autorizar en diálogo adaptable, cancelar no envía',
      (t) async {
    t.view.physicalSize = const Size(320, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final posted = <Map<String, dynamic>>[];
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          posted.add(body);
          return body['consentimiento_externo'] == true
              ? json({'respuesta': 'S/ 10.00 en ventas'})
              : json({
                  'error': {
                    'code': 'QUESTION_UNSUPPORTED',
                    'message': 'Puedes reformular tu pregunta.'
                  }
                }, 422);
        }))
      ..session = session();
    await t.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: InsightsPage(api: api, businessId: 'a')));
    await t.enterText(find.byType(TextField), 'Cuánto facturé hoy');
    await t.pump();
    await t.scrollUntilVisible(find.text('Consultar mis registros'), 150,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Consultar mis registros'));
    await t.pumpAndSettle();
    for (final authorize in [false, true]) {
      await t.scrollUntilVisible(
          find.text('Ayudarme a entender mi pregunta'), 150,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Ayudarme a entender mi pregunta'));
      await t.pumpAndSettle();
      expect(posted.length, 1);
      final action =
          find.text(authorize ? 'Autorizar y continuar' : 'Ahora no');
      await t.ensureVisible(action);
      await t.pumpAndSettle();
      await t.tap(action);
      await t.pumpAndSettle();
    }
    expect(posted.length, 2);
    expect(posted.last['consentimiento_externo'], true);
    expect(t.takeException(), isNull);
    api.client.close();
  });
  testWidgets('resumen con saltos de línea legible a 320 px y texto ampliado',
      (t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const response =
        'Resumen de tu negocio · 19/10/2026 al 23/10/2026\n\nActividad del periodo\nVentas: S/ 100.00\nGastos operativos: S/ 23.00\nCompras de mercadería: S/ 80.00\n\nDinero cobrado y pagado\nCobros de ventas: S/ 40.00\n\nDeudas al 23/10/2026\nPor cobrar: S/ 60.00\nPor pagar: S/ 0.00\n\nResultado simplificado: -S/ 3.00';
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async => json({'respuesta': response})))
      ..session = session();
    await t.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: InsightsPage(api: api, businessId: 'a')));
    await t.enterText(find.byType(TextField), 'Mi resumen semanal');
    await t.pump();
    await t.scrollUntilVisible(find.text('Consultar mis registros'), 150,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Consultar mis registros'));
    await t.pumpAndSettle();
    expect(
        t.widget<SelectableText>(find.byType(SelectableText)).data, response);
    await t.scrollUntilVisible(
        find.text('Fuente: registros del negocio seleccionado.'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(t.takeException(), isNull);
    api.client.close();
  });
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
