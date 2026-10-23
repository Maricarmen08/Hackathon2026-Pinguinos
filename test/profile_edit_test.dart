import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/profile_edit_page.dart';
import 'widget_test.dart' show MemoryStore, session, json;

void main() {
  for (final status in [200, 409]) {
    testWidgets(
        'editar perfil usa PATCH autenticado y versión; respuesta $status',
        (t) async {
      var requests = 0;
      final api = ApiClient(
          store: MemoryStore(),
          client: MockClient((r) async {
            requests++;
            expect(r.method, 'PATCH');
            expect(r.url.path.endsWith('/perfil'), true);
            expect(r.headers['Authorization'] ?? r.headers['authorization'],
                startsWith('Bearer '));
            expect(jsonDecode(r.body), {
              'expected_version': '7',
              'nombre': 'Ana Nueva',
              'telefono': '+51987654321',
              'correo': null
            });
            return json(
                status == 200
                    ? {'usuario': {}}
                    : {
                        'error': {
                          'code': 'VERSION_CONFLICT',
                          'message': 'Versión desactualizada'
                        }
                      },
                status);
          }))
        ..session = session();
      await t.pumpWidget(MaterialApp(
          home: Builder(
              builder: (c) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          c,
                          MaterialPageRoute(
                              builder: (_) => ProfileEditPage(
                                      api: api,
                                      profile: const {
                                        'nombre': 'Ana',
                                        'telefono': '+51987654321',
                                        'version': '7'
                                      }))),
                      child: const Text('Abrir'))))));
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Ana Nueva');
      await t.ensureVisible(find.text('Guardar cambios'));
      await t.tap(find.text('Guardar cambios'));
      await t.pumpAndSettle();
      expect(requests, 1);
      if (status == 200) {
        expect(find.text('Abrir'), findsOneWidget);
      } else {
        expect(find.textContaining('Vuelve al perfil'), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  }
}
