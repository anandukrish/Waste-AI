// Pure, local-only file inspection policy used by the security preview and tests.
// This is a heuristic reviewer, not a malware engine and never claims a file is clean.
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.WasteSecurityPolicy = factory();
  }
}(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  var riskyExtensions = {
    ade: true, apk: true, appx: true, bat: true, cmd: true, com: true,
    dll: true, dmg: true, exe: true, hta: true, iso: true, js: true,
    jse: true, lnk: true, msi: true, ps1: true, scr: true, sh: true,
    sys: true, vbe: true, vbs: true, ws: true, wsf: true, xll: true,
    docm: true, dotm: true, potm: true, ppam: true, pptm: true,
    xlam: true, xlsb: true, xlsm: true, xltm: true
  };

  var extensionLabels = {
    bat: 'Windows batch script', cmd: 'Windows command script',
    dll: 'Windows library', exe: 'Windows executable', hta: 'HTML application',
    iso: 'disk image', js: 'JavaScript file', lnk: 'Windows shortcut',
    msi: 'Windows installer', ps1: 'PowerShell script', scr: 'screen saver executable',
    sh: 'shell script', vbs: 'VBScript file', wsf: 'Windows Script file',
    docm: 'macro-enabled document', xlsm: 'macro-enabled workbook',
    pptm: 'macro-enabled presentation'
  };

  function extensionOf(name) {
    var clean = String(name || '').toLowerCase().split(/[?#]/)[0];
    var match = clean.match(/\.([a-z0-9]{1,12})$/);
    return match ? match[1] : '';
  }

  function contains(list, value) {
    for (var index = 0; index < list.length; index += 1) {
      if (list[index] === value) return true;
    }
    return false;
  }

  function classifyFile(name, mime, size, headerBytes) {
    var filename = String(name || 'Unnamed file');
    var lower = filename.toLowerCase();
    var extension = extensionOf(filename);
    var findings = [];
    var severity = 'low';
    var header = Array.prototype.slice.call(headerBytes || []);
    var hasMZ = header.length >= 2 && header[0] === 0x4d && header[1] === 0x5a;
    var hasPDF = header.length >= 4 && header[0] === 0x25 && header[1] === 0x50 && header[2] === 0x44 && header[3] === 0x46;
    var hasZip = header.length >= 2 && header[0] === 0x50 && header[1] === 0x4b;

    if (/\.[a-z0-9]{1,12}\.(exe|scr|com|bat|cmd|js|vbs|ps1|msi)$/i.test(lower)) {
      findings.push('Double extension can disguise an executable or script.');
      severity = 'high';
    }
    if (riskyExtensions[extension]) {
      findings.push('File type requires review: ' + (extensionLabels[extension] || extension.toUpperCase() + ' file') + '.');
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
    if (Number(size) > 250 * 1024 * 1024) {
      findings.push('Large file: a deeper engine scan may be appropriate.');
      if (severity === 'low') severity = 'medium';
    }
    if (!findings.length) findings.push('No local heuristic matched. This is not a malware-engine verdict.');
    return {
      name: filename,
      extension: extension,
      mime: String(mime || 'unknown'),
      size: Number(size) || 0,
      severity: severity,
      findings: findings,
      label: severity === 'high' ? 'High attention' : severity === 'medium' ? 'Review recommended' : 'No local indicator'
    };
  }

  return { extensionOf: extensionOf, classifyFile: classifyFile, riskyExtensions: riskyExtensions };
}));
