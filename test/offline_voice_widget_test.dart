import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/local_speech.dart';
import 'package:hackathon_pinguinos_mvp/v1/intake_widgets.dart';
import 'widget_test.dart' show MemoryStore, session, json;
import 'v4_intake_test.dart' show page, visible;

void main() {
  testWidgets(
      'Vosk funciona sin consentimiento externo y espera capacidades antes de elegir motor',
      (t) async {
    final caps = Completer<Map<String, dynamic>>();
    final calls = <String>[];
    final messenger = t.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(LocalSpeech.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'capabilities') return caps.future;
      if (call.method == 'prepare') {
        expect((call.arguments as Map)['preferNative'], false);
        return {'engine': 'vosk'};
      }
      return call.method == 'listen'
          ? 'gasté veintitrés soles en azúcar'
          : null;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(LocalSpeech.channel, null));
    var posts = 0;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') posts++;
          return json(r.url.path.endsWith('/estado')
              ? {'configurado': false}
              : {'items': []});
        }))
      ..session = session();
    await t.pumpWidget(page(api));
    await t.pumpAndSettle();
    await visible(t, find.text('Hablar'));
    await t.tap(find.text('Hablar'));
    await t.pump();
    expect(find.text('Transcribir con ayuda por internet'), findsNothing);
    expect(calls, ['capabilities']);
    caps.complete({'onDevice': false, 'offlineModel': true});
    await t.pumpAndSettle();
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
        'gasté veintitrés soles en azúcar');
    expect(find.text('Revisar gasto'), findsOneWidget);
    expect(find.text('Esto entendí').hitTestable(), findsOneWidget);
    expect(posts, 0);
    expect(calls, containsAllInOrder(['capabilities', 'prepare', 'listen']));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  for (final row in [
    ('Gasté 23 soles en azúcar', 'GASTO_OPERATIVO', '2300'),
    ('Vendí 50 soles de arroz', 'VENTA', '5000'),
    ('Compré 100 soles de mercadería', 'COMPRA_MERCADERIA', '10000'),
    ('Le fié 30 soles a Juan', 'VENTA', '3000'),
    ('este veintitrés ofrecen en azúcar', 'DESCONOCIDO', null),
  ]) {
    testWidgets('final automático, visible y sin guardar: ${row.$1}',
        (t) async {
      await t.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final finalText = Completer<String>();
      final messenger = t.binding.defaultBinaryMessenger;
      var listens = 0, posts = 0;
      messenger.setMockMethodCallHandler(LocalSpeech.channel, (call) async {
        if (call.method == 'capabilities') {
          return {'onDevice': false, 'offlineModel': true};
        }
        if (call.method == 'prepare') return {'engine': 'vosk'};
        if (call.method == 'listen') {
          listens++;
          return finalText.future;
        }
        return null;
      });
      addTearDown(
          () => messenger.setMockMethodCallHandler(LocalSpeech.channel, null));
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
          'usuario': {'id': 'voice-user'}
        };
      await t.pumpWidget(page(api));
      await t.pumpAndSettle();
      await visible(t, find.text('Hablar'));
      await t.tap(find.text('Hablar'));
      await t.pump();
      await messenger.handlePlatformMessage(
          LocalSpeech.channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('ready')),
          (_) {});
      await t.pump();
      // Deliver a real method-channel partial while the final Future is pending.
      await messenger.handlePlatformMessage(
          LocalSpeech.channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(MethodCall('partial', row.$1)),
          (_) {});
      await t.pump();
      expect(find.byType(IntakeProposalCard), findsNothing);
      expect(
          store.values.keys.where((k) => k.startsWith('local-proposals-v1:')),
          isEmpty);
      await t.ensureVisible(find.text('Detener y revisar'));
      await t.pump();
      await t.tap(find.text('Detener y revisar'));
      await t.tap(find.text('Detener y revisar'));
      await t.pump();
      expect(listens, 1);
      expect(find.byType(IntakeProposalCard), findsNothing);
      finalText.complete(row.$1);
      await t.pumpAndSettle();
      final card =
          t.widget<IntakeProposalCard>(find.byType(IntakeProposalCard));
      expect(card.proposal['intencion'], row.$2);
      expect(card.proposal['monto_minor'], row.$3);
      if (row.$1.startsWith('Le fié')) expect(card.proposal['fiado'], true);
      expect(find.text('Esto entendí').hitTestable(), findsOneWidget);
      final draftKey = store.values.keys
          .singleWhere((k) => k.startsWith('local-proposals-v1:'));
      final original =
          (jsonDecode(store.values[draftKey]!) as List).single as Map;
      expect(listens, 1);
      expect(posts, 0);
      // Correct the existing draft twice. It must remain the same pending item.
      await t.ensureVisible(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'Gasté 25 soles en azúcar');
      for (var i = 0; i < 2; i++) {
        await t.ensureVisible(find.text('Interpretar texto corregido'));
        await t.pumpAndSettle();
        await t.tap(find.text('Interpretar texto corregido'));
        await t.pumpAndSettle();
      }
      final drafts = jsonDecode(store.values[draftKey]!) as List;
      expect(drafts, hasLength(1));
      expect(drafts.single['id'], original['id']);
      expect(drafts.single['resultado']['monto_minor'], '2500');
      expect(find.byType(IntakeProposalCard), findsOneWidget);
      expect(posts, 0);
      expect(api.localEntries, isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  for (final code in ['PERMISSION_REQUIRED', 'NO_SPEECH', 'CANCELLED']) {
    testWidgets('Vosk $code no envía audio ni pierde el texto anterior',
        (t) async {
      final messenger = t.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(LocalSpeech.channel, (call) async {
        if (call.method == 'capabilities') {
          return {'onDevice': false, 'offlineModel': true};
        }
        if (call.method == 'prepare') return {'engine': 'vosk'};
        if (call.method == 'listen') throw PlatformException(code: code);
        return null;
      });
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
      await t.enterText(find.byType(TextField), 'Mi texto anterior');
      await t.ensureVisible(find.text('Hablar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Hablar'));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
          'Mi texto anterior');
      expect(find.text('Transcribir con ayuda por internet'), findsNothing);
      expect(posts, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
