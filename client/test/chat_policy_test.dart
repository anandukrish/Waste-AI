import 'package:flutter_test/flutter_test.dart';

import 'package:waste/models/app_models.dart';
import 'package:waste/services/chat_policy.dart';

void main() {
  ChatMessage message(String mode, String content) => ChatMessage(
        role: 'user',
        content: content,
        mode: mode,
        createdAt: DateTime(2026),
      );

  test('outgoing history contains only the snapshotted request mode', () {
    final history = [
      message('offline', 'local one'),
      message('online', 'private online one'),
      message('offline', 'local two'),
    ];

    final outgoing = ChatRequestPolicy.historyForRequest(history, 'offline');

    expect(outgoing.map((item) => item['content']), ['local one', 'local two']);
    expect(outgoing.every((item) => !item.containsKey('mode')), isTrue);
  });

  test('outgoing history is bounded by items, item chars, and total chars', () {
    final history = List<ChatMessage>.generate(
      40,
      (index) => message('offline', 'x' * 8000),
    );

    final outgoing = ChatRequestPolicy.historyForRequest(history, 'offline');
    final total = outgoing.fold<int>(
      0,
      (sum, item) => sum + (item['content'] ?? '').runes.length,
    );

    // The total character bound is reached after three 8,000-character items,
    // before the 30-item bound is reached.
    expect(outgoing, hasLength(3));
    expect(
      outgoing.every(
        (item) => (item['content'] ?? '').runes.length <= 8000,
      ),
      isTrue,
    );
    expect(total, lessThanOrEqualTo(24000));
  });

  test('messages over 8000 characters are rejected before sending', () {
    expect(
      () => ChatRequestPolicy.validateMessage('x' * 8001),
      throwsA(isA<ChatRequestPolicyException>()),
    );
  });
}
