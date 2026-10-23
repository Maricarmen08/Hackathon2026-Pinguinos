import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/certificate_page.dart';
import 'package:hackathon_pinguinos_mvp/v1/money.dart';
import 'widget_test.dart' show MemoryStore, session, json;

void main() {
  testWidgets(
      'Hoy no hereda inicio del historial; presets y PDF usan mismo periodo',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final today = limaToday(), requests = <Map<String, String>>[];
    Json? command;
    final summary = <String, dynamic>{
      'ventas_minor': '7000',
      'cobros_ventas_minor': '6000',
      'gastos_minor': '1200',
      'compras_minor': '8000',
      'por_cobrar_minor': '1000',
      'por_pagar_minor': '5000',
      'resultado_operativo_simplificado_minor': '-2200',
      'meses_completos': 0,
      'meses_con_informacion': 1,
      'promedio_mensual_ventas_minor': null
    };
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            command = jsonDecode(r.body) as Json;
            return json({'entidades': []});
          }
          if (r.url.path.endsWith('/indicadores')) {
            requests.add(r.url.queryParameters);
            return json({...summary, ...r.url.queryParameters});
          }
          if (r.url.path.contains('/constancias/')) {
            return json({
              'pdf_base64': base64Encode('%PDF-fixture'.codeUnits),
              'indicadores': {...summary, ...requests.last}
            });
          }
          return json({'items': []});
        }))
      ..session = session();
    await t.pumpWidget(MaterialApp(
        home: CertificatePage(
            api: api,
            business: const {'id': 'b', 'inicio_historial': '2025-01-01'})));
    await t.pumpAndSettle();
    expect(requests.last['desde'], today);
    expect(requests.last['hasta'], today);
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    await t.tap(find.text('Últimos 7 días'));
    await t.pumpAndSettle();
    expect(
        requests.last['desde'],
        DateTime.parse(today)
            .subtract(const Duration(days: 6))
            .toIso8601String()
            .substring(0, 10));
    await t.tap(find.text('Este mes'));
    await t.pumpAndSettle();
    expect(requests.last['desde'], '${today.substring(0, 7)}-01');
    await t.scrollUntilVisible(find.text('Generar constancia'), 200,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Generar constancia'));
    await t.pumpAndSettle();
    expect(command!['payload']['desde'], requests.last['desde']);
    expect(command!['payload']['hasta'], today);
    expect(t.takeException(), isNull);
  });
}
