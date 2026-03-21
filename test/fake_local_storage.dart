import 'package:waze_kibris/core/services/local_storage.dart';

/// In-memory storage for unit tests (no GetIt).
class FakeLocalStorage implements ILocalStorage {
  final Map<String, dynamic> _map = {};

  @override
  Future<void> clear() async => _map.clear();

  @override
  Future<void> delete(String key) async => _map.remove(key);

  @override
  T? get<T>(
    String key, {
    T? defaultValue,
    T Function(dynamic value)? transform,
  }) {
    final v = _map[key];
    if (v == null) return defaultValue;
    if (transform != null) return transform(v);
    return v as T?;
  }

  @override
  Future<void> save<T>(String key, T value) async {
    _map[key] = value;
  }

  /// Synchronous preset for tests (e.g. existing access token before getProfile).
  void seed<T>(String key, T value) {
    _map[key] = value;
  }
}
