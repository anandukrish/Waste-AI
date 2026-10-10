// Pure voice policy for browser smoke tests and the embedded preview.
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.WasteVoicePolicy = factory();
  }
}(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  var maxSpeechChars = 8000;
  function boundedSpeechText(text, maxChars) {
    var limit = typeof maxChars === 'number' ? maxChars : maxSpeechChars;
    if (limit <= 0) return '';
    var value = String(text || '');
    var chars = [];
    for (var index = 0; index < value.length && chars.length < limit; index += 1) chars.push(value.charAt(index));
    return chars.join('');
  }
  function preferredVoice(voices, language) {
    var preferred = language === 'en-IN' ? ['en-IN', 'ml-IN'] : ['ml-IN', 'en-IN'];
    for (var wanted = 0; wanted < preferred.length; wanted += 1) {
      for (var index = 0; index < voices.length; index += 1) {
        if (String(voices[index].lang || '').toLowerCase() === preferred[wanted].toLowerCase()) return voices[index];
      }
    }
    return voices[0] || null;
  }
  return { maxSpeechChars: maxSpeechChars, boundedSpeechText: boundedSpeechText, preferredVoice: preferredVoice };
}));
