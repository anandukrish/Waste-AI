// Pure request-shaping policy for browser smoke tests and the embedded preview.
// The preview keeps an inline copy because the companion serves only `/`.
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.WasteChatPolicy = factory();
  }
}(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  var limits = {
    maxOutgoingHistoryItems: 30,
    maxOutgoingHistoryChars: 24000,
    maxOutgoingItemChars: 8000,
    maxOutgoingMessageChars: 8000
  };

  function validateMessage(message) {
    if (message.length > limits.maxOutgoingMessageChars) {
      throw new Error('Messages are limited to 8,000 characters.');
    }
    return message;
  }

  function historyForRequest(history, requestMode) {
    var matching = [];
    for (var sourceIndex = 0; sourceIndex < history.length; sourceIndex += 1) {
      if (history[sourceIndex].mode === requestMode) matching.push(history[sourceIndex]);
    }
    var newest = [];
    var totalChars = 0;
    for (var index = matching.length - 1; index >= 0; index -= 1) {
      if (newest.length >= limits.maxOutgoingHistoryItems || totalChars >= limits.maxOutgoingHistoryChars) break;
      var available = limits.maxOutgoingHistoryChars - totalChars;
      var maxChars = Math.min(available, limits.maxOutgoingItemChars);
      var content = String(matching[index].content || '').slice(0, maxChars);
      if (!content) continue;
      newest.push({ role: matching[index].role, content: content });
      totalChars += content.length;
    }
    return newest.reverse();
  }

  return { limits: limits, validateMessage: validateMessage, historyForRequest: historyForRequest };
}));
