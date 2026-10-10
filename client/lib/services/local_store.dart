import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class LocalStore {
  LocalStore(this._preferences, this._secureStorage);

  static const _settingsKey = 'waste.settings';
  static const _notesKey = 'waste.notes';
  static const _historyKey = 'waste.history';
  static const _tokenKey = 'waste.pairing_token';
  static const _maxHistory = 40;

  final SharedPreferences _preferences;
  final FlutterSecureStorage _secureStorage;

  static Future<LocalStore> create() async => LocalStore(
        await SharedPreferences.getInstance(),
        const FlutterSecureStorage(),
      );

  AppSettings get settings {
    final raw = _preferences.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings(
        host: json['host'] as String? ?? 'http://127.0.0.1:8765',
        mode: json['mode'] as String? == 'online' ? 'online' : 'offline',
        showSetup: json['showSetup'] as bool? ?? true,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings value) => _preferences.setString(
        _settingsKey,
        jsonEncode({
          'host': value.host,
          'mode': value.mode,
          'showSetup': value.showSetup,
        }),
      );

  List<Note> get notes => _decodeList(_notesKey, Note.fromJson);

  Future<void> saveNotes(List<Note> value) => _saveList(_notesKey, value);

  List<ChatMessage> get history =>
      _decodeList<ChatMessage>(_historyKey, ChatMessage.fromJson)
          .takeLast(_maxHistory)
          .toList();

  Future<void> saveHistory(List<ChatMessage> value) =>
      _saveList(_historyKey, value.takeLast(_maxHistory).toList());

  Future<void> clearHistory() => _preferences.remove(_historyKey);

  Future<void> clearNotes() => _preferences.remove(_notesKey);

  Future<String?> readToken() => _secureStorage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _secureStorage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _secureStorage.delete(key: _tokenKey);

  List<T> _decodeList<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = _preferences.getString(key);
    if (raw == null) return <T>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> _saveList<T>(String key, List<T> values) =>
      _preferences.setString(key, jsonEncode(values));
}

extension<T> on List<T> {
  Iterable<T> takeLast(int count) => skip(length > count ? length - count : 0);
}
