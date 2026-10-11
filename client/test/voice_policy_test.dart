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

  test('locale matching accepts platform separators and language families', () {
    expect(
      VoicePolicy.selectAvailableLocale(['en_US', 'ml'], 'ml-IN'),
      'ml',
    );
    expect(
      VoicePolicy.selectAvailableLocale(['en_US'], 'en-IN'),
      'en_US',
    );
    expect(
      VoicePolicy.selectAvailableLocale([], 'ml-IN'),
      'ml-IN',
    );
  });

  test('Malayalam script selects Malayalam for mixed replies', () {
    const available = ['en-IN', 'ml-IN'];
    expect(
      VoicePolicy.localeForSpeechText(
        'Please explain ഇത് simply',
        preferred: 'en-IN',
        available: available,
      ),
      'ml-IN',
    );
    expect(
      VoicePolicy.localeForSpeechText(
        'Please explain this simply',
        preferred: 'en-IN',
        available: available,
      ),
      'en-IN',
    );
  });
}
