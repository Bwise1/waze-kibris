abstract class ILocalStorage {
  Future<void> save<T>(String key, T value);

  T? get<T>(
    String key, {
    T? defaultValue,
    T Function(dynamic value)? transform,
  });

  Future<void> delete(String key);

  Future<void> clear();
}
