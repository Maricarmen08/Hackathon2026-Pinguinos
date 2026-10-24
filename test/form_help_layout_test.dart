import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/core/theme/app_theme.dart';
import 'package:hackathon_pinguinos_mvp/ui/widgets/finki_components.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/forms.dart';
import 'widget_test.dart' show MemoryStore;

void main() {
  const guidance =
      'Si queda un pago pendiente, selecciona un proveedor. Si ya pagaste, elige Pago completo.';
  const longName =
      'Proveedor de prueba con un nombre extenso para revisar el selector';
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root == null) return;
    for (final item in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final font =
          File('$root/bin/cache/artifacts/material_fonts/${item.value}');
      if (await font.exists()) {
        final loader = FontLoader(item.key)
          ..addFont(
              font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
        await loader.load();
      }
    }
  });
  for (final width in [320.0, 360.0, 400.0]) {
    for (final kind in [
      'VENTA',
      'GASTO_OPERATIVO',
      'COMPRA_MERCADERIA',
      'payment',
      'person',
      'account',
      'category'
    ]) {
      testWidgets('$kind a $width: ayuda separada, fuente ampliada y teclado',
          (t) async {
        t.view.physicalSize = Size(width, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetViewInsets);
        final api = ApiClient(
            store: MemoryStore(),
            client: MockClient(
                (_) async => throw StateError('No se permiten escrituras')));
        addTearDown(api.client.close);
        final shot = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
            key: shot,
            child: MaterialApp(
                theme: AppTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.4)),
                    child: child!),
                home: EntryForm(
                    api: api,
                    kind: kind,
                    business: const {'id': 'b'},
                    accounts: const [],
                    categories: const [],
                    people: const [
                      {'id': 'p', 'nombre': longName}
                    ],
                    row: kind == 'payment'
                        ? const {
                            'id': 'op',
                            'tipo': 'VENTA',
                            'concepto': 'Venta de ensayo',
                            'total_minor': '2000',
                            'liquidado_minor': '1000',
                            'pendiente_minor': '1000'
                          }
                        : const {'initial_mode': 'CREDITO'}))));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (kind == 'GASTO_OPERATIVO') {
          expect(find.byType(FinkiFieldHelp), findsWidgets);
          await t.scrollUntilVisible(find.text(guidance), 160,
              scrollable: find.byType(Scrollable).first);
          await t.pumpAndSettle();
          final date = find.widgetWithText(TextFormField, 'Fecha');
          await t.ensureVisible(date);
          await t.pumpAndSettle();
          expect(t.getRect(date).top - t.getRect(find.text(guidance)).bottom,
              greaterThanOrEqualTo(20));
          expect(t.widget<Text>(find.text(guidance)).maxLines, isNull);
          if (width == 360 && Platform.environment['FINKI_UI_SHOTS'] == '1') {
            await t.runAsync(() async {
              final boundary = shot.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File('build/tooling/form-help-gasto-360.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await t.scrollUntilVisible(find.text('Revisar y guardar'), 150,
              scrollable: find.byType(Scrollable).first);
          await t.drag(find.byType(Scrollable).first, const Offset(0, -100));
          await t.pumpAndSettle();
          await t.tap(find.text('Revisar y guardar'));
          await t.pumpAndSettle();
          const error =
              'Elige un proveedor para registrar lo que queda por pagar.';
          await t.scrollUntilVisible(find.text(error), -100,
              scrollable: find.byType(Scrollable).first);
          await t.pumpAndSettle();
          expect(t.getSize(find.text(error)).height, greaterThan(30));
          expect(t.takeException(), isNull);
        }
        if (['VENTA', 'GASTO_OPERATIVO', 'COMPRA_MERCADERIA'].contains(kind)) {
          final label = kind == 'VENTA' ? 'Cliente' : 'Proveedor';
          await t.scrollUntilVisible(find.text(label), -120,
              scrollable: find.byType(Scrollable).first);
          await t.pumpAndSettle();
          await t.tap(find.text(label));
          await t.pumpAndSettle();
          await t.tap(find.text(longName).last);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        t.view.viewInsets = const FakeViewPadding(bottom: 260);
        await t.pumpAndSettle();
        await t.scrollUntilVisible(find.text('Revisar y guardar'), 150,
            scrollable: find.byType(Scrollable).first);
        await t.drag(find.byType(Scrollable).first, const Offset(0, -100));
        await t.pumpAndSettle();
        expect(find.text('Revisar y guardar').hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
