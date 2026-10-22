import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/main.dart';
import 'package:hackathon_pinguinos_mvp/core/theme/app_theme.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/forms.dart';
import 'package:hackathon_pinguinos_mvp/v1/money.dart';
import 'package:hackathon_pinguinos_mvp/v1/presentation.dart';
import 'package:hackathon_pinguinos_mvp/ui/widgets/finki_brand.dart';
import 'package:hackathon_pinguinos_mvp/ui/widgets/finki_components.dart';
import 'widget_test.dart' show MemoryStore, session, json;
import 'redesign_test.dart' show capture;

Future<void> review(WidgetTester t) async {
  await t.scrollUntilVisible(find.text('Revisar y guardar'), 200,
      scrollable: find.byType(Scrollable).first);
  await t.drag(find.byType(Scrollable).first, const Offset(0, -200));
  await t.pumpAndSettle();
  await t.tap(find.text('Revisar y guardar'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('importes grandes y texto ampliado siguen legibles sin desbordar',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: ListView(children: const [
              FinkiMoneyCard(
                  label: 'Nombre de cuenta con una descripción larga',
                  value: 'S/ 1,000,000,000,000.00',
                  icon: Icons.account_balance_wallet_outlined)
            ])))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('S/ 1,000,000,000,000.00'), findsOneWidget);
  });
  testWidgets('selector largo permite desplazarse y conserva la selección',
      (t) async {
    String? value;
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, update) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: FinkiSelect(
                        label: 'Cliente',
                        value: value,
                        items: List.generate(
                            50,
                            (i) => DropdownMenuItem(
                                value: '$i', child: Text('Cliente $i'))),
                        onChanged: (next) => update(() => value = next)))))));
    await t.tap(find.text('Cliente'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Cliente 35'), 200,
        scrollable: find.byType(Scrollable).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Cliente 35').last);
    await t.pumpAndSettle();
    expect(value, '35');
    expect(t.takeException(), isNull);
  });
  setUpAll(() async {
    // Load the SDK fonts for legible optional PNG captures instead of Ahem.
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root == null) return;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final file =
          File('$root/bin/cache/artifacts/material_fonts/${entry.value}');
      if (await file.exists()) {
        final loader = FontLoader(entry.key)
          ..addFont(
              file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
        await loader.load();
      }
    }
  });

  test('presentación peruana conserva exactamente fechas y céntimos', () {
    expect(firstName('  Danny   Flores '), 'Danny');
    expect(firstName(null), '');
    expect(periodEs('2026-10-22', '2026-10-22', today: '2026-10-22'),
        'Hoy, 22 de octubre');
    expect(periodEs('2026-10-01', '2026-10-22', today: '2026-10-22'),
        'Del 1 al 22 de octubre de 2026');
    expect(periodEs('2025-12-31', '2026-01-02', today: '2026-10-22'),
        'Del 31 de diciembre de 2025 al 2 de enero de 2026');
    expect(soles('100000000000000'), 'S/ 1,000,000,000,000.00');
    expect(soles('-123456'), '-S/ 1,234.56');
  });
  testWidgets(
      'venta sin categoría guarda una sola operación y refresca los indicadores',
      (t) async {
    final store = MemoryStore();
    await store.write('session', jsonEncode(session()));
    bool saved = false;
    final writes = <Json>[];
    final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          if (r.method == 'POST') {
            expect(r.url.path, endsWith('/negocios/b/operaciones'));
            writes.add(jsonDecode(r.body) as Json);
            saved = true;
            return json({'replayed': false}, 201);
          }
          if (r.url.path.endsWith('/auth/me')) {
            return json({
              'usuario': {'nombre': 'Prueba aislada'},
              'negocios': [
                {
                  'id': 'b',
                  'nombre': 'Negocio aislado',
                  'rol': 'PROPIETARIO',
                  'inicio_historial': '2026-10-22'
                }
              ]
            });
          }
          if (r.url.path.endsWith('/indicadores')) {
            return json({
              'desde': '2026-10-22',
              'hasta': '2026-10-22',
              'ventas_minor': saved ? '10000' : '0',
              'cobros_ventas_minor': saved ? '10000' : '0',
              'pagos_operativos_minor': '0',
              'por_cobrar_minor': '0',
              'por_pagar_minor': '0',
              'cuentas': [
                {
                  'id': 'cash',
                  'nombre': 'Caja',
                  'tipo': 'EFECTIVO',
                  'saldo_registrado_minor': saved ? '10000' : '0'
                }
              ]
            });
          }
          return json({'items': [], 'next_offset': null});
        }));
    await t.pumpWidget(PinguinosAiApp(api: api));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Venta'));
    await t.pumpAndSettle();
    await t.tap(find.text('Venta'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextFormField, '¿Qué vendiste o pagaste?'),
        'Venta aislada');
    await t.enterText(
        find.widgetWithText(TextFormField, 'Importe total'), '100');
    await review(t);
    await t.tap(find.text('Confirmar'));
    await t.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(writes.single['payload']['operacion']['categoria_id'], isNull);
    expect(
        writes.single['payload']['pagos_iniciales'][0]['monto_minor'], '10000');
    expect(find.text('S/ 100.00'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('editar negocio usa versión y comando existente sin recrearlo',
      (t) async {
    Json? sent;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          expect(r.url.path, endsWith('/negocios/b/comandos'));
          sent = jsonDecode(r.body) as Json;
          return json({'replayed': false}, 201);
        }))
      ..session = session();
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: EntryForm(api: api, kind: 'businessEdit', business: const {
          'id': 'b',
          'nombre': 'Nombre anterior',
          'rubro': 'Bodega',
          'version': '7'
        }, accounts: const [], categories: const [], people: const [])));
    expect(find.text('Nombre anterior'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).first, 'Nombre actualizado');
    await review(t);
    await t.tap(find.text('Confirmar'));
    await t.pumpAndSettle();
    expect(sent?['tipo'], 'ACTUALIZAR_NEGOCIO');
    expect(sent?['payload'], {
      'expected_version': '7',
      'nombre': 'Nombre actualizado',
      'rubro': 'Bodega'
    });
  });
  testWidgets('sobreabono se rechaza antes de enviar y conserva el importe',
      (t) async {
    int writes = 0;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          writes++;
          return json({});
        }))
      ..session = session();
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: EntryForm(api: api, kind: 'payment', business: const {
          'id': 'b'
        }, row: const {
          'id': 'o',
          'tipo': 'VENTA',
          'concepto': 'Venta',
          'total_minor': '10000',
          'liquidado_minor': '4000',
          'pendiente_minor': '6000'
        }, accounts: const [
          {'id': 'c', 'nombre': 'Caja'}
        ], categories: const [], people: const [])));
    await t.enterText(
        find.widgetWithText(TextFormField, 'Monto del abono'), '61');
    await review(t);
    expect(find.text('El abono no puede superar el saldo pendiente.'),
        findsOneWidget);
    expect(writes, 0);
    expect(
        (t.widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Monto del abono')))
            .controller!
            .text,
        '61');
  });
  for (final width in [320.0, 360.0, 390.0, 412.0, 768.0]) {
    testWidgets('vacíos completos, acceso fiado y final de scroll a $width px',
        (t) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = MemoryStore();
      await store.write('session', jsonEncode(session()));
      final api = ApiClient(
          store: store,
          client: MockClient((r) async {
            if (r.url.path.endsWith('/auth/me')) {
              return json({
                'usuario': {'nombre': 'Nombre Dinámico'},
                'negocios': [
                  {
                    'id': 'b',
                    'nombre': 'Negocio aislado',
                    'rubro': 'Bodega',
                    'rol': 'PROPIETARIO',
                    'version': '1',
                    'inicio_historial': '2026-10-22'
                  }
                ]
              });
            }
            if (r.url.path.endsWith('/indicadores')) {
              return json({
                'desde': '2026-10-22',
                'hasta': '2026-10-22',
                'ventas_minor': '0',
                'cobros_ventas_minor': '0',
                'pagos_operativos_minor': '0',
                'por_cobrar_minor': '0',
                'por_pagar_minor': '0',
                'cuentas': []
              });
            }
            return json({'items': [], 'next_offset': null});
          }));
      final key = GlobalKey();
      await t.pumpWidget(
          RepaintBoundary(key: key, child: PinguinosAiApp(api: api)));
      await t.pumpAndSettle();
      expect(find.text('¡Hola, Nombre!'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Hablar con Finki'), 240,
          scrollable: find.byType(Scrollable).first);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await t.pumpAndSettle();
      expect(t.getBottomLeft(find.text('Hablar con Finki')).dy,
          lessThan(t.getTopLeft(find.byType(NavigationBar)).dy));
      if (width == 390) await capture(t, key, 'v2-home-bottom');
      await t.tap(find.text('Fiados'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Registrar una venta fiada'), 160,
          scrollable: find.byType(Scrollable).first);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await t.pumpAndSettle();
      expect(find.byType(FinkiMascot), findsWidgets);
      if (width == 390) await capture(t, key, 'v2-empty-fiados');
      await t.tap(find.text('Registrar una venta fiada'));
      await t.pumpAndSettle();
      expect(find.text('Fiado · sin abono'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
