import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// One in-memory photo per API session; reuses the existing encrypted cache.
class ProfilePhotoState extends ChangeNotifier {
  static final _states = Expando<ProfilePhotoState>();
  static ProfilePhotoState of(ApiClient api) =>
      _states[api] ??= ProfilePhotoState._(api);
  final ApiClient api;
  String? _owner;
  Uint8List? _bytes;
  bool _loaded = false;
  int _generation = 0;
  Future<void>? _loading;
  ProfilePhotoState._(this.api) {
    _owner = api.userId;
    api.addListener(_sessionChanged);
  }
  Uint8List? get bytes => _owner == api.userId ? _bytes : null;
  bool get hasPhoto => bytes != null;
  void _sessionChanged() {
    if (_owner == api.userId) return;
    _owner = api.userId;
    _bytes = null;
    _loaded = false;
    _loading = null;
    _generation++;
    notifyListeners();
  }

  Future<void> load() {
    _sessionChanged();
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    final owner = _owner, generation = _generation;
    Json? value;
    try {
      // Cache explicitly under the request's owner, even if accounts change
      // while the HTTP request is still in flight.
      value = await api.request('GET', '/perfil/foto', useCache: false);
      if (_owner != owner || api.userId != owner || generation != _generation) {
        return;
      }
      if (owner != null) {
        await api.store.write('cache:$owner:/perfil/foto', jsonEncode(value));
      }
    } on ApiException catch (e) {
      if (e.status == 0 && owner != null) {
        final cached = await api.store.read('cache:$owner:/perfil/foto');
        if (cached != null) {
          value = jsonDecode(cached) as Json;
          api.offline = true;
        }
      }
    } catch (_) {/* Keep the default avatar if data cannot be decoded. */}
    if (_owner != owner || api.userId != owner || generation != _generation) {
      return;
    }
    try {
      _bytes = value?['imagen_base64'] == null
          ? null
          : base64Decode(value!['imagen_base64'] as String);
    } catch (_) {
      _bytes = null;
    }
    _loaded = value != null;
    _loading = null;
    notifyListeners();
  }

  Future<void> saved(String? owner, String? encoded) async {
    if (owner != api.userId) return;
    _generation++;
    _owner = owner;
    _bytes = encoded == null ? null : base64Decode(encoded);
    _loaded = true;
    _loading = null;
    notifyListeners();
    if (owner != null) {
      await api.store.write('cache:$owner:/perfil/foto',
          jsonEncode({'imagen_base64': encoded, 'mime': 'image/png'}));
    }
  }
}
