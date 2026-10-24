import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/google_access.dart';
import 'package:hackathon_pinguinos_mvp/v1/app.dart';
import 'widget_test.dart' show MemoryStore, json, session;

void main() {
  test('cada método de acceso queda explícito sin cambiar tokens o usuario',
      () async {
    final api = ApiClient(
        store: MemoryStore(), client: MockClient((r) async => json(session())));
    await api.authenticateGoogle('fixture', GoogleAccess.nonce);
    expect(api.session?['metodo_acceso'], 'GOOGLE');
    await api.authenticate(
        false, {'usuario': 'fixture@example.invalid', 'clave': 'fixture-only'});
    expect(api.session?['metodo_acceso'], 'TRADICIONAL');
    api.client.close();
  });
  testWidgets(
      'Google nuevo llega a registrar negocio sin pedir teléfono o clave',
      (t) async {
    final signed = {
      ...session(),
      'usuario': {
        'id': 'user',
        'nombre': 'Google Ensayo',
        'telefono': null,
        'correo': 'fixture@example.invalid',
        'tiene_clave': false,
        'google_vinculado': true
      }
    };
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/google')) return json(signed);
          if (r.url.path.endsWith('/auth/me')) {
            return json({'usuario': signed['usuario'], 'negocios': []});
          }
          throw StateError('Unexpected request');
        }));
    await t.pumpWidget(MaterialApp(home: SessionGate(api: api)));
    await t.pumpAndSettle();
    await api.authenticateGoogle('fixture-token', GoogleAccess.nonce);
    await t.pumpAndSettle();
    expect(find.byType(BusinessHome, skipOffstage: false), findsOneWidget);
    expect(find.text('Mi negocio'), findsWidgets);
    expect(find.text('Celular peruano'), findsNothing);
    expect(find.text('Contraseña'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    api.client.close();
  });
  testWidgets('Google cancelado no llama backend ni cambia sesión', (t) async {
    var calls = 0;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          calls++;
          return json({});
        }));
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GoogleAccess(api: api, tokenRequest: () async => null))));
    await t.pumpAndSettle();
    await t.tap(find.text('Continuar con Google'));
    await t.pumpAndSettle();
    expect(calls, 0);
    expect(api.authenticated, false);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Google usa sesión FINKI, dispositivo y nonce; sin teléfono ni contraseña',
      (t) async {
    Map<String, dynamic>? body;
    final store = MemoryStore();
    final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          expect(r.url.path, endsWith('/auth/google'));
          body = jsonDecode(r.body);
          return json(session());
        }));
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GoogleAccess(
                api: api, tokenRequest: () async => 'fiction-token'))));
    await t.pumpAndSettle();
    await t.tap(find.text('Continuar con Google'));
    await t.pumpAndSettle();
    expect(api.authenticated, true);
    expect(body?['nonce'], GoogleAccess.nonce);
    expect(body?.containsKey('telefono'), false);
    expect(body?.containsKey('clave'), false);
    expect(body?['dispositivo']['plataforma'], 'ANDROID');
  });
  testWidgets('sin Client IDs botón informativo cabe en pantalla pequeña',
      (t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final api = ApiClient(
        store: MemoryStore(), client: MockClient((r) async => json({})));
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(24),
                child: GoogleAccess(api: api)))));
    await t.pumpAndSettle();
    expect(t.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    expect(t.takeException(), isNull);
  });
}
