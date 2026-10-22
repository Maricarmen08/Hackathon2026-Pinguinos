import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/intake_page.dart';
import 'package:hackathon_pinguinos_mvp/v1/forms.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_draft.dart';
import 'package:hackathon_pinguinos_mvp/core/theme/app_theme.dart';
import 'widget_test.dart' show MemoryStore, session, json;

const business = {
  'id': 'b',
  'nombre': 'Ensayo',
  'inicio_historial': '2026-01-01'
};
const proposal = {
  'intencion': 'VENTA',
  'concepto': 'Arroz',
  'monto_minor': '5000',
  'fecha': '2026-10-22',
  'medio': null,
  'fiado': false,
  'es_pago': false,
  'texto_visible': 'Venta de arroz'
};
Widget page(ApiClient api, {double scale = 1}) => MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: IntakePage(
        api: api,
        business: business,
        accounts: const [],
        categories: const [],
        people: const []));
Future<void> visible(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 160, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('captura accesible sin desbordes a $width con texto ampliado',
        (t) async {
      t.view.physicalSize = Size(width, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var posts = 0;
      final api = ApiClient(
          store: MemoryStore(),
          client: MockClient((r) async {
            if (r.method == 'POST') posts++;
            return json(r.url.path.endsWith('/estado')
                ? {'configurado': true, 'proveedor': 'Gemini'}
                : {'items': []});
          }))
        ..session = {...session(), 'usuario': {'id':'v4-user'}};
      await t.pumpWidget(page(api, scale: 1.6));
      await t.pumpAndSettle();
      expect(find.textContaining('nivel gratuito'), findsNothing);
      expect(find.textContaining('servicio de IA externo'), findsOneWidget);
      await visible(t, find.text('Cómo se usan mis datos'));
      await t.tap(find.text('Cómo se usan mis datos'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.textContaining('Google puede usar'), 120, scrollable:find.byType(Scrollable).last);
      expect(find.textContaining('Google puede usar'), findsOneWidget);
      expect(posts, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'venta sugerida con una acción; cambiar tipo solo bajo petición y sin efectivo inventado',
      (t) async {
    final posts = <String>[];
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            posts.add(r.url.path);
            expect(r.headers['X-Finki-Consent-Version'], 'finki-v4-2026-10-22');
            return json({
              'id': 'p',
              'resultado': proposal,
              'estado': 'REQUIERE_REVISION'
            });
          }
          return json(r.url.path.endsWith('/estado')
              ? {'configurado': true, 'proveedor': 'Gemini'}
              : {'items': []});
        }))
      ..session = {...session(), 'usuario': {'id':'v4-user'}};
    await t.pumpWidget(page(api));
    await t.pumpAndSettle();
    await t.tap(find.byType(CheckboxListTile));
    await visible(t, find.byType(TextField));
    await t.enterText(find.byType(TextField), 'Vendí 50 soles de arroz');
    await visible(t, find.text('Interpretar'));
    await t.tap(find.text('Interpretar'));
    await t.pumpAndSettle();
    expect(posts.length, 1);
    expect(find.text('Revisar venta'), findsOneWidget);
    expect(find.text('Revisar gasto'), findsNothing);
    expect(find.text('Compré mercadería'), findsNothing);
    await visible(t, find.text('Cambiar tipo'));
    await t.tap(find.text('Cambiar tipo'));
    await t.pumpAndSettle();
    expect(find.text('¿Qué quieres registrar?'), findsOneWidget);
    expect(find.text('Cobro de un fiado'), findsOneWidget);
    Navigator.of(t.element(find.text('¿Qué quieres registrar?'))).pop();
    await t.pumpAndSettle();
    await visible(t, find.text('Revisar venta'));
    await t.tap(find.text('Revisar venta'));
    await t.pumpAndSettle();
    await visible(t, find.text('¿Cómo te pagaron?'));
    expect(find.text('Fiado'), findsOneWidget);
    expect(posts.where((p) => p.endsWith('/comandos')), isEmpty);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'propuesta pendiente con fecha legible y descarte confirmado sin afectar finanzas',
      (t) async {
    var discarded = false;
    Json? command;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            command = jsonDecode(r.body) as Json;
            discarded = true;
            return json({'entidades': []});
          }
          return json(r.url.path.endsWith('/estado')
              ? {'configurado': true, 'proveedor': 'Gemini'}
              : {
                  'items': discarded
                      ? []
                      : [
                          {
                            'id': 'p',
                            'version': '3',
                            'resultado': proposal,
                            'tipo_entrada': 'TEXTO',
                            'creado_en': '2026-10-22T19:06:23.000Z'
                          }
                        ]
                });
        }))
      ..session = {...session(), 'usuario': {'id':'v4-user'}};
    await t.pumpWidget(page(api));
    await t.pumpAndSettle();
    await visible(t, find.text('Descartar'));
    expect(find.textContaining('14:06'), findsOneWidget);
    expect(find.textContaining('T19:'), findsNothing);
    await t.tap(find.text('Descartar'));
    await t.pumpAndSettle();
    expect(command, isNull);
    await t.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await t.pumpAndSettle();
    expect(command!['tipo'], 'DESCARTAR_PROPUESTA');
    expect(
        command!['payload'], {'extraccion_id': 'p', 'expected_version': '3'});
    expect(find.text('Pendiente'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('borrador manual recuperado al reabrir; aislado por negocio',
      (t) async {
    final store = MemoryStore();
    final api = ApiClient(store: store)..session = {...session(), 'usuario': {'id':'v4-user'}};
    Widget form(ApiClient c, Json b) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: EntryForm(
            api: c,
            kind: 'VENTA',
            business: b,
            accounts: const [],
            categories: const [],
            people: const []));
    final first = ApiClient(store: store)..session = {...session(), 'usuario': {'id':'v4-user'}};
    await t.pumpWidget(form(first, business));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'Borrador de arroz');
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpWidget(const SizedBox());
    await t.pump();
    final second = ApiClient(store: store)..session = {...session(), 'usuario': {'id':'v4-user'}};
    await t.pumpWidget(form(second, business));
    await t.pumpAndSettle();
    expect(find.text('Borrador de arroz'), findsOneWidget);
    expect(find.textContaining('Recuperamos tu borrador'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(form(api, {...business, 'id': 'different'}));
    await t.pumpAndSettle();
    expect(find.text('Borrador de arroz'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  test('limpiar borrador espera escrituras previas y no lo resucita', () async {
    final store = MemoryStore(), draft = LocalDraft(MemoryStore(), 'unused');
    final d = LocalDraft(store, 'scoped');
    final a = d.save({'monto': '50'}), b = d.save({'monto': '60'});
    await d.clearAfterSubmission();
    await Future.wait([a, b]);
    await d.save({'monto': '70'});
    expect(await d.read(), isNull);
    expect(await draft.read(), isNull);
  });
}
