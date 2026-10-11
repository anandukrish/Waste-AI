[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$packaging = $PSScriptRoot

$tokens = $null
$errors = $null
Get-ChildItem -LiteralPath $packaging -Filter '*.ps1' -File | ForEach-Object {
    $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $details = ($errors | ForEach-Object { $_.Message }) -join '; '
        throw "PowerShell parser errors in $($_.Name): $details"
    }
}

$installerText = Get-Content -LiteralPath (Join-Path $packaging 'Waste.iss') -Raw
foreach ($requiredInstallerText in @(
        'PrivilegesRequired=lowest',
        '{localappdata}\Programs\Waste AI',
        '{app}\client\waste.exe',
        'Waste AI Companion (browser)',
        'client\web-preview\index.html',
        'companion\__init__.py',
        'companion\local_tools.py',
        'companion\server.py',
        'python -c')) {
    if ($installerText -notlike "*$requiredInstallerText*") {
        throw "Installer policy is missing: $requiredInstallerText"
    }
}

$androidText = Get-Content -LiteralPath (Join-Path $packaging 'build-android.ps1') -Raw
foreach ($requiredAndroidText in @(
        'android.permission.INTERNET',
        'android.permission.RECORD_AUDIO',
        'android.speech.RecognitionService',
        'android.intent.action.TTS_SERVICE',
        "'build', 'apk', '--debug'",
        'app-debug.apk')) {
    if ($androidText -notlike "*$requiredAndroidText*") {
        throw "Android packaging path is missing: $requiredAndroidText"
    }
}

$fakeBin = Join-Path ([IO.Path]::GetTempPath()) ('waste-packaging-test-' + [Guid]::NewGuid().ToString('N'))
$fakeFlutter = Join-Path $fakeBin 'flutter.cmd'
$fakeIscc = Join-Path $fakeBin 'iscc.cmd'
$oldPath = $env:PATH
try {
    New-Item -ItemType Directory -Force -Path $fakeBin | Out-Null
    Set-Content -LiteralPath $fakeFlutter -Value "@echo off`r`nexit /b 23`r`n" -Encoding ASCII
    Set-Content -LiteralPath $fakeIscc -Value "@echo off`r`nexit /b 0`r`n" -Encoding ASCII
    $env:PATH = "$fakeBin$([IO.Path]::PathSeparator)$oldPath"

    foreach ($scriptName in @('build-windows.ps1', 'build-android.ps1')) {
        $scriptPath = Join-Path $packaging $scriptName
        $output = @()
        try {
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1
        } catch {
            $output += $_.Exception.Message
        }
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            throw "$scriptName unexpectedly succeeded with a failing mocked Flutter command."
        }
        if (($output -join "`n") -notmatch 'exit code 23') {
            throw "$scriptName did not report the mocked native exit code."
        }
    }
} finally {
    $env:PATH = $oldPath
    if (Test-Path -LiteralPath $fakeBin) {
        Remove-Item -LiteralPath $fakeBin -Recurse -Force
    }
}

Write-Output 'Packaging parser and native failure-propagation checks passed.'
