// import 'dart:convert';
//
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:waze_kibris/common.dart';
//
//
// class LocalStorage implements ILocalStorage {
//   late final SharedPreferences prefs;
//
//   Future<void> initializePrefs() async {
//     prefs = await SharedPreferences.getInstance();
//   }
//
//   @override
//   Future<void> clear() async {
//     await prefs.clear();
//   }
//
//   @override
//   Future<void> delete(String key) async {
//     await prefs.remove(key);
//   }
//
//   @override
//   T? get<T>(String key,
//       {T? defaultValue, T Function(dynamic value)? transform}) {
//     final value = prefs.get(key);
//     if (value == null) return defaultValue;
//
//     dynamic decode(value) async {
//       try {
//         return jsonDecode(value);
//       } catch (e) {
//         return value;
//       }
//     }
//
//     return transform?.call(decode(value)) ?? decode(value);
//   }
//
//   @override
//   Future<void> save<T>(String key, T value) {
//     try {
//       if (value is String) {
//         return prefs.setString(key, value);
//       } else if (value is int) {
//         return prefs.setInt(key, value);
//       } else if (value is double) {
//         return prefs.setDouble(key, value);
//       } else if (value is bool) {
//         return prefs.setBool(key, value);
//       } else if (value is List<String>) {
//         return prefs.setStringList(key, value);
//       } else {
//         return prefs.setString(key, jsonEncode(value));
//       }
//     } catch (e) {
//       throw CachePutException();
//     }
//   }
// }
