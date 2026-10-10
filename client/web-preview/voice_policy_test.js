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
  var malayalam = '';
  for (var repeat = 0; repeat < 8001; repeat += 1) malayalam += 'മ';
  assert(policy.boundedSpeechText(malayalam).length === 8000, 'unicode speech bound failed');
  var ml = { lang: 'ml-IN', name: 'Malayalam' };
  var en = { lang: 'en-IN', name: 'English India' };
  assert(policy.preferredVoice([en, ml], 'ml-IN') === ml, 'Malayalam preference failed');
  assert(policy.preferredVoice([ml, en], 'en-IN') === en, 'English preference failed');
  if (typeof WScript !== 'undefined') WScript.Echo('voice policy tests passed');
}());
