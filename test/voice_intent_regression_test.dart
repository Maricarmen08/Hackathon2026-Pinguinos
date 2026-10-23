import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/forms.dart';
import 'package:hackathon_pinguinos_mvp/v1/intake_page.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_speech.dart';
import 'widget_test.dart' show MemoryStore, session, json;
import 'v4_intake_test.dart' show page, visible;

void main() {
  for (final phrase in [
    ('Gasté 23 soles en azúcar.', 'Revisar gasto', 'GASTO_OPERATIVO', '2300'),
    ('Vendí 50 soles de arroz', 'Revisar venta', 'VENTA', '5000'),
    (
      'Compré mercadería por 100 soles',
      'Revisar compra',
      'COMPRA_MERCADERIA',
      '10000'
    ),
  ]) {
    testWidgets('voz local reconoce tipo sin pedir respaldo: ${phrase.$1}',
        (t) async {
      final messenger = t.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
          LocalSpeech.channel,
          (call) async => call.method == 'capabilities'
              ? {'onDevice': true, 'spanishInstalled': true}
              : call.method == 'prepare'
                  ? {'engine': 'native'}
                  : call.method == 'listen'
                      ? phrase.$1
                      : null);
      addTearDown(
          () => messenger.setMockMethodCallHandler(LocalSpeech.channel, null));
      var posts = 0;
      final api = ApiClient(
          store: MemoryStore(),
          client: MockClient((r) async {
            if (r.method == 'POST') posts++;
            return json(r.url.path.endsWith('/estado')
                ? {'configurado': true}
                : {'items': []});
          }))
        ..session = session();
      await t.pumpWidget(page(api));
      await t.pumpAndSettle();
      await visible(t, find.text('Hablar'));
      await t.tap(find.text('Hablar'));
      await t.pumpAndSettle();
      expect(find.text('Transcribir con ayuda por internet'), findsNothing);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
          phrase.$1);
      await visible(t, find.text('Interpretar texto corregido'));
      await t.tap(find.text('Interpretar texto corregido'));
      await t.pumpAndSettle();
      expect(find.text(phrase.$2), findsOneWidget);
      expect(posts, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'pendiente de audio muestra Gasto sin reescribir la propuesta del servidor',
      (t) async {
    final original = {
      'intencion': 'DESCONOCIDO',
      'concepto': 'azúcar',
      'monto_minor': '2300',
      'es_pago': true,
      'texto_visible': 'Gasto de 23 soles en azúcar',
    };
    var posts = 0;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') posts++;
          return json(r.url.path.endsWith('/estado')
              ? {'configurado': false}
              : {
                  'items': [
                    {
                      'id': 'server-audio-fixture',
                      'version': '1',
                      'tipo_entrada': 'AUDIO',
                      'transcripcion': 'Gasté 23 soles en azúcar.',
                      'resultado': original,
                      'creado_en': '2026-10-23T03:12:21Z',
                    }
                  ],
                });
        }))
      ..session = session();
    await t.pumpWidget(page(api));
    await t.pumpAndSettle();
    await visible(t, find.textContaining('Gasto ·'));
    expect(find.textContaining('Tipo por definir'), findsNothing);
    await visible(t, find.text('Revisar'));
    await t.tap(find.text('Revisar'));
    await t.pumpAndSettle();
    expect(find.text('Revisar gasto'), findsOneWidget);
    expect(original['intencion'], 'DESCONOCIDO');
    expect(posts, 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'audio alternativo corrige es_pago ambiguo y conserva extracción para revisión humana',
      (t) async {
    final messenger = t.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        LocalSpeech.channel,
        (call) async =>
            call.method == 'capabilities' ? {'onDevice': false} : null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(LocalSpeech.channel, null);
    });
    final posts = <String>[];
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            posts.add(r.url.path);
            expect(r.url.path, endsWith('/ia/analizar'));
            expect(r.headers['X-Finki-Consent'], '1');
            return json({
              'id': 'server-audio-fixture',
              'transcripcion': 'Gasté 23 soles en azúcar.',
              'resultado': {
                'intencion': 'DESCONOCIDO',
                'monto_minor': '2300',
                'concepto': 'azúcar',
                'es_pago': true,
                'pregunta': '¿Venta, abono, pago o traslado?',
                'texto_visible': 'Gasto de 23 soles en azúcar',
              }
            });
          }
          return json(r.url.path.endsWith('/estado')
              ? {'configurado': true}
              : {'items': []});
        }))
      ..session = session();
    await t.pumpWidget(page(api));
    await t.pumpAndSettle();
    await t.tap(find.byType(CheckboxListTile));
    await visible(t, find.text('Hablar'));
    await t.tap(find.text('Hablar'));
    await t.pumpAndSettle();
    expect(find.text('Transcribir con ayuda por internet'), findsOneWidget);
    expect(posts, isEmpty);
    await t.tap(find.text('Volver'));
    await t.pumpAndSettle();
    // Exercise the audio response handler used after stopping the recorder,
    // without testing the native recorder plugin or capturing actual audio.
    final dynamic state = t.state(find.byType(IntakePage));
    await state.analyze(bytes: Uint8List.fromList('RIFF-fixture'.codeUnits));
    await t.pumpAndSettle();
    expect(find.text('Revisar gasto'), findsOneWidget);
    expect(find.text('Elegir tipo de registro'), findsNothing);
    expect(posts, hasLength(1));
    await visible(t, find.text('Revisar gasto'));
    await t.tap(find.text('Revisar gasto'));
    await t.pumpAndSettle();
    final form = t.widget<EntryForm>(find.byType(EntryForm));
    expect(form.row!['extraccion_id'], 'server-audio-fixture');
    expect(form.row!['local_entry'], null);
    expect(form.row!['proposal']['intencion'], 'GASTO_OPERATIVO');
    expect(form.row!['proposal']['monto_minor'], '2300');
    expect(posts.where((p) => p.endsWith('/comandos')), isEmpty);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
