import 'package:flutter_test/flutter_test.dart';

import 'package:waste/services/voice_service.dart';

void main() {
  test('voice text is bounded without splitting Unicode code points', () {
    final text = 'മ' * 8001;
    final bounded = VoicePolicy.boundedSpeechText(text);

    expect(bounded.runes.length, 8000);
    expect(bounded, 'മ' * 8000);
  });

  test('empty and non-positive bounds are safe', () {
    expect(VoicePolicy.boundedSpeechText('hello', maxChars: 0), isEmpty);
    expect(VoicePolicy.boundedSpeechText(''), isEmpty);
  });
}
