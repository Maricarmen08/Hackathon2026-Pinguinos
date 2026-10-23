import 'dart:async';
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
  for (final code in ['CANCELLED', 'AUDIO_INTERRUPTED']) {
    testWidgets('sesión $code conserva texto y no crea propuestas', (t) async {
      final messenger = t.binding.defaultBinaryMessenger;
      final finish = Completer<String>();
      var posts = 0;
      messenger.setMockMethodCallHandler(LocalSpeech.channel, (call) async {
        if (call.method == 'capabilities') {
          return {'onDevice': false, 'offlineModel': true};
        }
        if (call.method == 'prepare') return {'engine': 'vosk'};
        if (call.method == 'listen') return finish.future;
        if (call.method == 'cancel' && !finish.isCompleted) {
          finish.completeError(PlatformException(code: code));
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
          'usuario': {'id': 'cancel-test'}
        };
      await t.pumpWidget(page(api));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Texto anterior');
      await visible(t, find.text('Hablar'));
      await t.tap(find.text('Hablar'));
      await t.pump();
      await messenger.handlePlatformMessage(
          LocalSpeech.channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('ready')),
          (_) {});
      await t.pump();
      await t.pump(const Duration(seconds: 5));
      if (code == 'CANCELLED') {
        await t.ensureVisible(find.text('Cancelar grabación'));
        await t.pump();
        await t.tap(find.text('Cancelar grabación'));
      } else {
        finish.completeError(PlatformException(code: code));
      }
      await t.pumpAndSettle();
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
          'Texto anterior');
      expect(find.byType(IntakeProposalCard), findsNothing);
      expect(
          store.values.keys.where((k) => k.startsWith('local-proposals-v1:')),
          isEmpty);
      if (code == 'AUDIO_INTERRUPTED') {
        expect(find.textContaining('al salir de FINKI'), findsOneWidget);
      }
      expect(posts, 0);
      await t.pumpWidget(const SizedBox());
    });
  }
  for (final duration in [3, 5, 10, 45]) {
    testWidgets('sesión manual ${duration}s, pausas y único final', (t) async {
      final messenger = t.binding.defaultBinaryMessenger;
      final finish = Completer<String>();
      var stops = 0, posts = 0;
      Future<void> event(String method, [dynamic argument]) async {
        await messenger.handlePlatformMessage(
            LocalSpeech.channel.name,
            const StandardMethodCodec()
                .encodeMethodCall(MethodCall(method, argument)),
            (_) {});
      }

      messenger.setMockMethodCallHandler(LocalSpeech.channel, (call) async {
        if (call.method == 'capabilities') {
          return {'onDevice': true, 'offlineModel': true};
        }
        if (call.method == 'prepare') {
          expect((call.arguments as Map)['preferNative'], false);
          return {'engine': 'vosk'};
        }
        if (call.method == 'listen') return finish.future;
        if (call.method == 'stop') stops++;
        return null;
      });
      addTearDown(
          () => messenger.setMockMethodCallHandler(LocalSpeech.channel, null));
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
      // The counter starts only after the native microphone is really ready.
      await t.pump(const Duration(seconds: 2));
      expect(find.textContaining('Grabando ·'), findsNothing);
      await event('ready');
      await t.pump();
      await event('partial', 'vendí cincuenta');
      for (var i = 0; i < duration; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(find.text('Grabando · 00:${duration.toString().padLeft(2, '0')}'),
          findsOneWidget);
      expect(find.byType(IntakeProposalCard), findsNothing);
      expect(stops, duration == 45 ? 1 : 0);
      if (duration < 45) {
        await t.ensureVisible(find.text('Detener y revisar'));
        await t.pumpAndSettle();
        await t.tap(find.text('Detener y revisar'));
        await t.pump();
        expect(stops, 1);
      }
      await event('processing');
      await t.pump();
      expect(find.textContaining('Grabando ·'), findsNothing);
      expect(find.text('Transcribiendo tu grabación en el celular…'),
          findsOneWidget);
      finish.complete('Vendí cincuenta soles de arroz');
      await t.pumpAndSettle();
      final card =
          t.widget<IntakeProposalCard>(find.byType(IntakeProposalCard));
      expect(card.proposal['monto_minor'], '5000');
      expect(find.text('Esto entendí').hitTestable(), findsOneWidget);
      expect(posts, 0);
      expect(api.localEntries, isEmpty);
      await t.pumpWidget(const SizedBox());
    });
  }
}
