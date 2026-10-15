// Runs with Node (`node security_policy_test.js`) or Windows Script Host.
(function () {
  'use strict';
  var policy;
  if (typeof module === 'object' && module.exports) {
    policy = require('./security_policy.js');
  } else if (typeof WScript !== 'undefined') {
    var fso = new ActiveXObject('Scripting.FileSystemObject');
    var file = fso.OpenTextFile(fso.GetParentFolderName(WScript.ScriptFullName) + '\\security_policy.js', 1);
    var source = file.ReadAll();
    file.Close();
    (new Function(source))();
    policy = WasteSecurityPolicy;
  }
  if (!policy) throw new Error('No supported JavaScript host found.');

  function assert(condition, message) { if (!condition) throw new Error(message); }
  function bytes() { return Array.prototype.slice.call(arguments); }

  var disguised = policy.classifyFile('invoice.pdf.exe', 'application/octet-stream', 1200, bytes(0x4d, 0x5a));
  assert(disguised.severity === 'high', 'double extension was not high attention');
  assert(disguised.findings.length >= 2, 'expected multiple findings for disguised executable');

  var mismatch = policy.classifyFile('report.txt', 'text/plain', 200, bytes(0x25, 0x50, 0x44, 0x46));
  assert(mismatch.severity === 'high', 'header mismatch was not detected');

  var ordinary = policy.classifyFile('photo.jpg', 'image/jpeg', 200, bytes(0xff, 0xd8, 0xff));
  assert(ordinary.severity === 'low', 'ordinary file was over-flagged');
  assert(/not a malware-engine verdict/i.test(ordinary.findings[0]), 'honest limitation missing');

  if (typeof WScript !== 'undefined') WScript.Echo('security policy tests passed');
}());
