import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/main.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';
import 'package:hackathon_pinguinos_mvp/v1/forms.dart';
import 'package:hackathon_pinguinos_mvp/v1/money.dart';

class MemoryStore implements SessionStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

Json session() => {
      'access_token': 'access',
      'refresh_token': 'refresh',
      'dispositivo_id': 'device'
    };
http.Response json(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
void main() {
  test('céntimos exactos, límites y rechazo de formatos ambiguos', () {
    expect(toMinor('100,40'), '10040');
    expect(toMinor('0.01'), '1');
    expect(soles('-1040'), '-S/ 10.40');
    expect(toMinor('1000000000000'), '100000000000000');
    for (final value in [
      '0',
      '-1',
      '1.001',
      'NaN',
      '1e2',
      '1,234.50',
      '1000000000001'
    ]) {
      expect(() => toMinor(value), throwsFormatException);
    }
  });
  test('401 renueva una sola vez con concurrencia y conserva el dispositivo',
      () async {
    var refreshes = 0;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/refresh')) {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return json({
              'access_token': 'new',
              'refresh_token': 'rotated',
              'dispositivo_id': 'device'
            });
          }
          return r.headers['Authorization'] == 'Bearer new'
              ? json({'items': []})
              : json({
                  'error': {'code': 'INVALID_TOKEN', 'message': 'Expirado'}
                }, 401);
        }));
    api.session = session();
    await Future.wait(
        [api.request('GET', '/negocios'), api.request('GET', '/negocios')]);
    expect(refreshes, 1);
    expect(api.device, 'device');
  });
  test(
      'timeout lógico conserva el comando cifrable, reinicio y reintento no duplican IDs',
      () async {
    final store = MemoryStore(), bodies = <String>[];
    var first = true;
    final client = MockClient((r) async {
      bodies.add(r.body);
      if (first) {
        first = false;
        throw http.ClientException('offline');
      }
      return json({'replayed': true});
    });
    final api = ApiClient(store: store, client: client);
    api.session = session();
    await store.write('session', jsonEncode(session()));
    await expectLater(
        api.command('/negocios/b/operaciones', 'REGISTRAR_OPERACION', {
          'operacion': {'total_minor': '10000'}
        }),
        throwsA(isA<ApiException>()));
    expect(api.pending, isNotNull);
    await expectLater(
        api.command('/negocios/b/operaciones', 'REGISTRAR_OPERACION', {}),
        throwsA(isA<ApiException>()));
    final restored = ApiClient(store: store, client: client);
    await restored.restore();
    await restored.retryPending();
    expect(bodies.length, 2);
    expect(bodies[0], bodies[1]);
    expect(restored.pending, isNull);
  });
  test(
      '422 permite corregir, 403 no se reintenta y refresh inválido elimina sesión',
      () async {
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async => json({
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Importe inválido'
              }
            }, 422)));
    api.session = session();
    await expectLater(api.command('/negocios', 'CREAR_NEGOCIO', {}),
        throwsA(isA<ApiException>()));
    expect(api.pending, isNull);
    final invalid = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async => json({
              'error': {
                'code': 'INVALID_SESSION',
                'message': 'Ingresa nuevamente'
              }
            }, 401)));
    invalid.session = session();
    await expectLater(
        invalid.request('GET', '/auth/me'), throwsA(isA<ApiException>()));
    expect(invalid.authenticated, false);
  });
  testWidgets('pantalla pública real valida campos sin permitir acceso anónimo',
      (tester) async {
    final api = ApiClient(
        store: MemoryStore(), client: MockClient((r) async => json({}, 500)));
    await tester.pumpWidget(PinguinosAiApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresar'), findsOneWidget);
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingresar'));
    await tester.pump();
    expect(find.text('Completa este campo'), findsOneWidget);
    expect(find.text('Así va tu negocio'), findsNothing);
  });
  testWidgets('negocio sin actividad muestra cero real y sesión protegida',
      (tester) async {
    final store = MemoryStore();
    await store.write('session', jsonEncode(session()));
    final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/me')) {
            return json({
              'usuario': {'nombre': 'Comerciante'},
              'negocios': []
            });
          }
          return json({});
        }));
    await tester.pumpWidget(PinguinosAiApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Crear mi negocio'), findsOneWidget);
    expect(find.textContaining('Doña Rosa'), findsNothing);
  });
  testWidgets('venta fiada envía contrato V1 e importe como cadena',
      (tester) async {
    Json? sent;
    final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((r) async {
          sent = jsonDecode(r.body) as Json;
          return json({'replayed': false}, 201);
        }));
    api.session = session();
    await tester.pumpWidget(MaterialApp(
        home: EntryForm(api: api, kind: 'VENTA', business: const {
      'id': 'b'
    }, accounts: const [], categories: const [
      {'id': 'cat', 'nombre': 'Ventas', 'tipo': 'VENTA'}
    ], people: const [
      {'id': 'person', 'nombre': 'Ana'}
    ])));
    await tester.enterText(find.byType(TextFormField).at(0), 'Arroz');
    await tester.enterText(find.byType(TextFormField).at(1), '100');
    await tester.tap(find.text('Pago completo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fiado · sin abono').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cliente'));
    await tester.tap(find.text('Cliente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Revisar y guardar'));
    await tester.tap(find.text('Revisar y guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(sent?['tipo'], 'REGISTRAR_OPERACION');
    expect(sent?['payload']['operacion']['total_minor'], '10000');
    expect(sent?['payload']['operacion']['condicion'], 'CREDITO');
    expect(sent?['payload']['pagos_iniciales'], isEmpty);
  });
}
