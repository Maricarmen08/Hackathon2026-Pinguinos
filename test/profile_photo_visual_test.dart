import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/profile_photo_page.dart';
import 'package:hackathon_pinguinos_mvp/v1/profile_photo_state.dart';
import 'widget_test.dart' show MemoryStore, session, json;

Json identitySession() => session();

const firstPhoto =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMQkdP4DwAB/gFaQ7UOogAAAABJRU5ErkJggg==';
const secondPhoto =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNIkdP4DwADPgGqb21kyQAAAABJRU5ErkJggg==';

class PhotoTestApi extends ApiClient {
  PhotoTestApi({required super.client, required super.store});
  void user(String? id) {
    this.session = id == null
        ? null
        : {
            ...identitySession(),
            'usuario': {'id': id}
          };
    notifyListeners();
  }
}

void main() {
  test(
      'una carga compartida, cambio, eliminación y reapertura offline sin copias adicionales',
      () async {
    final store = MemoryStore();
    var requests = 0;
    final api = PhotoTestApi(
        store: store,
        client: MockClient((r) async {
          requests++;
          return json({'imagen_base64': firstPhoto});
        }))
      ..user('ana');
    final state = ProfilePhotoState.of(api);
    await Future.wait([state.load(), state.load(), state.load()]);
    expect(requests, 1);
    expect(identical(state, ProfilePhotoState.of(api)), true);
    expect(state.bytes, base64Decode(firstPhoto));
    await state.saved('ana', secondPhoto);
    expect(state.bytes, base64Decode(secondPhoto));
    final reopened = PhotoTestApi(
        store: store,
        client: MockClient((_) async => throw http.ClientException('offline')))
      ..user('ana');
    final restored = ProfilePhotoState.of(reopened);
    await restored.load();
    expect(restored.bytes, base64Decode(secondPhoto));
    expect(reopened.offline, true);
    await state.saved('ana', null);
    expect(state.hasPhoto, false);
    expect(jsonDecode(store.values['cache:ana:/perfil/foto']!)['imagen_base64'],
        null);
    expect(
        store.values.keys.where((k) => k.contains('/perfil/foto')).length, 1);
    api.user(null);
    expect(state.bytes, isNull);
    api.user('bob');
    expect(state.bytes, isNull);
  });
  test(
      'respuesta tardía y guardado anterior no cruzan cuentas ni pisan una foto nueva',
      () async {
    final pending = Completer<http.Response>();
    final store = MemoryStore();
    final api =
        PhotoTestApi(store: store, client: MockClient((_) => pending.future))
          ..user('ana');
    final state = ProfilePhotoState.of(api);
    final old = state.load();
    api.user('bob');
    await state.saved('bob', secondPhoto);
    pending.complete(json({'imagen_base64': firstPhoto}));
    await old;
    await state.saved('ana', firstPhoto);
    expect(state.bytes, base64Decode(secondPhoto));
    expect(jsonDecode(store.values['cache:bob:/perfil/foto']!)['imagen_base64'],
        secondPhoto);
    expect(store.values.containsKey('cache:ana:/perfil/foto'), false);
  });
  for (final width in [320.0, 390.0, 714.0]) {
    testWidgets(
        'tres vistas sincronizadas, círculo, separación y eliminación condicional a $width',
        (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var stored = firstPhoto;
      final api = PhotoTestApi(
          store: MemoryStore(),
          client: MockClient((r) async {
            if (r.method == 'DELETE') {
              stored = '';
              return json({'ok': true});
            }
            return json({'imagen_base64': stored.isEmpty ? null : stored});
          }))
        ..user('ana');
      final photo = ProfilePhotoState.of(api);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
                ProfileAvatar(api: api),
                Expanded(child: ProfilePhotoPage(api: api)),
              ]),
              bottomNavigationBar: NavigationBar(destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.home_outlined), label: 'Inicio'),
                NavigationDestination(
                    icon: ProfileAvatar(api: api, radius: 12, navigation: true),
                    label: 'Perfil')
              ]))));
      await t.pumpAndSettle();
      expect(find.byType(CircleAvatar), findsNWidgets(3));
      for (final avatar
          in t.widgetList<CircleAvatar>(find.byType(CircleAvatar))) {
        expect((avatar.backgroundImage! as MemoryImage).bytes,
            base64Decode(firstPhoto));
      }
      final gallery =
          find.widgetWithText(OutlinedButton, 'Elegir de la galería');
      final camera = find.widgetWithText(OutlinedButton, 'Tomar fotografía');
      expect(t.getTopLeft(camera).dy - t.getBottomLeft(gallery).dy,
          greaterThanOrEqualTo(12));
      expect(find.text('Eliminar fotografía'), findsOneWidget);
      await photo.saved('ana', secondPhoto);
      await t.pumpAndSettle();
      for (final avatar
          in t.widgetList<CircleAvatar>(find.byType(CircleAvatar))) {
        expect((avatar.backgroundImage! as MemoryImage).bytes,
            base64Decode(secondPhoto));
      }
      await photo.saved('ana', null);
      await t.pumpAndSettle();
      expect(find.text('Eliminar fotografía'), findsNothing);
      for (final avatar
          in t.widgetList<CircleAvatar>(find.byType(CircleAvatar))) {
        expect(avatar.backgroundImage, isNull);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
