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

# Exercise only prerequisite discovery, with controlled command/path results. Never
# execute the staging or build statements for these discovery regressions.
$windowsAst = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $packaging 'build-windows.ps1'), [ref]$tokens, [ref]$errors)
$discoveryStatements = @()
$inDiscovery = $false
foreach ($statement in $windowsAst.EndBlock.Statements) {
    if ($statement -is [System.Management.Automation.Language.AssignmentStatementAst]) {
        if ($statement.Left.Extent.Text -eq '$flutter') { $inDiscovery = $true }
        if ($statement.Left.Extent.Text -eq '$stage') { break }
    }
    if ($inDiscovery) { $discoveryStatements += $statement.Extent.Text }
}
if ($discoveryStatements.Count -eq 0) { throw 'Windows prerequisite discovery was not found.' }
$discovery = [scriptblock]::Create($discoveryStatements -join "`n")

function Test-WindowsDiscovery {
    param(
        [string[]]$IsccCommands = @(),
        [string[]]$ExistingPaths = @(),
        [string]$ExpectedIscc,
        [int]$ExpectedCount
    )

    function Get-Command {
        param($Name, $CommandType, $ErrorAction)
        if ($Name -eq 'flutter') {
            # Multiple application matches must resolve to one usable executable.
            [pscustomobject]@{ Path = 'first-flutter.cmd' }
            [pscustomobject]@{ Path = 'second-flutter.cmd' }
        } elseif ($Name -eq 'iscc') {
            foreach ($command in $IsccCommands) {
                [pscustomobject]@{ Source = $command }
            }
        } else { throw "Unexpected discovery command: $Name" }
    }
    function Test-Path {
        param([string]$LiteralPath)
        return $ExistingPaths -contains $LiteralPath
    }

    . $discovery
    if ($flutter -is [array] -or $flutter.Path -ne 'first-flutter.cmd') {
        throw 'Flutter discovery did not select the first executable as a scalar.'
    }
    if ($isccCandidates -isnot [array] -or $isccCandidates.Count -ne $ExpectedCount -or
        $isccCandidates[0] -ne $ExpectedIscc) {
        throw 'Inno Setup discovery returned the wrong candidates or priority.'
    }
}

$fakeBin = Join-Path ([IO.Path]::GetTempPath()) ('waste-packaging-test-' + [Guid]::NewGuid().ToString('N'))
$fakeFlutter = Join-Path $fakeBin 'flutter.cmd'
$fakeIscc = Join-Path $fakeBin 'iscc.cmd'
$oldPath = $env:PATH
$oldLocalAppData = $env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA = Join-Path $fakeBin 'Local App Data'
    $perUserIscc = Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'
    Test-WindowsDiscovery -ExistingPaths @($perUserIscc) -ExpectedIscc $perUserIscc -ExpectedCount 1
    $pathIscc = Join-Path $fakeBin 'path-iscc.exe'
    $secondPathIscc = Join-Path $fakeBin 'second-path-iscc.exe'
    Test-WindowsDiscovery -IsccCommands @($pathIscc, $secondPathIscc) `
        -ExistingPaths @($pathIscc, $secondPathIscc, $perUserIscc) -ExpectedIscc $pathIscc -ExpectedCount 3
    $env:LOCALAPPDATA = $null
    $systemIscc = 'C:\Program Files\Inno Setup 6\ISCC.exe'
    Test-WindowsDiscovery -ExistingPaths @($systemIscc) -ExpectedIscc $systemIscc -ExpectedCount 1
    $env:LOCALAPPDATA = $oldLocalAppData

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
    $env:LOCALAPPDATA = $oldLocalAppData
    if (Test-Path -LiteralPath $fakeBin) {
        Remove-Item -LiteralPath $fakeBin -Recurse -Force
    }
}

Write-Output 'Packaging parser, prerequisite discovery, and native failure-propagation checks passed.'
