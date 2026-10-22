import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/certificate_page.dart';
import 'package:hackathon_pinguinos_mvp/v1/intake_page.dart';
import 'package:hackathon_pinguinos_mvp/core/theme/app_theme.dart';
import 'widget_test.dart' show MemoryStore, session, json;

void main() {
  final today = DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 5))
      .toIso8601String()
      .substring(0, 10);
  final business = {
    'id': 'b',
    'nombre': 'Ensayo de widgets',
    'inicio_historial': today
  };
  testWidgets('constancia: resumen, confirmación del comando y opciones de PDF',
      (t) async {
    Json? sent;
    final summary = {
      'ventas_minor': '10000',
      'cobros_ventas_minor': '4000',
      'gastos_minor': '0',
      'compras_minor': '0',
      'por_cobrar_minor': '6000',
      'por_pagar_minor': '0',
      'resultado_operativo_simplificado_minor': '10000',
      'meses_completos': 0,
      'promedio_mensual_ventas_minor': null,
      'meses_con_informacion': 1
    };
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            sent = jsonDecode(r.body) as Json;
            return json({'entidades': []});
          }
          if (r.url.path.contains('/constancias/')) {
            return json({
              'pdf_base64': base64Encode('%PDF-test-widget-only'.codeUnits),
              'indicadores': summary
            });
          }
          return json(summary);
        }))
      ..session = session();
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: CertificatePage(api: api, business: business)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
        find.textContaining('Aún no hay meses completos'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Aún no hay meses completos'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Generar constancia'), 250,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Generar constancia'));
    await t.pumpAndSettle();
    expect(sent!['tipo'], 'GENERAR_CONSTANCIA');
    expect(sent!['payload']['desde'], today);
    await t.scrollUntilVisible(find.text('Abrir o descargar PDF'),150,scrollable:find.byType(Scrollable).first);
    expect(find.text('Abrir o descargar PDF'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Compartir constancia'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Compartir constancia'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Gemini muestra consentimiento y solo crea propuesta al interpretar texto',
      (t) async {
    final posts = <String>[];
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') {
            posts.add(r.url.path);
            expect(
                jsonDecode(r.body)['texto'], 'Hoy vendí 45 soles de gaseosas');
            expect(r.headers['X-Finki-Consent'], '1');
            return json({
              'id': 'proposal-test',
              'estado': 'REQUIERE_REVISION',
              'resultado': {
                'intencion': 'VENTA',
                'monto_minor': '4500',
                'concepto': 'gaseosas',
                'texto_visible': 'Venta de gaseosas',
                'fecha': today
              }
            });
          }
          if (r.url.path.endsWith('/estado')) {
            return json({'configurado': true, 'proveedor': 'Gemini'});
          }
          return json({'items': []});
        }))
      ..session = session();
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: IntakePage(
            api: api,
            business: business,
            accounts: const [],
            categories: const [],
            people: const [])));
    await t.pumpAndSettle();
    expect(find.text('Cómo se usan mis datos'), findsOneWidget);
    expect(find.textContaining('a Gemini'), findsNothing);
    expect(posts, isEmpty);
    await t.tap(find.byType(CheckboxListTile));
    await t.enterText(find.byType(TextField), 'Hoy vendí 45 soles de gaseosas');
    await t.scrollUntilVisible(find.text('Interpretar'), 200,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Interpretar'));
    await t.pumpAndSettle();
    expect(posts.length, 1);
    expect(posts.single, endsWith('/ia/analizar'));
    await t.scrollUntilVisible(find.text('Esto entendí'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Esto entendí'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'IA desactivada informa configuración y no envía audio ni imágenes',
      (t) async {
    var posts = 0;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.method == 'POST') posts++;
          return json({'configurado': false});
        }))
      ..session = session();
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: IntakePage(
            api: api,
            business: business,
            accounts: const [],
            categories: const [],
            people: const [])));
    await t.pumpAndSettle();
    expect(find.textContaining('no está disponible por ahora'), findsOneWidget);
    final button =
        t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hablar'));
    expect(button.onPressed, isNull);
    expect(posts, 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
