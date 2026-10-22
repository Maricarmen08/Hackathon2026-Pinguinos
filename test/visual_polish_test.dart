// UI-only fixtures: no HTTP, user accounts or database writes.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon_pinguinos_mvp/core/theme/app_theme.dart';
import 'package:hackathon_pinguinos_mvp/ui/widgets/finki_components.dart';
import 'redesign_test.dart' show capture;

void main() {
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root == null) return;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final file =
          File('$root/bin/cache/artifacts/material_fonts/${entry.value}');
      if (await file.exists()) {
        await (FontLoader(entry.key)
              ..addFont(file.readAsBytes().then(ByteData.sublistView)))
            .load();
      }
    }
  });
  for (final size in [
    const Size(320, 640),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(768, 1024),
    const Size(844, 390)
  ]) {
    testWidgets('tarjetas iguales, sin alturas rígidas a $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await t.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                  body: SafeArea(
                      child: SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: Column(children: [
                            IntrinsicHeight(
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  Expanded(
                                      child: FinkiMoneyCard(
                                          key: ValueKey('left'),
                                          label: 'Clientes te deben',
                                          value: 'S/ 0.00',
                                          icon: Icons.people_outline,
                                          fillHeight: true)),
                                  SizedBox(width: 8),
                                  Expanded(
                                      child: FinkiMoneyCard(
                                          key: ValueKey('right'),
                                          label: 'Debes pagar',
                                          value: 'S/ 0.00',
                                          icon: Icons.payments_outlined,
                                          fillHeight: true)),
                                ])),
                            SizedBox(height: 16),
                            IntrinsicHeight(
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  Expanded(
                                      child: FinkiMoneyCard(
                                          label:
                                              'Cuenta con un nombre largo para probar varias líneas',
                                          value: 'S/ 1,000,000,000,000.00',
                                          icon: Icons
                                              .account_balance_wallet_outlined,
                                          fillHeight: true)),
                                  SizedBox(width: 8),
                                  Expanded(
                                      child: FinkiMoneyCard(
                                          label: 'Pagos',
                                          value: 'S/ 40.00',
                                          icon: Icons.payments_outlined,
                                          fillHeight: true)),
                                ])),
                          ])))))));
      await t.pumpAndSettle();
      expect(t.getSize(find.byKey(const ValueKey('left'))).height,
          t.getSize(find.byKey(const ValueKey('right'))).height);
      final zero = find.text('S/ 0.00');
      expect(t.getBottomLeft(zero.at(0)).dy,
          closeTo(t.getBottomLeft(zero.at(1)).dy, .1));
      expect(t.takeException(), isNull);
      if (size.width == 390) await capture(t, key, 'polish-cards');
    });
    for (final keyboard in [false, true]) {
      testWidgets(
          'menú alineado y dentro del área segura a $size teclado=$keyboard',
          (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        t.view.padding = const FakeViewPadding(top: 24, bottom: 16);
        if (keyboard) {
          t.view.viewInsets = FakeViewPadding(bottom: size.height * .35);
        }
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPadding);
        addTearDown(t.view.resetViewInsets);
        String? selected = 'all';
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                home: Scaffold(
                    body: SafeArea(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: StatefulBuilder(
                                builder: (context, update) => Column(children: [
                                      const TextField(
                                          decoration: InputDecoration(
                                              labelText: 'Buscar concepto')),
                                      const SizedBox(height: 24),
                                      FinkiSelect(
                                          label: 'Tipo de operación',
                                          value: selected,
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'all',
                                                child: Text('Todas')),
                                            DropdownMenuItem(
                                                value: 'sale',
                                                child: Text('Ventas')),
                                            DropdownMenuItem(
                                                value: 'expense',
                                                child: Text('Gastos')),
                                            DropdownMenuItem(
                                                value: 'purchase',
                                                child: Text('Compras'))
                                          ],
                                          onChanged: (v) =>
                                              update(() => selected = v)),
                                    ]))))))));
        await t.pumpAndSettle();
        final field = t.getRect(find.byType(FinkiSelect));
        await t.tap(find.text('Todas'));
        await t.pumpAndSettle();
        final menu = t.getRect(find.byType(ClipRRect).last);
        expect(menu.left, greaterThanOrEqualTo(16));
        expect(menu.right, lessThanOrEqualTo(size.width - 16));
        expect(menu.left, closeTo(field.left, 1));
        expect(menu.right, closeTo(field.right, 1));
        expect(menu.top, greaterThanOrEqualTo(24));
        expect(
            menu.bottom,
            lessThanOrEqualTo(
                size.height - (keyboard ? size.height * .35 : 16)));
        expect(find.byIcon(Icons.check_rounded), findsWidgets);
        if (size.width == 390 && !keyboard) {
          await capture(t, key, 'polish-menu');
        }
        await t.tap(find.text('Ventas').last);
        await t.pumpAndSettle();
        expect(selected, 'sale');
        expect(t.takeException(), isNull);
      });
    }
  }
}
