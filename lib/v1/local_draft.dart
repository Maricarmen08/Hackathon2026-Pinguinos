import 'dart:convert';
import 'api_client.dart';

/// Uses the same secure, API/user/business-scoped storage as the offline queue.
class LocalDraft {
  final SessionStore store;
  final String key;
  Future<void> _writes = Future.value();
  bool _closed = false;
  LocalDraft(this.store, this.key);
  Future<Json?> read() async {
    final raw = await store.read(key);
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> save(Json value) {
    if (_closed) return Future.value();
    final snapshot = jsonEncode(value);
    return _writes = _writes
        .catchError((Object _) {})
        .then((_) => store.write(key, snapshot));
  }

  Future<void> clearAfterSubmission() async {
    _closed = true;
    await _writes.catchError((Object _) {});
    await store.write(key, null);
  }
}
