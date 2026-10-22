import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/main.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'widget_test.dart' show MemoryStore, session, json;

void main() {
  testWidgets(
      'inicio de teléfono, historial y pendientes vacíos provienen de la API',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    await store.write('session', jsonEncode(session()));
    final paths = <String>[];
    final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          paths.add(r.url.toString());
          if (r.url.path.endsWith('/auth/me')) {
            return json({
              'usuario': {'nombre': 'Usuario de prueba'},
              'negocios': [
                {
                  'id': 'business',
                  'nombre': 'Negocio de prueba',
                  'rol': 'PROPIETARIO',
                  'inicio_historial': '2026-10-22'
                }
              ]
            });
          }
          if (r.url.path.endsWith('/indicadores')) {
            return json({
              'ventas_minor': '0',
              'por_cobrar_minor': '0',
              'por_pagar_minor': '0',
              'resultado_operativo_simplificado_minor': '0',
              'cuentas': [],
              'promedio_mensual_ventas_minor': null,
              'meses_completos': 0,
              'dias_con_ventas': 0
            });
          }
          return json({'items': [], 'next_offset': null});
        }));
    await tester.pumpWidget(PinguinosAiApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Así va tu negocio'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes movimientos'), findsOneWidget);
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gastos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos los estados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmado').last);
    await tester.pumpAndSettle();
    expect(paths.any((p) => p.contains('tipo=GASTO_OPERATIVO') && p.contains('estado=CONFIRMADO')), true);
    expect(find.text('Sin coincidencias'), findsOneWidget);
    await tester.tap(find.text('Fiados'));
    await tester.pumpAndSettle();
    expect(find.text('Me deben'), findsOneWidget);
    expect(
        paths.any((p) =>
            p.contains('/pendientes?') && p.contains('direccion=COBRAR')),
        true);
    expect(tester.takeException(), isNull);
  });
}
