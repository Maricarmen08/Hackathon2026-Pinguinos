import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/intake_page.dart';
import 'package:hackathon_pinguinos_mvp/v1/intake_widgets.dart';
import 'widget_test.dart' show MemoryStore, session, json;
import 'v4_intake_test.dart' show business, visible;

void main() {
  for (final complete in [true, false]) {
    testWidgets(
        'foto completa=$complete: progreso, original, revisión y deduplicación',
        (t) async {
      late Directory directory;
      late File file;
      await t.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('finki-photo-test-');
        file = await File('${directory.path}/receipt.png')
            .writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
      });
      final messenger = t.binding.defaultBinaryMessenger;
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      const ocr = MethodChannel('google_mlkit_text_recognizer');
      messenger.setMockMethodCallHandler(paths, (_) async => directory.path);
      final first = Completer<Map<String, dynamic>>();
      var scans = 0, posts = 0, photos = 0;
      final lines = [
        'BODEGA PRUEBA',
        'BOLETA DE VENTA',
        'Fecha:23/10/2026',
        if (complete) ...[
          '1 ARROZ S/12.00',
          '1 AZUCAR S/8.00',
          'TOTAL S/20.00',
          'MEDIO DE PAGO: EFECTIVO'
        ]
      ];
      final native = <String, dynamic>{
        'text': lines.join('\n'),
        'blocks': [
          for (var i = 0; i < lines.length; i++)
            {
              'text': lines[i],
              'rect': {
                'left': 0,
                'top': i * 40,
                'right': 400,
                'bottom': i * 40 + 25
              },
              'points': [],
              'recognizedLanguages': [],
              'lines': [
                {
                  'text': lines[i],
                  'rect': {
                    'left': 0,
                    'top': i * 40,
                    'right': 400,
                    'bottom': i * 40 + 25
                  },
                  'points': [],
                  'recognizedLanguages': [],
                  'elements': [],
                  'confidence': .9,
                  'angle': 0.0
                }
              ]
            }
        ]
      };
      messenger.setMockMethodCallHandler(ocr, (call) async {
        if (call.method.contains('start')) {
          scans++;
          return scans == 1 ? first.future : native;
        }
        return null;
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(paths, null);
        messenger.setMockMethodCallHandler(ocr, null);
        if (directory.path.contains('finki-photo-test-')) {
          await directory.delete(recursive: true);
        }
      });
      final store = MemoryStore();
      final api = ApiClient(
          store: store,
          client: MockClient((r) async {
            if (r.method == 'POST') posts++;
            return json(r.url.path.endsWith('/estado')
                ? {'configurado': false}
                : {'items': []});
          }))
        ..session = {
          ...session(),
          'usuario': {'id': 'photo-test'}
        };
      await t.pumpWidget(MaterialApp(
          home: IntakePage(
              api: api,
              business: business,
              accounts: const [],
              categories: const [],
              people: const [],
              pickImage: (source) async {
                expect(source, ImageSource.camera);
                photos++;
                return XFile(file.path);
              })));
      await t.pumpAndSettle();
      await visible(t, find.text('Tomar foto'));
      await t.runAsync(() async {
        await t.tap(find.text('Tomar foto'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pump();
      expect(find.text('Analizando imagen en tu celular…'), findsOneWidget);
      expect(find.byType(IntakeProposalCard), findsNothing);
      first.complete(native);
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pumpAndSettle();
      final card =
          t.widget<IntakeProposalCard>(find.byType(IntakeProposalCard));
      expect(card.proposal['monto_minor'], complete ? '2000' : null);
      expect(card.proposal['intencion'], 'DESCONOCIDO');
      expect(find.text('Esto entendí').hitTestable(), findsOneWidget);
      final key = store.values.keys
          .singleWhere((k) => k.startsWith('local-proposals-v1:'));
      final original = (jsonDecode(store.values[key]!) as List).single as Map;
      final evidence =
          store.values.keys.singleWhere((k) => k.startsWith('local-evidence:'));
      final meta = jsonDecode(store.values[evidence]!) as Map;
      expect(meta['ocr_raw'], lines.join('\n'));
      expect(
          await t.runAsync(() =>
              File('${directory.path}/finki_evidence/${meta['token']}')
                  .readAsBytes()),
          [137, 80, 78, 71, 13, 10, 26, 10]);
      await visible(
          t, find.text(complete ? 'Tomar foto' : 'Repetir fotografía'));
      await t.runAsync(() async {
        await t.tap(find.text(complete ? 'Tomar foto' : 'Repetir fotografía'));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await t.pumpAndSettle();
      final drafts = jsonDecode(store.values[key]!) as List;
      expect(drafts, hasLength(1));
      expect(drafts.single['id'], original['id']);
      expect(photos, 2);
      expect(posts, 0);
      expect(api.localEntries, isEmpty);
      await visible(t, find.text('Ver texto completo'));
      await t.tap(find.text('Ver texto completo'));
      await t.pumpAndSettle();
      expect(find.text('Texto reconocido completo'), findsOneWidget);
      expect(
          t.widgetList<TextField>(find.byType(TextField)).last.controller!.text,
          contains('BODEGA PRUEBA'));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
