// Pure policy checks. Run with: cscript //nologo venom_policy_test.js
(function () {
  'use strict';
  var policy;
  if (typeof module === 'object' && module.exports) {
    policy = require('./venom_policy.js');
  } else if (typeof WScript !== 'undefined') {
    var fso = new ActiveXObject('Scripting.FileSystemObject');
    var file = fso.OpenTextFile(fso.GetParentFolderName(WScript.ScriptFullName) + '\\venom_policy.js', 1);
    var source = file.ReadAll();
    file.Close();
    (new Function(source))();
    policy = VenomPolicy;
  }
  if (!policy) throw new Error('No supported JavaScript host found.');

  function assert(condition, message) { if (!condition) throw new Error(message); }
  function bytes() { return Array.prototype.slice.call(arguments); }

  var disguised = policy.classifyFile('invoice.pdf.exe', 'application/octet-stream', 1200, bytes(0x4d, 0x5a), '');
  assert(disguised.severity === 'high', 'double extension was not high attention');
  assert(disguised.findings.length >= 2, 'expected multiple findings for disguised executable');

  var mismatch = policy.classifyFile('report.txt', 'text/plain', 200, bytes(0x25, 0x50, 0x44, 0x46), '');
  assert(mismatch.severity === 'high', 'header mismatch was not detected');

  var standardEicar = ['X5O!P%@AP[4\\PZX54(P^)7CC)7}', '$EICAR-STANDARD-', 'ANTIVIRUS-TEST-FILE!$H+H*'].join('');
  var eicar = policy.classifyFile('eicar.com', 'application/octet-stream', standardEicar.length, bytes(0x58, 0x35), standardEicar);
  assert(eicar.severity === 'high', 'EICAR test string was not high attention');
  assert(eicar.eicarDetected === true, 'EICAR detection flag was not set');
  assert(/EICAR/i.test(eicar.findings[0]), 'EICAR finding was not explained');
  assert(policy.containsEicar(standardEicar) === true, 'EICAR string helper failed');
  var eicarBytes = [];
  for (var byteIndex = 0; byteIndex < standardEicar.length; byteIndex += 1) eicarBytes.push(standardEicar.charCodeAt(byteIndex));
  assert(policy.containsEicar(eicarBytes) === true, 'EICAR byte helper failed');

  var ordinary = policy.classifyFile('photo.jpg', 'image/jpeg', 200, bytes(0xff, 0xd8, 0xff), 'plain image metadata');
  assert(ordinary.severity === 'low', 'ordinary file was over-flagged');
  assert(/not a malware-engine verdict/i.test(ordinary.findings[0]), 'honest limitation missing');

  var batch = policy.limitBatch([1, 2, 3, 4], 2);
  assert(batch.length === 2, 'batch limit was not enforced');
  assert(policy.MAX_BATCH_SIZE === 32, 'batch policy changed unexpectedly');

  assert(policy.extensionOf('report.exe?download=1') === '', 'filename query text was incorrectly stripped');
  assert(policy.extensionOf('folder\\report.EXE') === 'exe', 'basename extension was not recognized');
  assert(policy.classifyFile('sample.__proto__', 'text/plain', 1, [], '').severity === 'low', 'prototype-like extension was treated as risky');

  var longFinding = '';
  for (var findingIndex = 0; findingIndex < 700; findingIndex += 1) longFinding += 'x';
  var sourceResult = {
    name: 'folder\\private.exe', size: 42, mime: 'application/octet-stream', extension: 'exe',
    hash: new Array(65).join('a'),
    severity: 'high', status: 'complete', findings: [longFinding, 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth', 'ninth'],
    inspectedAt: '2026-10-12T10:20:30.000Z', relativePath: 'private\\folder\\private.exe', content: 'DO NOT SEND THIS'
  };
  var ai = policy.aiMetadata(sourceResult);
  var expectedKeys = ['name', 'size', 'mime_type', 'extension', 'sha256', 'severity', 'status', 'detections', 'created_at'];
  var aiKeys = [];
  for (var key in ai) if (Object.prototype.hasOwnProperty.call(ai, key)) aiKeys.push(key);
  assert(aiKeys.join('|') === expectedKeys.join('|'), 'AI metadata keys were not exactly allowlisted');
  assert(ai.name === 'private.exe', 'AI metadata did not reduce name to basename');
  assert(!Object.prototype.hasOwnProperty.call(ai, 'content') && !Object.prototype.hasOwnProperty.call(ai, 'relativePath'), 'AI metadata leaked file content or relative path');
  assert(ai.detections.length === 8 && ai.detections[0].length === 512, 'AI detections were not bounded');
  assert(ai.mime_type === 'application/octet-stream' && ai.sha256.length === 64, 'AI metadata canonical keys were not mapped');

  var stored = policy.validateHistory([sourceResult, { name: 99 }, { name: 'bad', size: 1, severity: 'unknown', inspectedAt: 'never' }]);
  assert(stored.length === 1 && stored[0].name === 'private.exe', 'malformed history was not filtered safely');

  if (typeof WScript !== 'undefined') WScript.Echo('Venom policy tests passed');
}());
