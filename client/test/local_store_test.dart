import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waste/models/app_models.dart';
import 'package:waste/services/local_store.dart';

void main() {
  late SharedPreferences preferences;
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = LocalStore(preferences, const FlutterSecureStorage());
  });

  test('round-trips online settings and the English voice language', () async {
    const expected = AppSettings(
      host: 'http://127.0.0.1:9000',
      mode: 'online',
      showSetup: false,
      autoSpeak: true,
      voiceLanguage: 'en-IN',
      voiceRate: 0.8,
      voiceVolume: 0.25,
    );

    await store.saveSettings(expected);

    final actual = store.settings;
    expect(actual.host, expected.host);
    expect(actual.mode, expected.mode);
    expect(actual.showSetup, expected.showSetup);
    expect(actual.autoSpeak, expected.autoSpeak);
    expect(actual.voiceLanguage, expected.voiceLanguage);
    expect(actual.voiceRate, expected.voiceRate);
    expect(actual.voiceVolume, expected.voiceVolume);
  });

  test('keeps safe settings fallbacks and bounds stored numeric values', () {
    preferences.setString(
      'waste.settings',
      jsonEncode({
        'host': 'https://companion.example.test',
        'mode': 'unknown',
        'showSetup': false,
        'autoSpeak': true,
        'voiceLanguage': 'fr-FR',
        'voiceRate': 2,
        'voiceVolume': -1,
      }),
    );

    final actual = store.settings;
    expect(actual.mode, 'offline');
    expect(actual.voiceLanguage, 'ml-IN');
    expect(actual.voiceRate, 1.0);
    expect(actual.voiceVolume, 0.0);
  });

  test('round-trips notes and clears them from shared preferences', () async {
    final notes = [
      Note(id: 'one', text: 'local note', createdAt: DateTime(2026, 1, 2)),
      Note(id: 'two', text: 'another note', createdAt: DateTime(2026, 1, 3)),
    ];

    await store.saveNotes(notes);

    expect(store.notes.map((note) => note.id), ['one', 'two']);
    expect(
        store.notes.map((note) => note.text), ['local note', 'another note']);

    await store.clearNotes();
    expect(store.notes, isEmpty);
  });

  test('stores only the last 40 history messages and clears history', () async {
    final messages = List<ChatMessage>.generate(
      45,
      (index) => ChatMessage(
        role: 'user',
        content: 'message $index',
        mode: 'offline',
        createdAt: DateTime(2026, 1, 1).add(Duration(minutes: index)),
      ),
    );

    await store.saveHistory(messages);

    expect(store.history, hasLength(40));
    expect(store.history.first.content, 'message 5');
    expect(store.history.last.content, 'message 44');

    await store.clearHistory();
    expect(store.history, isEmpty);
  });

  test('keeps pairing tokens in secure storage', () async {
    await store.saveToken('pairing-secret');

    expect(await store.readToken(), 'pairing-secret');
    expect(preferences.containsKey('waste.pairing_token'), isFalse);

    await store.clearToken();
    expect(await store.readToken(), isNull);
  });
}
