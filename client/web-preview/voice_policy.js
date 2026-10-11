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
    for (var index = 0; index < value.length && chars.length < limit; index += 1) {
      var code = value.charCodeAt(index);
      if (code >= 0xd800 && code <= 0xdbff && index + 1 < value.length) {
        var next = value.charCodeAt(index + 1);
        if (next >= 0xdc00 && next <= 0xdfff) {
          chars.push(value.substr(index, 2));
          index += 1;
          continue;
        }
      }
      chars.push(value.charAt(index));
    }
    return chars.join('');
  }
  function trim(value) {
    return String(value || '').replace(/^\s+|\s+$/g, '');
  }
  function normalizeLocale(value) {
    return trim(value).toLowerCase().replace(/_/g, '-');
  }
  function localeCandidates(language) {
    var normalized = normalizeLocale(language);
    var candidates = [language];
    if (normalized.indexOf('ml') === 0) candidates.push('ml-IN');
    if (normalized.indexOf('en') === 0) candidates.push('en-IN');
    candidates.push('ml-IN', 'en-IN', 'en-US');
    var unique = [];
    for (var index = 0; index < candidates.length; index += 1) {
      var alreadyAdded = false;
      for (var uniqueIndex = 0; uniqueIndex < unique.length; uniqueIndex += 1) {
        if (unique[uniqueIndex] === candidates[index]) alreadyAdded = true;
      }
      if (!alreadyAdded) unique.push(candidates[index]);
    }
    return unique;
  }
  function containsMalayalam(text) {
    var value = String(text || '');
    for (var index = 0; index < value.length; index += 1) {
      var code = value.charCodeAt(index);
      if (code >= 0x0d00 && code <= 0x0d7f) return true;
    }
    return false;
  }
  function selectAvailableLocale(available, preferred, fallback) {
    var values = [];
    for (var availableIndex = 0; availableIndex < (available || []).length; availableIndex += 1) {
      var value = trim(available[availableIndex]);
      if (value) values.push(value);
    }
    if (!values.length) return fallback || preferred;
    var candidates = localeCandidates(preferred);
    for (var wanted = 0; wanted < candidates.length; wanted += 1) {
      for (var index = 0; index < values.length; index += 1) {
        if (normalizeLocale(values[index]) === normalizeLocale(candidates[wanted])) return values[index];
      }
      var language = normalizeLocale(candidates[wanted]).split('-')[0];
      for (var valueIndex = 0; valueIndex < values.length; valueIndex += 1) {
        if (normalizeLocale(values[valueIndex]).split('-')[0] === language) return values[valueIndex];
      }
    }
    return fallback || preferred;
  }
  function speechLocale(text, preferred, available, fallback) {
    return selectAvailableLocale(available, containsMalayalam(text) ? 'ml-IN' : preferred, fallback);
  }
  function preferredVoice(voices, language, text) {
    var languages = [];
    for (var voiceIndex = 0; voiceIndex < (voices || []).length; voiceIndex += 1) languages.push(voices[voiceIndex].lang);
    var wantedLanguage = speechLocale(text, language, languages, language);
    for (var index = 0; index < voices.length; index += 1) {
      if (normalizeLocale(voices[index].lang) === normalizeLocale(wantedLanguage)) return voices[index];
    }
    var wantedFamily = normalizeLocale(wantedLanguage).split('-')[0];
    for (var familyIndex = 0; familyIndex < voices.length; familyIndex += 1) {
      if (normalizeLocale(voices[familyIndex].lang).split('-')[0] === wantedFamily) return voices[familyIndex];
    }
    return voices[0] || null;
  }
  return {
    maxSpeechChars: maxSpeechChars,
    boundedSpeechText: boundedSpeechText,
    containsMalayalam: containsMalayalam,
    selectAvailableLocale: selectAvailableLocale,
    speechLocale: speechLocale,
    preferredVoice: preferredVoice
  };
}));
