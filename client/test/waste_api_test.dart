import 'package:flutter_test/flutter_test.dart';
import 'package:waste/services/waste_api.dart';

void main() {
  group('WasteApi.validateBaseUrl', () {
    test('accepts the loopback default and strips a root slash', () {
      expect(
        WasteApi.validateBaseUrl('http://127.0.0.1:8765/').toString(),
        'http://127.0.0.1:8765',
      );
    });

    test('requires HTTPS for non-loopback origins', () {
      expect(
        () => WasteApi.validateBaseUrl('http://companion.example.test'),
        throwsA(isA<WasteApiException>()),
      );
    });

    test('rejects credentials and URL decorations', () {
      expect(
        () => WasteApi.validateBaseUrl('https://user:pass@example.test'),
        throwsA(isA<WasteApiException>()),
      );
      expect(
        () => WasteApi.validateBaseUrl('https://example.test/?token=secret'),
        throwsA(isA<WasteApiException>()),
      );
    });
  });
}
