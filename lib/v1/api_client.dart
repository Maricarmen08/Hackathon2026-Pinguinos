import 'dart:async';
import 'dart:convert';
import 'local_media.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../core/constants/api_constants.dart';

typedef Json = Map<String, dynamic>;

abstract class SessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureSessionStore implements SessionStore {
  final String namespace;
  SecureSessionStore(String baseUrl)
      : namespace = base64Url.encode(utf8.encode(baseUrl));
  final FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));
  @override
  Future<String?> read(String key) => storage.read(key: '$namespace:$key');
  @override
  Future<void> write(String key, String? value) => value == null
      ? storage.delete(key: '$namespace:$key')
      : storage.write(key: '$namespace:$key', value: value);
}

class ApiException implements Exception {
  final int status;
  final String code, message;
  const ApiException(this.status, this.code, this.message);
  @override
  String toString() => message;
}

class ApiClient extends ChangeNotifier {
  final http.Client client;
  final SessionStore store;
  final String baseUrl;
  final Future<List<int>> Function(String) mediaReader;
  Json? session, pending;
  Future<void>? _refreshing;
  bool writing = false;
  bool offline = false, syncing = false;
  List<Json> outbox = [];
  String? get userId => session?['usuario']?['id'] as String?;
  List<Json> get localEntries =>
      outbox.where((e) => userId != null && e['owner'] == userId).toList();
  ApiClient(
      {http.Client? client,
      SessionStore? store,
      String? baseUrl,
      Future<List<int>> Function(String)? mediaReader})
      : client = client ?? http.Client(),
        mediaReader = mediaReader ?? readLocalMedia,
        store = store ?? SecureSessionStore(baseUrl ?? ApiConstants.baseUrl),
        baseUrl = baseUrl ?? ApiConstants.baseUrl;
  String newId() => const Uuid().v4();
  bool get authenticated => session != null;
  String get device => session!['dispositivo_id'] as String;
  Future<void> restore() async {
    final saved = await store.read('session'),
        command = await store.read('pending');
    if (saved != null) session = jsonDecode(saved) as Json;
    if (command != null) pending = jsonDecode(command) as Json;
    final queue = await store.read('outbox_v3');
    if (queue != null) {
      outbox = (jsonDecode(queue) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (pending != null &&
        localEntries.any((e) =>
            e['path'] == pending!['path'] &&
            jsonEncode(e['body']) == jsonEncode(pending!['body']))) {
      await store.write('pending', null);
      pending = null;
    }
  }

  Future<void> _save(Json value) async {
    final next = <String, dynamic>{...?session, ...value};
    await store.write('session', jsonEncode(next));
    session = next;
    notifyListeners();
  }

  Future<void> forget() async {
    await store.write('session', null);
    session = null;
    notifyListeners();
  }

  Future<Json> _send(String method, String path,
      {Json? body,
      bool auth = true,
      List<int>? bytes,
      Map<String, String>? headers}) async {
    try {
      final req = http.Request(method, Uri.parse('$baseUrl$path'));
      req.headers['Content-Type'] = 'application/json';
      if (headers != null) req.headers.addAll(headers);
      if (auth && session != null) {
        req.headers['Authorization'] = 'Bearer ${session!['access_token']}';
      }
      if (body != null) req.body = jsonEncode(body);
      if (bytes != null) req.bodyBytes = bytes;
      final response = await (() async =>
              http.Response.fromStream(await client.send(req)))()
          .timeout(Duration(seconds: path.contains('/ia/analizar') ? 100 : 25));
      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 400) {
        final error = decoded is Map ? decoded['error'] : null;
        throw ApiException(response.statusCode, error?['code'] ?? 'HTTP_ERROR',
            error?['message'] ?? 'No se pudo completar la solicitud.');
      }
      return Map<String, dynamic>.from(decoded as Map);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
          0, 'NETWORK', 'Sin respuesta. Comprueba tu conexión y reintenta.');
    } on http.ClientException {
      throw const ApiException(
          0, 'NETWORK', 'No se pudo conectar con el servidor.');
    } on FormatException {
      throw const ApiException(502, 'INVALID_RESPONSE',
          'El servidor devolvió una respuesta inesperada.');
    }
  }

  Future<void> _refresh() async {
    try {
      await _save(await _send('POST', '/auth/refresh',
          body: {'refresh_token': session!['refresh_token']}, auth: false));
    } on ApiException catch (e) {
      if (e.status == 401) await forget();
      rethrow;
    }
  }

  Future<Json> request(String method, String path,
      {Json? body,
      List<int>? bytes,
      Map<String, String>? headers,
      bool useCache = true}) async {
    final token = session?['access_token'];
    try {
      final result =
          await _send(method, path, body: body, bytes: bytes, headers: headers);
      offline = false;
      if (useCache &&
          method == 'GET' &&
          userId != null &&
          !path.contains('/constancias/')) {
        await store.write('cache:$userId:$path', jsonEncode(result));
      }
      return result;
    } on ApiException catch (e) {
      if (useCache && e.status == 0 && method == 'GET' && userId != null) {
        final saved = await store.read('cache:$userId:$path');
        if (saved != null) {
          offline = true;
          return Map<String, dynamic>.from(jsonDecode(saved) as Map);
        }
        final replica = await _replicaRead(path);
        if (replica != null) {
          offline = true;
          return replica;
        }
      }
      if (e.status != 401 || session == null) rethrow;
      if (token == session?['access_token']) {
        final refresh = _refreshing ??= _refresh();
        try {
          await refresh;
        } finally {
          if (identical(_refreshing, refresh)) _refreshing = null;
        }
      }
      try {
        return await _send(method, path,
            body: body, bytes: bytes, headers: headers);
      } on ApiException catch (e) {
        if (e.status == 401) await forget();
        rethrow;
      }
    }
  }

  Future<void> authenticate(bool register, Json input) async {
    await _save(await _send('POST', register ? '/auth/registro' : '/auth/login',
        body: {
          ...input,
          'dispositivo': {
            'nombre': kIsWeb ? 'FINKI Chrome' : 'FINKI Android',
            'plataforma': kIsWeb ? 'WEB' : 'ANDROID'
          }
        },
        auth: false));
  }

  Future<void> logout() async {
    if (pending != null || localEntries.isNotEmpty) {
      throw const ApiException(
          409, 'PENDING', 'Resuelve primero el envío pendiente.');
    }
    await request('POST', '/auth/logout');
    await forget();
  }

  Future<Json> command(String path, String type, Json payload) async {
    if (writing || syncing || pending != null) {
      throw const ApiException(
          409, 'PENDING', 'Hay un envío pendiente. Reinténtalo desde Inicio.');
    }
    final commandId = type == 'CONFIRMAR_PROPUESTA_LOCAL'
        ? (payload['entrada'] as Map)['id_local'] as String
        : newId();
    if (offline || localEntries.isNotEmpty) {
      if (userId == null ||
          ![
            'CONFIRMAR_PROPUESTA_LOCAL',
            'REGISTRAR_OPERACION',
            'REGISTRAR_COBRO',
            'REGISTRAR_PAGO',
            'REGISTRAR_TRANSFERENCIA',
            'CREAR_TERCERO',
            'CREAR_CUENTA',
            'CREAR_CATEGORIA'
          ].contains(type)) {
        throw const ApiException(0, 'ONLINE_REQUIRED',
            'Esta acción necesita conexión. Puedes registrar ventas y gastos manualmente.');
      }
      writing = true;
      try {
        final entry = <String, dynamic>{
          'owner': userId,
          'path': path,
          'body': {
            'command_id': commandId,
            'dispositivo_id': device,
            'tipo': type,
            'payload': payload
          },
          'estado': 'PENDIENTE',
          'creado': DateTime.now().toUtc().toIso8601String()
        };
        final next = [...outbox, entry];
        await store.write('outbox_v3', jsonEncode(next));
        outbox = next;
        return {'local': true, 'command_id': entry['body']['command_id']};
      } finally {
        writing = false;
        notifyListeners();
      }
    }
    pending = {
      'path': path,
      'body': {
        'command_id': commandId,
        'dispositivo_id': device,
        'tipo': type,
        'payload': payload
      }
    };
    await store.write('pending', jsonEncode(pending));
    notifyListeners();
    try {
      return await retryPending();
    } on ApiException catch (e) {
      if (e.status != 0 ||
          userId == null ||
          pending == null ||
          ![
            'CONFIRMAR_PROPUESTA_LOCAL',
            'REGISTRAR_OPERACION',
            'REGISTRAR_COBRO',
            'REGISTRAR_PAGO',
            'REGISTRAR_TRANSFERENCIA',
            'CREAR_TERCERO',
            'CREAR_CUENTA',
            'CREAR_CATEGORIA'
          ].contains(type)) {
        rethrow;
      }
      final entry = <String, dynamic>{
        ...pending!,
        'owner': userId,
        'estado': 'PENDIENTE',
        'resultado_incierto': true,
        'creado': DateTime.now().toUtc().toIso8601String()
      };
      final next = [...outbox, entry];
      await store.write('outbox_v3', jsonEncode(next));
      outbox = next;
      await store.write('pending', null);
      pending = null;
      offline = true;
      notifyListeners();
      return {'local': true, 'command_id': entry['body']['command_id']};
    }
  }

  Future<Json> retryPending() async {
    if (writing || pending == null) {
      throw const ApiException(409, 'PENDING', 'No hay un envío disponible.');
    }
    if (pending!['body']['dispositivo_id'] != device) {
      throw const ApiException(409, 'DEVICE_MISMATCH',
          'El envío pertenece a una sesión anterior. Conserva su código y revisa el historial antes de descartarlo.');
    }
    writing = true;
    notifyListeners();
    try {
      await store.write('pending', jsonEncode(pending));
      await _prepareLocalEvidence(pending!);
      final result = await request('POST', pending!['path'] as String,
          body: Map<String, dynamic>.from(pending!['body'] as Map));
      await store.write('pending', null);
      pending = null;
      return result;
    } on ApiException catch (e) {
      if ([403, 404, 409, 422].contains(e.status) &&
          e.code != 'IDEMPOTENCY_CONFLICT') {
        await store.write('pending', null);
        pending = null;
      }
      rethrow;
    } finally {
      writing = false;
      notifyListeners();
    }
  }

  Future<void> discardPending() async {
    await store.write('pending', null);
    pending = null;
    notifyListeners();
  }

  Future<void> syncLocal() async {
    if (syncing || writing || pending != null) return;
    syncing = true;
    notifyListeners();
    try {
      for (final entry in localEntries) {
        if (entry['estado'] == 'REVISION') break;
        if (entry['body']['dispositivo_id'] != device) {
          entry['estado'] = 'REVISION';
          entry['error'] =
              'Pertenece a una sesión anterior. Revisa el historial antes de reenviarlo.';
          await store.write('outbox_v3', jsonEncode(outbox));
          break;
        }
        try {
          await _prepareLocalEvidence(entry);
          await request('POST', entry['path'] as String,
              body: Map<String, dynamic>.from(entry['body'] as Map));
          final next = outbox
              .where(
                  (e) => e['body']['command_id'] != entry['body']['command_id'])
              .toList();
          await store.write('outbox_v3', jsonEncode(next));
          outbox = next;
        } on ApiException catch (e) {
          if ([403, 404, 409, 422].contains(e.status)) {
            entry['estado'] = 'REVISION';
            entry['error'] = e.message;
            await store.write('outbox_v3', jsonEncode(outbox));
          }
          rethrow;
        }
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _prepareLocalEvidence(Json entry) async {
    final body = entry['body'] as Map;
    if (body['tipo'] != 'CONFIRMAR_PROPUESTA_LOCAL') return;
    final id = (body['payload'] as Map)['comprobante_id'];
    if (id == null) return;
    final parts = Uri.parse(entry['path'] as String).pathSegments;
    if (parts.length < 2 || parts[0] != 'negocios' || userId == null) {
      throw const ApiException(422, 'LOCAL_EVIDENCE_MISSING',
          'No se encontró el negocio de la imagen.');
    }
    final businessId = parts[1];
    final raw = await store.read('local-evidence:$userId:$businessId:$id');
    if (raw == null) {
      throw const ApiException(422, 'LOCAL_EVIDENCE_MISSING',
          'No se encontró la imagen local. Revisa el registro antes de reenviarlo.');
    }
    try {
      final metadata = jsonDecode(raw) as Map;
      final data = await mediaReader(metadata['token'] as String);
      final result = await request(
          'POST', '/negocios/$businessId/ia/evidencia-local?id=$id',
          bytes: data, headers: {'Content-Type': 'application/octet-stream'});
      if (result['id'] != id) {
        throw const FormatException('La imagen no coincide con el registro.');
      }
    } on FormatException catch (e) {
      throw ApiException(422, 'LOCAL_EVIDENCE_MISSING', e.message);
    }
  }

  Future<Json?> _replicaRead(String path) async {
    final uri = Uri.parse(path), parts = uri.pathSegments;
    if (parts.length < 3 || parts[0] != 'negocios') return null;
    final raw =
        await store.read('cache:$userId:/negocios/${parts[1]}/sync/snapshot');
    if (raw == null) return null;
    final tables = <String, List<Json>>{};
    for (final t in (jsonDecode(raw) as Map)['entidades'] as List) {
      tables[t['tabla'] as String] = (t['registros'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    }
    final table = {
          'historial': 'operaciones',
          'pendientes': 'operaciones'
        }[parts[2]] ??
        parts[2];
    if (!['operaciones', 'categorias', 'cuentas', 'terceros', 'movimientos']
        .contains(table)) {
      return null;
    }
    var rows = tables[table] ?? <Json>[];
    if (table == 'operaciones') {
      final moves = {
        for (final m in tables['movimientos'] ?? <Json>[]) m['id']: m
      };
      rows = rows.map((o) {
        final applications = (tables['aplicaciones'] ?? <Json>[])
            .where((a) => a['operacion_id'] == o['id'])
            .toList();
        final paid = applications.fold<BigInt>(
            BigInt.zero,
            (n, a) =>
                n +
                (moves[a['movimiento_id']]?['estado'] == 'CONFIRMADO'
                    ? BigInt.parse(a['monto_minor'] as String)
                    : BigInt.zero));
        return {
          ...o,
          'liquidado_minor': paid.toString(),
          'pendiente_minor': o['estado'] == 'ANULADO'
              ? '0'
              : (BigInt.parse(o['total_minor'] as String) - paid).toString(),
          'aplicaciones': applications,
          'movimientos': applications
              .map((a) => moves[a['movimiento_id']])
              .whereType<Json>()
              .toList()
        };
      }).toList();
    }
    if (parts.length == 4 && table == 'operaciones') {
      return rows.where((o) => o['id'] == parts[3]).firstOrNull;
    }
    final q = uri.queryParameters;
    rows = rows.where((r) {
      if (parts[2] == 'pendientes' &&
          (r['estado'] != 'CONFIRMADO' ||
              BigInt.parse(r['pendiente_minor'] as String) <= BigInt.zero)) {
        return false;
      }
      if (q['direccion'] != null &&
          (['VENTA', 'SALDO_CXC'].contains(r['tipo'])) !=
              (q['direccion'] == 'COBRAR')) {
        return false;
      }
      for (final key in [
        'tipo',
        'estado',
        'tercero_id',
        'categoria_id',
        'cuenta_id'
      ]) {
        if (q[key] != null && r[key] != q[key]) return false;
      }
      final date = (r['fecha_operacion'] ?? r['fecha_movimiento']) as String?;
      if (date != null &&
          (q['desde'] != null && date.compareTo(q['desde']!) < 0 ||
              q['hasta'] != null && date.compareTo(q['hasta']!) > 0)) {
        return false;
      }
      return q['q'] == null ||
          (r['concepto'] ?? r['nombre'] ?? '')
              .toString()
              .toLowerCase()
              .contains(q['q']!.toLowerCase());
    }).toList();
    rows.sort((a, b) => (b['fecha_operacion'] ??
            b['fecha_movimiento'] ??
            b['nombre'] ??
            '')
        .toString()
        .compareTo(
            (a['fecha_operacion'] ?? a['fecha_movimiento'] ?? a['nombre'] ?? '')
                .toString()));
    final offset = int.tryParse(q['offset'] ?? '0') ?? 0,
        limit = int.tryParse(q['limit'] ?? '30') ?? 30;
    return {
      'items': rows.skip(offset).take(limit).toList(),
      'next_offset': rows.length > offset + limit ? offset + limit : null
    };
  }

  Future<void> removeReviewedLocal(String id) async {
    if (syncing || writing) return;
    final entry = localEntries
        .where(
            (e) => e['body']['command_id'] == id && e['estado'] == 'REVISION')
        .firstOrNull;
    if (entry == null) return;
    final next = outbox.where((e) => e['body']['command_id'] != id).toList();
    await store.write('outbox_v3', jsonEncode(next));
    outbox = next;
    notifyListeners();
  }

  Future<List<Json>> all(String path) async {
    final result = <Json>[];
    int? offset = 0;
    while (offset != null) {
      final data = await request('GET',
          '$path${path.contains('?') ? '&' : '?'}limit=100&offset=$offset');
      result.addAll((data['items'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map)));
      offset = data['next_offset'] as int?;
    }
    return result;
  }
}
