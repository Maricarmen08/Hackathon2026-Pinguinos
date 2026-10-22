import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hackathon_pinguinos_mvp/v1/api_client.dart';

// Persistent test adapter. Production uses encrypted FlutterSecureStorage.
class DiskStore implements SessionStore {
  final Directory directory;
  DiskStore(this.directory);
  File file(String key) =>
      File('${directory.path}/${base64Url.encode(utf8.encode(key))}');
  @override
  Future<String?> read(String key) async =>
      await file(key).exists() ? file(key).readAsString() : null;
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      if (await file(key).exists()) await file(key).delete();
    } else {
      await file(key).writeAsString(value, flush: true);
    }
  }
}

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('finki-v3-offline-');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  Json session(String user) => {
        'usuario': {'id': user},
        'dispositivo_id': 'device',
        'access_token': 'access',
        'refresh_token': 'refresh'
      };
  test(
      'datos locales persisten al reconstruir cliente; aislamiento y respuesta perdida conservan ID',
      () async {
    final store = DiskStore(dir);
    await store.write('session', jsonEncode(session('alice')));
    var connected = true, lost = false;
    final ids = <String>{};
    final client = MockClient((r) async {
      if (!connected) throw http.ClientException('sin red');
      if (r.method == 'GET') {
        return http.Response(jsonEncode({'ventas_minor': '10000'}), 200);
      }
      final id = (jsonDecode(r.body) as Map)['command_id'] as String;
      ids.add(id);
      if (lost) {
        lost = false;
        throw http.ClientException('respuesta perdida después del guardado');
      }
      return http.Response(jsonEncode({'replayed': true}), 200);
    });
    final api = ApiClient(client: client, store: store);
    await api.restore();
    await api.request('GET', '/negocios/business/indicadores');
    connected = false;
    expect(
        (await api.request(
            'GET', '/negocios/business/indicadores'))['ventas_minor'],
        '10000');
    expect(api.offline, true);
    final first = await api
        .command('/negocios/business/comandos', 'REGISTRAR_OPERACION', {
      'operacion': {'total_minor': '10000'}
    });
    expect(first['local'], true);
    await api.command('/negocios/another/comandos', 'REGISTRAR_COBRO', {
      'movimiento': {'monto_minor': '4000'}
    });
    expect(api.localEntries.length, 2);
    final restarted = ApiClient(client: client, store: DiskStore(dir));
    await restarted.restore();
    expect(restarted.localEntries.length, 2);
    expect(restarted.localEntries.first['body']['command_id'],
        first['command_id']);
    restarted.session = session('bob');
    expect(restarted.localEntries, isEmpty);
    await expectLater(
        restarted.request('GET', '/negocios/business/indicadores'),
        throwsA(isA<ApiException>()));
    restarted.session = session('alice');
    connected = true;
    lost = true;
    await expectLater(restarted.syncLocal(), throwsA(isA<ApiException>()));
    expect(restarted.localEntries.length, 2);
    await restarted.syncLocal();
    expect(restarted.localEntries, isEmpty);
    expect(ids.length, 2);
    final finalClient = ApiClient(client: client, store: DiskStore(dir));
    await finalClient.restore();
    expect(finalClient.localEntries, isEmpty);
  });
  test('sobreabono o conflicto queda para revisión y detiene dependencias',
      () async {
    final store = DiskStore(dir);
    await store.write('session', jsonEncode(session('alice')));
    var requests = 0;
    final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          requests++;
          return http.Response(
              jsonEncode({
                'error': {
                  'code': 'EXCEEDS_OUTSTANDING',
                  'message': 'El saldo cambió'
                }
              }),
              409);
        }));
    await api.restore();
    api.offline = true;
    await api.command('/negocios/a/comandos', 'REGISTRAR_COBRO', {
      'movimiento': {'monto_minor': '4000'}
    });
    await api.command('/negocios/a/comandos', 'REGISTRAR_COBRO', {
      'movimiento': {'monto_minor': '6000'}
    });
    await expectLater(api.syncLocal(), throwsA(isA<ApiException>()));
    expect(requests, 1);
    expect(api.localEntries.first['estado'], 'REVISION');
    await api.syncLocal();
    expect(requests, 1);
    expect(api.localEntries.length, 2);
    final restarted = ApiClient(store: DiskStore(dir));
    await restarted.restore();
    expect(restarted.localEntries.first['estado'], 'REVISION');
    restarted.client.close();
  });
  test(
      'caída durante el primer envío pasa a cola sin cambiar su ID ni bloquear nuevos registros',
      () async {
    final store = DiskStore(dir);
    await store.write('session', jsonEncode(session('alice')));
    var online = false;
    final ids = <String>[];
    final client = MockClient((r) async {
      ids.add((jsonDecode(r.body) as Map)['command_id'] as String);
      if (!online) throw http.ClientException('respuesta perdida');
      return http.Response('{}', 200);
    });
    final api = ApiClient(store: store, client: client);
    await api.restore();
    final first = await api.command('/negocios/a/comandos', 'REGISTRAR_COBRO', {
      'movimiento': {'monto_minor': '4000'}
    });
    expect(first['local'], true);
    expect(api.pending, isNull);
    expect(api.localEntries.single['resultado_incierto'], true);
    await api.command('/negocios/a/comandos', 'REGISTRAR_COBRO', {
      'movimiento': {'monto_minor': '6000'}
    });
    expect(api.localEntries.length, 2);
    // Crash window: both secure records exist; restore deduplicates them safely.
    await store.write(
        'pending',
        jsonEncode({
          'path': api.localEntries.first['path'],
          'body': api.localEntries.first['body']
        }));
    final restored = ApiClient(store: store, client: client);
    await restored.restore();
    expect(restored.pending, isNull);
    online = true;
    await restored.syncLocal();
    expect(restored.localEntries, isEmpty);
    expect(ids[0], ids[1]);
    expect(ids.toSet().length, 2);
  });
}
