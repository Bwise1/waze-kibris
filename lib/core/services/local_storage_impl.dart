import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:waze_kibris/common.dart';

class LocalStorage implements ILocalStorage {
  late SharedPreferences prefs;

  Future<void> initializePrefs() async {
    prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<void> clear() async {
    await prefs.clear();
  }

  @override
  Future<void> delete(String key) async {
    await prefs.remove(key);
  }

  @override
  T? get<T>(
    String key, {
    T? defaultValue,
    T Function(dynamic value)? transform,
  }) {
    final value = prefs.get(key);
    if (value == null) return defaultValue;

    dynamic decode(dynamic value) {
      if (value is String) {
        try {
          return jsonDecode(value);
        } catch (_) {
          return value;
        }
      }
      return value;
    }

    return transform?.call(decode(value)) ?? decode(value) as T?;
  }

  @override
  Future<void> save<T>(String key, T value) async {
    try {
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      } else {
        await prefs.setString(key, jsonEncode(value));
      }
    } catch (e) {
      throw CachePutException();
    }
  }
}
