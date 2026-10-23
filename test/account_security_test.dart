import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hackathon_pinguinos_mvp/v1/account_security_page.dart';
import 'package:hackathon_pinguinos_mvp/v1/profile_photo_page.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/ui/widgets/finki_brand.dart';
import 'widget_test.dart' show MemoryStore, session, json;

void main() {
  for (final origin in [ImageSource.camera, ImageSource.gallery]) {
    testWidgets(
        'foto $origin previsualiza, confirma, normaliza y conserva caché privada',
        (t) async {
      final source = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMQkdP4DwAB/gFaQ7UOogAAAABJRU5ErkJggg==');
      var writes = 0;
      String? stored;
      final store = MemoryStore();
      final api = ApiClient(
          store: store,
          client: MockClient((r) async {
            if (r.method == 'PUT') {
              writes++;
              final bytes = r.bodyBytes;
              expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
              expect(bytes[18] * 256 + bytes[19], 256);
              expect(bytes[22] * 256 + bytes[23], 256);
              stored = base64Encode(bytes);
              return json({'ok': true});
            }
            return json({'imagen_base64': stored});
          }))
        ..session = {
          ...session(),
          'usuario': {'id': 'fixture'}
        };
      await t.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      child: const Text('Abrir foto'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProfilePhotoPage(
                                  api: api,
                                  selectImage: (selected) async {
                                    expect(selected, origin);
                                    return XFile.fromData(source,
                                        mimeType: 'image/png',
                                        name: 'ficticia.png');
                                  }))))))));
      await t.tap(find.text('Abrir foto'));
      await t.pumpAndSettle();
      await t.tap(find.text(origin == ImageSource.camera
          ? 'Tomar fotografía'
          : 'Elegir de la galería'));
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Confirmar y guardar fotografía'), findsOneWidget);
      await t.ensureVisible(find.text('Confirmar y guardar fotografía'));
      await t.tap(find.text('Confirmar y guardar fotografía'));
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pumpAndSettle();
      expect(writes, 1);
      expect(stored, isNotNull);
      await t.runAsync(() async {
        final file = File('build/tooling/profile-normalized-test.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(base64Decode(stored!));
      });
      expect(store.values['cache:fixture:/perfil/foto'], contains(stored!));
      expect(find.text('Abrir foto'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  for (final width in [320.0, 714.0]) {
    testWidgets('logo completo proporcional en cabecera de $width', (t) async {
      t.view.physicalSize = Size(width, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              appBar: AppBar(
                  title: const FinkiBrandHeader(
                      subtitle: 'Nombre de negocio muy largo')))));
      final image = t.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName,
          'assets/branding/finki_logo_display.png');
      expect(image.fit, BoxFit.contain);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'contraseña valida coincidencia, conserva formulario ante error y envía contrato',
      (t) async {
    var calls = 0;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          calls++;
          expect(r.url.path.endsWith('/perfil/contrasena'), true);
          expect(jsonDecode(r.body), {
            'actual': 'Anterior-2026!',
            'nueva': 'Nueva-segura-2026!',
            'confirmacion': 'Nueva-segura-2026!'
          });
          return json({
            'error': {
              'code': 'WRONG_PASSWORD',
              'message': 'La contraseña actual no es correcta'
            }
          }, 422);
        }))
      ..session = session();
    await t.pumpWidget(MaterialApp(home: AccountSecurityPage(api: api)));
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'Anterior-2026!');
    await t.enterText(fields.at(1), 'corta');
    await t.enterText(fields.at(2), 'Distinta-segura-2026!');
    await t.tap(find.text('Guardar contraseña'));
    await t.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    await t.enterText(fields.at(1), 'Nueva-segura-2026!');
    await t.enterText(fields.at(2), 'Nueva-segura-2026!');
    await t.ensureVisible(find.text('Guardar contraseña'));
    await t.tap(find.text('Guardar contraseña'));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('La contraseña actual no es correcta'), findsOneWidget);
    expect(t.widget<TextFormField>(fields.first).controller!.text,
        'Anterior-2026!');
    await t.tap(find.byTooltip('Mostrar contraseña').first);
    await t.pump();
    expect(
        t.widget<TextField>(find.byType(TextField).first).obscureText, false);
  });
  testWidgets(
      'foto offline usa caché del usuario y avisa; sin escritura automática',
      (t) async {
    final store = MemoryStore();
    store.values['cache:ana:/perfil/foto'] =
        jsonEncode({'imagen_base64': null});
    var calls = 0;
    final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          calls++;
          expect(r.method, 'GET');
          throw http.ClientException('offline');
        }))
      ..session = {
        ...session(),
        'usuario': {'id': 'ana'}
      }
      ..offline = true;
    await t.pumpWidget(MaterialApp(home: ProfilePhotoPage(api: api)));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Sin conexión: ves la última fotografía'),
        findsOneWidget);
    expect(
        t
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Elegir de la galería'))
            .onPressed,
        isNull);
    expect(t.takeException(), isNull);
    // Another account cannot read Ana's cached avatar through ApiClient.
    api.session = {
      ...session(),
      'usuario': {'id': 'bob'}
    };
    await expectLater(
        api.request('GET', '/perfil/foto'), throwsA(isA<ApiException>()));
  });
}
