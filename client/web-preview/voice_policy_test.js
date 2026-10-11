// Runs with Node (`node voice_policy_test.js`) or Windows Script Host.
(function () {
  'use strict';
  var policy;
  if (typeof module === 'object' && module.exports) {
    policy = require('./voice_policy.js');
  } else if (typeof WScript !== 'undefined') {
    var fso = new ActiveXObject('Scripting.FileSystemObject');
    var file = fso.OpenTextFile(fso.GetParentFolderName(WScript.ScriptFullName) + '\\voice_policy.js', 1);
    var source = file.ReadAll();
    file.Close();
    (new Function(source))();
    policy = WasteVoicePolicy;
  }
  if (!policy) throw new Error('No supported JavaScript host found.');
  function assert(condition, message) { if (!condition) throw new Error(message); }
  assert(policy.boundedSpeechText(new Array(8002).join('x')).length === 8000, 'speech bound failed');
  assert(policy.boundedSpeechText('x\ud83d\ude00z', 2) === 'x\ud83d\ude00', 'surrogate speech bound failed');
  var malayalam = '';
  for (var repeat = 0; repeat < 8001; repeat += 1) malayalam += 'മ';
  assert(policy.boundedSpeechText(malayalam).length === 8000, 'unicode speech bound failed');
  var ml = { lang: 'ml-IN', name: 'Malayalam' };
  var en = { lang: 'en-IN', name: 'English India' };
  assert(policy.preferredVoice([en, ml], 'ml-IN') === ml, 'Malayalam preference failed');
  assert(policy.preferredVoice([ml, en], 'en-IN') === en, 'English preference failed');
  assert(policy.selectAvailableLocale(['en_US', 'ml'], 'ml-IN') === 'ml', 'locale family fallback failed');
  assert(policy.selectAvailableLocale(['en_US'], 'en-IN') === 'en_US', 'locale separator fallback failed');
  assert(policy.speechLocale('Please explain \u0d07\u0d24\u0d4d simply', 'en-IN', ['en-IN', 'ml-IN']) === 'ml-IN', 'mixed Malayalam locale failed');
  assert(policy.speechLocale('Please explain this simply', 'en-IN', ['en-IN', 'ml-IN']) === 'en-IN', 'English locale failed');
  if (typeof WScript !== 'undefined') WScript.Echo('voice policy tests passed');
}());
