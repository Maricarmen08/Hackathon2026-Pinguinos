import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_entry.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_rules.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_speech.dart';
import 'widget_test.dart' show MemoryStore, session, json;
import 'v4_intake_test.dart' show page, visible;

Json signedIn() => {
      ...session(),
      'usuario': {'id': 'local-user'}
    };
Json entry({bool image = false}) => {
      'id_local': 'a59ab673-a9b3-43ac-a802-8b41e180c6bd',
      'tipo': image ? 'IMAGEN' : 'VOZ',
      'texto': 'Vendí cincuenta soles de arroz',
      'propuesta': LocalRules().interpret('Vendí cincuenta soles de arroz'),
      'comprobante_id': image ? 'image-1' : null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('confirmación local offline conserva identidad tras respuesta perdida',
      () async {
    final store = MemoryStore(), bodies = <String>[];
    var lost = true;
    final client = MockClient((r) async {
      bodies.add(r.body);
      if (lost) {
        lost = false;
        throw http.ClientException('Respuesta perdida');
      }
      return json({'replayed': true});
    });
    final api = ApiClient(store: store, client: client)..session = signedIn();
    await store.write('session', jsonEncode(signedIn()));
    final payload = localConfirmation(entry(), 'REGISTRAR_OPERACION', {
      'operacion': {'total_minor': '5000'}
    });
    expect(payload.containsKey('extraccion_id'), false);
    final result = await api.command(
        '/negocios/b/comandos', 'CONFIRMAR_PROPUESTA_LOCAL', payload);
    expect(result['local'], true);
    expect(api.localEntries.single['resultado_incierto'], true);
    final restored = ApiClient(store: store, client: client);
    await restored.restore();
    await restored.syncLocal();
    expect(bodies, hasLength(2));
    expect(bodies[0], bodies[1]);
    expect(restored.localEntries, isEmpty);
  });
  test(
      'imagen offline sube original antes de confirmar; reintento usa mismos IDs',
      () async {
    final store = MemoryStore(), paths = <String>[], bodies = <String>[];
    var lost = true;
    final client = MockClient((r) async {
      paths.add(r.url.path);
      if (r.url.path.endsWith('/evidencia-local')) {
        expect(r.url.queryParameters['id'], 'image-1');
        expect(r.bodyBytes, [1, 2, 3, 4]);
        return json({'id': 'image-1'});
      }
      bodies.add(r.body);
      if (lost) {
        lost = false;
        throw http.ClientException('Respuesta perdida');
      }
      return json({'replayed': true});
    });
    Future<List<int>> read(String token) async {
      expect(token, 'hash');
      return [1, 2, 3, 4];
    }

    final api = ApiClient(store: store, client: client, mediaReader: read)
      ..session = signedIn()
      ..offline = true;
    await store.write('session', jsonEncode(signedIn()));
    await store.write(
        'local-evidence:local-user:b:image-1', jsonEncode({'token': 'hash'}));
    await api.command('/negocios/b/comandos', 'CONFIRMAR_PROPUESTA_LOCAL',
        localConfirmation(entry(image: true), 'REGISTRAR_OPERACION', {}));
    expect(paths, isEmpty);
    final restored = ApiClient(store: store, client: client, mediaReader: read);
    await restored.restore();
    await expectLater(restored.syncLocal(), throwsA(isA<ApiException>()));
    await restored.syncLocal();
    expect(paths.map((p) => p.split('/').last),
        ['evidencia-local', 'comandos', 'evidencia-local', 'comandos']);
    expect(bodies[0], bodies[1]);
    expect(restored.localEntries, isEmpty);
  });
  test('imagen ausente queda en revisión y nunca confirma sin evidencia',
      () async {
    var requests = 0;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          requests++;
          return json({});
        }))
      ..session = signedIn()
      ..offline = true;
    await api.command('/negocios/b/comandos', 'CONFIRMAR_PROPUESTA_LOCAL',
        localConfirmation(entry(image: true), 'REGISTRAR_OPERACION', {}));
    await expectLater(api.syncLocal(), throwsA(isA<ApiException>()));
    expect(api.localEntries.single['estado'], 'REVISION');
    expect(requests, 0);
  });
  testWidgets(
      'voz nativa editable y propuesta recuperada sin llamadas externas',
      (t) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        LocalSpeech.channel,
        (call) async => switch (call.method) {
              'capabilities' => {
                  'onDevice': true,
                  'spanishInstalled': true,
                  'language': 'es-PE'
                },
              'listen' => 'Vendí cincuenta soles de arroz',
              'prepare' => {'engine': 'native'},
              _ => null,
            });
    addTearDown(
        () => messenger.setMockMethodCallHandler(LocalSpeech.channel, null));
    final store = MemoryStore();
    var posts = 0;
    final client = MockClient((r) async {
      if (r.method == 'POST') posts++;
      return json(r.url.path.endsWith('/estado')
          ? {'configurado': false}
          : {'items': []});
    });
    final api = ApiClient(store: store, client: client)..session = signedIn();
    await t.pumpWidget(page(api));
    await t.pumpAndSettle();
    await visible(t, find.text('Hablar'));
    await t.tap(find.text('Hablar'));
    await t.pumpAndSettle();
    expect(find.text('Vendí cincuenta soles de arroz'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Vendí sesenta soles de arroz');
    await visible(t, find.text('Interpretar texto corregido'));
    await t.tap(find.text('Interpretar texto corregido'));
    await t.pumpAndSettle();
    expect(find.text('Revisar venta'), findsOneWidget);
    expect(posts, 0);
    final drafts =
        jsonDecode(store.values['local-proposals-v1:local-user:b']!) as List;
    expect(drafts.single['resultado']['monto_minor'], '6000');
    expect(drafts.single['entrada']['tipo'], 'VOZ');
    await t.pumpWidget(const SizedBox());
    final restored = ApiClient(store: store, client: client)
      ..session = signedIn();
    await t.pumpWidget(page(restored));
    await t.pumpAndSettle();
    await visible(t, find.text('Por revisar'));
    expect(find.text('Pendiente'), findsOneWidget);
    expect(posts, 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'cuota agotada bloquea ayuda externa y conserva interpretación local',
      (t) async {
    var external = 0;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            external++;
            return json({
              'error': {
                'code': 'AI_QUOTA_EXHAUSTED',
                'message': 'Cuota agotada'
              }
            }, 503);
          }
          return json(r.url.path.endsWith('/estado')
              ? {'configurado': true, 'disponible': true}
              : {'items': []});
        }))
      ..session = signedIn();
    await t.pumpWidget(page(api));
    await t.pumpAndSettle();
    await t.tap(find.byType(CheckboxListTile));
    await t.enterText(find.byType(TextField), 'Algo ocurrió con el dinero');
    await visible(t, find.text('Interpretar'));
    await t.tap(find.text('Interpretar'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Pedir ayuda por internet'), -160,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Pedir ayuda por internet'));
    await t.pumpAndSettle();
    expect(external, 1);
    expect(
        t
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Pedir ayuda por internet'))
            .onPressed,
        isNull);
    await t.scrollUntilVisible(find.byType(TextField), -160,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Gasté veinte soles en luz');
    await visible(t, find.text('Interpretar'));
    await t.tap(find.text('Interpretar'));
    await t.pumpAndSettle();
    expect(find.text('Revisar gasto'), findsOneWidget);
    expect(external, 1);
    await t.pumpWidget(const SizedBox());
  });
}
