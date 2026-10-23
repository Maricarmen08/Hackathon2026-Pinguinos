import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/app.dart';
import 'package:hackathon_pinguinos_mvp/v1/daily_sales.dart';
import 'widget_test.dart' show MemoryStore, session, json;

Json snapshot(String business, {bool yesterday = false}) {
  final now = DateTime.now().toUtc().subtract(const Duration(hours: 5));
  final local = DateTime.utc(now.year, now.month, now.day)
      .subtract(Duration(days: yesterday ? 1 : 0));
  final day = local.toIso8601String().substring(0, 10),
      start = local.add(const Duration(hours: 5));
  return {
    'negocio_id': business,
    'fecha': day,
    'desde': day,
    'hasta': day,
    'ventas_minor': business == 'a' ? '7000' : '8000',
    'vigente_desde_utc': start.toIso8601String(),
    'vigente_hasta_utc': start.add(const Duration(days: 1)).toIso8601String()
  };
}

void main() {
  test(
      'caché valida negocio y límites inclusivo/exclusivo, sin trasladar cifras al día siguiente',
      () {
    final r = snapshot('a');
    final s = DailySales.parse(r, 'a')!;
    expect(s.isToday(s.start), true);
    expect(s.isToday(s.end.subtract(const Duration(milliseconds: 1))), true);
    expect(s.isToday(s.end), false);
    expect(s.isToday(s.start.subtract(const Duration(milliseconds: 1))), false);
    expect(DailySales.parse(r, 'b'), null);
    expect(DailySales.parse({...r, 'ventas_minor': null}, 'a'), null);
    expect(DailySales.parse({...r, 'hasta': '2000-01-01'}, 'a'), null);
  });
  testWidgets(
      'Inicio consulta ventas diarias y offline no inventa cero ni reutiliza ayer',
      (t) async {
    final store = MemoryStore();
    var offline = false;
    var dailyGets = 0;
    final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          expect(r.method, 'GET');
          if (offline) throw http.ClientException('offline');
          if (r.url.path == '/api/v1/auth/me') {
            return json({
              'usuario': {'id': 'u', 'nombre': 'Persona Prueba'},
              'negocios': [
                {
                  'id': 'a',
                  'nombre': 'Negocio A',
                  'rol': 'PROPIETARIO',
                  'inicio_historial': '2026-01-01'
                }
              ]
            });
          }
          if (r.url.path.endsWith('/ventas/hoy')) {
            dailyGets++;
            return json(snapshot('a'));
          }
          if (r.url.path.endsWith('/indicadores')) {
            return json({'cuentas': [], 'ventas_minor': '16000'});
          }
          return json({'items': [], 'next_offset': null, 'entidades': []});
        }))
      ..session = {
        ...session(),
        'usuario': {'id': 'u'}
      };
    await t.pumpWidget(MaterialApp(home: BusinessHome(api: api)));
    await t.pumpAndSettle();
    expect(find.text('Ventas de hoy'), findsOneWidget);
    expect(find.text('S/ 70.00'), findsOneWidget);
    expect(find.text('S/ 160.00'), findsNothing);
    expect(dailyGets, 1);
    offline = true;
    await t.tap(find.byIcon(Icons.refresh));
    await t.pumpAndSettle();
    expect(find.text('S/ 70.00'), findsOneWidget);
    expect(
        find.textContaining('Sin conexión · Datos guardados'), findsOneWidget);
    store.values['cache:u:/negocios/a/ventas/hoy'] =
        jsonEncode(snapshot('a', yesterday: true));
    await t.tap(find.byIcon(Icons.refresh));
    await t.pumpAndSettle();
    expect(find.text('Sin datos de hoy'), findsOneWidget);
    expect(find.textContaining('Último dato:'), findsOneWidget);
    expect(find.text('S/ 70.00'), findsNothing);
    store.values.remove('cache:u:/negocios/a/ventas/hoy');
    await t.tap(find.byIcon(Icons.refresh));
    await t.pumpAndSettle();
    expect(find.text('Sin datos de hoy'), findsOneWidget);
    expect(
        find.text('Conecta para consultar las ventas de hoy.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'cambiar negocio recarga la cifra diaria sin mostrar el otro negocio',
      (t) async {
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) {
            return json({
              'usuario': {'id': 'u', 'nombre': 'Persona Prueba'},
              'negocios': [
                for (final id in ['a', 'b'])
                  {
                    'id': id,
                    'nombre': 'Negocio ${id.toUpperCase()}',
                    'rol': 'PROPIETARIO',
                    'inicio_historial': '2026-01-01'
                  }
              ]
            });
          }
          if (r.url.path.endsWith('/ventas/hoy')) {
            return json(snapshot(r.url.path.contains('/a/') ? 'a' : 'b'));
          }
          if (r.url.path.endsWith('/indicadores')) {
            return json({'cuentas': [], 'ventas_minor': '99999'});
          }
          return json({'items': [], 'next_offset': null, 'entidades': []});
        }))
      ..session = {
        ...session(),
        'usuario': {'id': 'u'}
      };
    await t.pumpWidget(MaterialApp(home: BusinessHome(api: api)));
    await t.pumpAndSettle();
    expect(find.text('S/ 70.00'), findsOneWidget);
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Negocio B'));
    await t.pumpAndSettle();
    expect(find.text('S/ 80.00'), findsOneWidget);
    expect(find.text('S/ 70.00'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
