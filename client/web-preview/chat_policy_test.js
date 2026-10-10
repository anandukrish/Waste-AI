// Runs with Node (`node chat_policy_test.js`) or Windows Script Host
// (`cscript //nologo chat_policy_test.js`). It has no server or browser needs.
(function () {
  'use strict';
  var policy;
  if (typeof module === 'object' && module.exports) {
    policy = require('./chat_policy.js');
  } else if (typeof WScript !== 'undefined') {
    var fso = new ActiveXObject('Scripting.FileSystemObject');
    var policyFile = fso.OpenTextFile(fso.GetParentFolderName(WScript.ScriptFullName) + '\\chat_policy.js', 1);
    var policySource = policyFile.ReadAll();
    policyFile.Close();
    (new Function(policySource))();
    policy = WasteChatPolicy;
  }
  if (!policy) throw new Error('No supported JavaScript host found.');

  function assert(condition, message) {
    if (!condition) throw new Error(message);
  }

  var history = [];
  for (var index = 0; index < 40; index += 1) {
    history.push({ role: 'user', mode: index % 2 ? 'online' : 'offline', content: new Array(9001).join('x') });
  }
  var offline = policy.historyForRequest(history, 'offline');
  assert(offline.length <= 30, 'history item limit exceeded');
  var total = 0;
  for (var itemIndex = 0; itemIndex < offline.length; itemIndex += 1) {
    assert(offline[itemIndex].content.length <= 8000, 'item limit exceeded');
    assert(offline[itemIndex].role === 'user', 'role changed');
    total += offline[itemIndex].content.length;
  }
  assert(total <= 24000, 'total limit exceeded');
  var online = policy.historyForRequest(history, 'online');
  for (var onlineIndex = 0; onlineIndex < online.length; onlineIndex += 1) {
    assert(online[onlineIndex].content.length === 8000, 'mode filtering failed');
  }
  var mixed = [
    { role: 'user', mode: 'offline', content: 'PRIVATE LOCAL NOTE' },
    { role: 'assistant', mode: 'online', content: 'CLOUD CONTEXT' }
  ];
  var isolated = policy.historyForRequest(mixed, 'online');
  assert(isolated.length === 1 && isolated[0].content === 'CLOUD CONTEXT', 'offline text leaked to cloud');
  var localOnly = policy.historyForRequest(mixed, 'offline');
  assert(localOnly.length === 1 && localOnly[0].content === 'PRIVATE LOCAL NOTE', 'online text leaked to offline context');
  var threw = false;
  try { policy.validateMessage(new Array(8002).join('x')); } catch (_) { threw = true; }
  assert(threw, 'message limit was not enforced');
  if (typeof WScript !== 'undefined') WScript.Echo('chat policy tests passed');
}());
