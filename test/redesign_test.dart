// Isolated presentation fixtures. This suite never connects to MySQL or Express.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/main.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/forms.dart';
import 'package:hackathon_pinguinos_mvp/v1/app.dart';
import 'package:hackathon_pinguinos_mvp/core/theme/app_theme.dart';
import 'widget_test.dart' show MemoryStore, session, json;

const business = {
  'id': 'isolated-business',
  'nombre': 'Negocio de prueba visual',
  'rol': 'PROPIETARIO',
  'inicio_historial': '2026-07-01'
};
const operation = {
  'id': 'isolated-operation',
  'tipo': 'VENTA',
  'concepto': 'Venta de prueba visual',
  'total_minor': '10000',
  'liquidado_minor': '4000',
  'pendiente_minor': '6000',
  'fecha_operacion': '2026-10-22',
  'estado': 'CONFIRMADO',
  'tercero_id': 'isolated-person'
};
const accounts = [
  {
    'id': 'isolated-cash',
    'nombre': 'Caja',
    'tipo': 'EFECTIVO',
    'saldo_registrado_minor': '4000'
  }
];
const people = [
  {'id': 'isolated-person', 'nombre': 'Cliente de prueba visual'}
];
const categories = [
  {'id': 'sale', 'nombre': 'Ventas', 'tipo': 'VENTA'},
  {'id': 'expense', 'nombre': 'Servicios', 'tipo': 'GASTO_OPERATIVO'},
  {'id': 'purchase', 'nombre': 'Mercadería', 'tipo': 'COMPRA_MERCADERIA'},
];

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_FINKI')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/tooling/redesign-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final register in [false, true]) {
    testWidgets(
        'formulario público ${register ? 'registro' : 'login'} conserva contrato y errores de API',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Json? body;
      String? path;
      final api = ApiClient(
          store: MemoryStore(),
          client: MockClient((r) async {
            path = r.url.path;
            body = jsonDecode(r.body) as Json;
            return json({
              'error': {
                'code': 'TEST_REJECTION',
                'message': 'Respuesta aislada de prueba'
              }
            }, register ? 422 : 401);
          }));
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: AuthPage(api: api))));
      await tester.pumpAndSettle();
      await tester.tap(find.text(register ? 'Comenzar' : 'Ya tengo cuenta'));
      await tester.pumpAndSettle();
      await capture(tester, key, register ? 'registro' : 'login');
      if (register) {
        await tester.enterText(
            find.widgetWithText(TextFormField, 'Tu nombre'), 'Usuario aislado');
      }
      await tester.enterText(
          find.widgetWithText(
              TextFormField, register ? 'Celular peruano' : 'Celular o correo'),
          '999999999');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'),
          'clave-solo-prueba-visual');
      final submit = find.byKey(const ValueKey('auth-submit'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(path, endsWith(register ? '/auth/registro' : '/auth/login'));
      expect(body?[register ? 'telefono' : 'usuario'], '999999999');
      expect(body?['clave'], 'clave-solo-prueba-visual');
      expect(find.text('Respuesta aislada de prueba'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
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
  for (final size in [
    const Size(320, 640),
    const Size(360, 800),
    const Size(412, 915),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1280, 900)
  ]) {
    testWidgets('navegación privada y reportes sin overflow a ${size.width}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore();
      await store.write('session', jsonEncode(session()));
      final api = ApiClient(
          store: store,
          client: MockClient((request) async {
            expect(request.method, 'GET');
            final path = request.url.path;
            if (path.endsWith('/auth/me')) {
              return json({
                'usuario': {
                  'nombre': 'Usuario de prueba visual',
                  'telefono': '999999999'
                },
                'negocios': [business]
              });
            }
            if (path.endsWith('/indicadores')) {
              return json({
                'desde': '2026-07-01',
                'hasta': '2026-10-22',
                'ventas_minor': '10000',
                'gastos_minor': '0',
                'compras_minor': '0',
                'cobros_ventas_minor': '4000',
                'pagos_operativos_minor': '0',
                'por_cobrar_minor': '6000',
                'por_pagar_minor': '0',
                'resultado_operativo_simplificado_minor': '10000',
                'promedio_mensual_ventas_minor': '3333',
                'meses_completos': 3,
                'meses_historial': 3,
                'dias_con_ventas': 1,
                'cuentas': accounts,
                'ventas_mensuales': [
                  {'mes': '2026-07', 'ventas_minor': '10000'},
                  {'mes': '2026-08', 'ventas_minor': '0'},
                  {'mes': '2026-09', 'ventas_minor': '0'}
                ],
              });
            }
            if (path.endsWith('/categorias')) {
              return json({'items': categories, 'next_offset': null});
            }
            if (path.endsWith('/terceros')) {
              return json({'items': people, 'next_offset': null});
            }
            if (path.contains('/operaciones/')) return json(operation);
            return json({
              'items': [operation],
              'next_offset': null
            });
          }));
      final key = GlobalKey();
      await tester.pumpWidget(
          RepaintBoundary(key: key, child: PinguinosAiApp(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('S/ 100.00'), findsWidgets);
      await capture(tester, key, 'home-${size.width.toInt()}');
      expect(tester.takeException(), isNull);
      for (final label in ['Historial', 'Fiados', 'Reportes', 'Perfil']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width == 390) await capture(tester, key, label.toLowerCase());
        if (label == 'Fiados') {
          expect(find.text('Pendiente S/ 60.00'), findsOneWidget);
          expect(find.text('Abonado S/ 40.00'), findsOneWidget);
          await tester.ensureVisible(find.text('Registrar abono'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Registrar abono'));
          await tester.pumpAndSettle();
          expect(find.text('Pendiente: S/ 60.00'), findsOneWidget);
          if (size.width == 390) await capture(tester, key, 'detalle');
          await tester.tapAt(const Offset(10, 90));
          await tester.pumpAndSettle();
        }
      }
    });
  }
  for (final kind in [
    'business',
    'account',
    'category',
    'person',
    'VENTA',
    'GASTO_OPERATIVO',
    'COMPRA_MERCADERIA',
    'payment'
  ]) {
    testWidgets('formulario $kind cabe en teléfono y admite scroll con teclado',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ApiClient(
          store: MemoryStore(),
          client: MockClient((_) async => throw StateError(
              'No se autorizan escrituras en revisión visual')));
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: EntryForm(
                  api: api,
                  kind: kind,
                  business: business,
                  row: operation,
                  accounts: accounts,
                  categories: categories,
                  people: people))));
      await tester.pumpAndSettle();
      if (['VENTA', 'payment', 'business'].contains(kind)) {
        await capture(tester, key, 'form-$kind');
      }
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Revisar y guardar'), 160,
          scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(find.text('Revisar y guardar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    });
  }
}
