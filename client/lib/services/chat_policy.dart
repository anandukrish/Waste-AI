import '../models/app_models.dart';

class ChatRequestPolicy {
  static const maxOutgoingHistoryItems = 30;
  static const maxOutgoingHistoryChars = 24000;
  static const maxOutgoingItemChars = 8000;
  static const maxOutgoingMessageChars = 8000;

  static String validateMessage(String message) {
    if (message.runes.length > maxOutgoingMessageChars) {
      throw const ChatRequestPolicyException(
        'Messages are limited to 8,000 characters.',
      );
    }
    return message;
  }

  /// Returns only the selected mode's recent history, in chronological order.
  /// The API contract intentionally receives role/content only.
  static List<Map<String, String>> historyForRequest(
    Iterable<ChatMessage> history,
    String requestMode,
  ) {
    final matching = history.where((item) => item.mode == requestMode).toList();
    final newest = <Map<String, String>>[];
    var totalChars = 0;
    for (final item in matching.reversed) {
      if (newest.length >= maxOutgoingHistoryItems ||
          totalChars >= maxOutgoingHistoryChars) {
        break;
      }
      final available = maxOutgoingHistoryChars - totalChars;
      final content = _clip(
        item.content,
        available < maxOutgoingItemChars ? available : maxOutgoingItemChars,
      );
      if (content.isEmpty) continue;
      newest.add({'role': item.role, 'content': content});
      totalChars += content.runes.length;
    }
    return newest.reversed.toList();
  }

  static String _clip(String value, int maxChars) {
    if (value.runes.length <= maxChars) return value;
    return String.fromCharCodes(value.runes.take(maxChars));
  }
}

class ChatRequestPolicyException implements Exception {
  const ChatRequestPolicyException(this.message);

  final String message;

  @override
  String toString() => message;
}
