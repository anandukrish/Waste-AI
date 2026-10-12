// Venom Antivirus inspection policy.
// Pure metadata/content-sample rules only: this is not a malware engine.
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.VenomPolicy = factory();
  }
}(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  var MAX_BATCH_SIZE = 32;
  var MAX_FILE_BYTES = 128 * 1024 * 1024;
  var MAX_HISTORY_SIZE = 40;
  var EICAR_TEST_STRING = ['X5O!P%@AP[4\\PZX54(P^)7CC)7}', '$EICAR-STANDARD-', 'ANTIVIRUS-TEST-FILE!$H+H*'].join('');

  var riskyExtensions = {
    ade: true, apk: true, appx: true, bat: true, cmd: true, com: true,
    dll: true, dmg: true, exe: true, hta: true, iso: true, js: true,
    jse: true, lnk: true, msi: true, ps1: true, scr: true, sh: true,
    sys: true, vbe: true, vbs: true, ws: true, wsf: true, xll: true,
    docm: true, dotm: true, potm: true, ppam: true, pptm: true,
    xlam: true, xlsb: true, xlsm: true, xltm: true
  };

  var extensionLabels = {
    apk: 'Android package', bat: 'Windows batch script', cmd: 'Windows command script',
    dll: 'Windows library', dmg: 'macOS disk image', exe: 'Windows executable',
    hta: 'HTML application', iso: 'disk image', js: 'JavaScript file',
    lnk: 'Windows shortcut', msi: 'Windows installer', ps1: 'PowerShell script',
    scr: 'screen saver executable', sh: 'shell script', vbs: 'VBScript file',
    wsf: 'Windows Script file', docm: 'macro-enabled document',
    xlsm: 'macro-enabled workbook', pptm: 'macro-enabled presentation'
  };

  function extensionOf(name) {
    var clean = String(name || '').toLowerCase().split(/[\\/]/).pop();
    var match = clean.match(/\.([a-z0-9]{1,12})$/);
    return match ? match[1] : '';
  }

  function hasExtension(name, extension) {
    return extensionOf(name) === extension;
  }

  function contains(list, value) {
    var index;
    for (index = 0; index < list.length; index += 1) {
      if (list[index] === value) return true;
    }
    return false;
  }

  function bytesToString(bytes) {
    var output = '';
    var index;
    var cursor;
    var end;
    var chunk;
    for (index = 0; index < bytes.length; index += 8192) {
      end = Math.min(index + 8192, bytes.length);
      chunk = '';
      for (cursor = index; cursor < end; cursor += 1) {
        chunk += String.fromCharCode(bytes[cursor]);
      }
      output += chunk;
    }
    return output;
  }

  function sampleAsString(sample) {
    if (sample === null || typeof sample === 'undefined') return '';
    if (typeof sample === 'string') return sample;
    if (typeof Uint8Array !== 'undefined' && sample instanceof Uint8Array) return bytesToString(sample);
    if (Object.prototype.toString.call(sample) === '[object Array]') return bytesToString(sample);
    return String(sample);
  }

  function containsEicar(sample) {
    return sampleAsString(sample).indexOf(EICAR_TEST_STRING) !== -1;
  }

  function classifyFile(name, mime, size, headerBytes, sample) {
    var filename = String(name || 'Unnamed file');
    var lower = filename.toLowerCase();
    var extension = extensionOf(filename);
    var findings = [];
    var severity = 'low';
    var header = Array.prototype.slice.call(headerBytes || []);
    var hasMZ = header.length >= 2 && header[0] === 0x4d && header[1] === 0x5a;
    var hasPDF = header.length >= 4 && header[0] === 0x25 && header[1] === 0x50 && header[2] === 0x44 && header[3] === 0x46;
    var hasZip = header.length >= 2 && header[0] === 0x50 && header[1] === 0x4b;
    var numericSize = Number(size) || 0;
    var eicar = containsEicar(sample);

    if (eicar) {
      findings.push('Explicit EICAR test string detected. This is a harmless antivirus test pattern for validating a scanner.');
      severity = 'high';
    }
    if (/\.[a-z0-9]{1,12}\.(exe|scr|com|bat|cmd|js|vbs|ps1|msi)$/i.test(lower)) {
      findings.push('Double extension can disguise an executable or script.');
      severity = 'high';
    }
    if (Object.prototype.hasOwnProperty.call(riskyExtensions, extension)) {
      findings.push('File type requires review: ' + (Object.prototype.hasOwnProperty.call(extensionLabels, extension) ? extensionLabels[extension] : extension.toUpperCase() + ' file') + '.');
      if (severity !== 'high') severity = 'medium';
    }
    if (hasMZ && !contains(['exe', 'dll', 'scr', 'sys', 'com', 'cpl', 'ocx'], extension)) {
      findings.push('The content begins like a Windows portable executable, but the extension is ' + (extension ? '.' + extension : 'missing') + '.');
      severity = 'high';
    }
    if (hasPDF && extension && extension !== 'pdf') {
      findings.push('The content looks like a PDF but the extension does not match.');
      severity = 'high';
    }
    if (hasZip && contains(['js', 'vbs', 'ps1', 'exe', 'scr'], extension)) {
      findings.push('The header looks like an archive while the name suggests an executable or script.');
      severity = 'high';
    }
    if (numericSize > MAX_FILE_BYTES) {
      findings.push('File exceeds the local inspection size limit and needs a deeper engine scan.');
      if (severity === 'low') severity = 'medium';
    }
    if (!findings.length) findings.push('No local heuristic matched. This is not a malware-engine verdict.');

    return {
      name: filename,
      extension: extension,
      mime: String(mime || 'unknown'),
      size: numericSize,
      severity: severity,
      label: severity === 'high' ? 'High attention' : severity === 'medium' ? 'Review recommended' : 'No local indicator',
      eicarDetected: eicar,
      findings: findings
    };
  }

  function limitBatch(files, limit) {
    var max = Number(limit) > 0 ? Math.min(MAX_BATCH_SIZE, Math.floor(Number(limit))) : MAX_BATCH_SIZE;
    return Array.prototype.slice.call(files || [], 0, max);
  }

  function boundedString(value) { return typeof value === 'string' ? value.slice(0, 512) : ''; }
  function own(object, key) { return Object.prototype.hasOwnProperty.call(object, key) ? object[key] : undefined; }
  function field(object, canonical, legacy) {
    var value = own(object, canonical);
    return typeof value === 'undefined' ? own(object, legacy) : value;
  }
  // The only serialization boundary for AI review and downloaded reports.
  // Construct fields explicitly; never spread/copy input or stringify arbitrary objects.
  function aiMetadata(result) {
    result = result && typeof result === 'object' ? result : {};
    var name = own(result, 'name');
    var detections = field(result, 'detections', 'findings');
    var safeDetections = [];
    var index;
    if (Object.prototype.toString.call(detections) === '[object Array]') {
      for (index = 0; index < detections.length && safeDetections.length < 8; index += 1) {
        if (typeof detections[index] === 'string') safeDetections.push(boundedString(detections[index]));
      }
    }
    var size = own(result, 'size');
    var severity = own(result, 'severity');
    return {
      name: typeof name === 'string' ? boundedString(name.split(/[\\/]/).pop()) : '',
      size: typeof size === 'number' && isFinite(size) && size >= 0 ? Math.floor(size) : 0,
      mime_type: boundedString(field(result, 'mime_type', 'mime')),
      extension: boundedString(own(result, 'extension')),
      sha256: boundedString(field(result, 'sha256', 'hash')),
      severity: severity === 'high' || severity === 'medium' || severity === 'low' ? severity : 'medium',
      status: boundedString(own(result, 'status')) || 'incomplete',
      detections: safeDetections,
      created_at: boundedString(field(result, 'created_at', 'inspectedAt'))
    };
  }

  function validateHistory(records) {
    var valid = [];
    var index;
    if (Object.prototype.toString.call(records) !== '[object Array]') return valid;
    for (index = 0; index < records.length && valid.length < MAX_HISTORY_SIZE; index += 1) {
      var row = records[index];
      if (!row || typeof row !== 'object' || typeof own(row, 'name') !== 'string' ||
          typeof own(row, 'size') !== 'number' || !isFinite(row.size) || row.size < 0 ||
          !contains(['high', 'medium', 'low'], own(row, 'severity')) ||
          typeof field(row, 'created_at', 'inspectedAt') !== 'string' ||
          !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(field(row, 'created_at', 'inspectedAt'))) continue;
      var metadata = aiMetadata(row);
      valid.push({
        name: metadata.name, size: metadata.size, mime: metadata.mime_type,
        extension: metadata.extension, hash: /^[a-f0-9]{64}$/i.test(metadata.sha256) ? metadata.sha256 : '',
        severity: metadata.severity, status: metadata.status === 'complete' ? 'complete' : 'incomplete',
        findings: metadata.detections, inspectedAt: metadata.created_at,
        label: boundedString(own(row, 'label')) || 'Stored inspection',
        eicarDetected: own(row, 'eicarDetected') === true,
        bytesRead: typeof own(row, 'bytesRead') === 'number' && isFinite(own(row, 'bytesRead')) ? Math.max(0, Math.floor(own(row, 'bytesRead'))) : 0,
        durationMs: typeof own(row, 'durationMs') === 'number' && isFinite(own(row, 'durationMs')) ? Math.max(0, own(row, 'durationMs')) : 0,
        hashScope: boundedString(own(row, 'hashScope'))
      });
    }
    return valid;
  }

  return {
    MAX_BATCH_SIZE: MAX_BATCH_SIZE,
    MAX_FILE_BYTES: MAX_FILE_BYTES,
    MAX_HISTORY_SIZE: MAX_HISTORY_SIZE,
    EICAR_TEST_STRING: EICAR_TEST_STRING,
    extensionOf: extensionOf,
    hasExtension: hasExtension,
    containsEicar: containsEicar,
    classifyFile: classifyFile,
    limitBatch: limitBatch,
    aiMetadata: aiMetadata,
    validateHistory: validateHistory,
    riskyExtensions: riskyExtensions
  };
}));
