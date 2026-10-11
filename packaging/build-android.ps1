[CmdletBinding()]
param(
    [switch]$SkipFlutterCreate
)

$ErrorActionPreference = 'Stop'

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory = $true)][string]$Description
    )

    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$Description failed with exit code $exitCode."
    }
}

function Copy-ClientSources {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $generatedNames = @('windows', 'android', 'build', '.dart_tool', '.flutter-plugins', '.flutter-plugins-dependencies')
    Get-ChildItem -LiteralPath $Source -Force |
        Where-Object { $generatedNames -notcontains $_.Name } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Destination $_.Name) -Recurse -Force
        }
}

function Update-AndroidManifest {
    param([Parameter(Mandatory = $true)][string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw
    $permissionLines = @()
    if ($text -notmatch 'android\.permission\.INTERNET') {
        $permissionLines += '    <uses-permission android:name="android.permission.INTERNET" />'
    }
    if ($text -notmatch 'android\.permission\.RECORD_AUDIO') {
        $permissionLines += '    <uses-permission android:name="android.permission.RECORD_AUDIO" />'
    }
    if ($permissionLines.Count -gt 0) {
        $insert = (($permissionLines -join "`r`n") + "`r`n")
        $text = $text -replace '(\s*<application\b)', ("`r`n" + $insert + '$1')
    }

    $speechIntent = '<intent><action android:name="android.speech.RecognitionService" /></intent>'
    $ttsIntent = '<intent><action android:name="android.intent.action.TTS_SERVICE" /></intent>'
    if ($text -notmatch '<queries\b') {
        $queries = "    <queries>`r`n        $speechIntent`r`n        $ttsIntent`r`n    </queries>`r`n"
        $text = $text -replace '(\s*<application\b)', ("`r`n" + $queries + '$1')
    } else {
        if ($text -notmatch 'android\.speech\.RecognitionService') {
            $text = $text -replace '(\s*</queries>)', ("`r`n        $speechIntent`r`n    </queries>")
        }
        if ($text -notmatch 'android\.intent\.action\.TTS_SERVICE') {
            $text = $text -replace '(\s*</queries>)', ("`r`n        $ttsIntent`r`n    </queries>")
        }
    }
    Set-Content -LiteralPath $Path -Value $text -Encoding UTF8
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$client = Join-Path $root 'client'
$flutter = @(Get-Command flutter -CommandType Application -ErrorAction SilentlyContinue) |
    Where-Object { $_.Path } |
    Select-Object -First 1
if (-not $flutter) {
    throw 'Flutter is required. Install Flutter, add it to PATH, and run this script again.'
}

$stage = Join-Path ([IO.Path]::GetTempPath()) ('waste-android-' + [Guid]::NewGuid().ToString('N'))
$stageClient = Join-Path $stage 'client'
$stageApk = Join-Path $stageClient 'build\app\outputs\flutter-apk\app-debug.apk'
$manifest = Join-Path $stageClient 'android\app\src\main\AndroidManifest.xml'
$dist = Join-Path $root 'dist'
$destination = Join-Path $dist 'Waste-android-debug.apk'

try {
    Copy-ClientSources -Source $client -Destination $stageClient
    $stagePlatform = Join-Path $stageClient 'android'
    if ($SkipFlutterCreate) {
        $existingPlatform = Join-Path $client 'android'
        if (-not (Test-Path -LiteralPath $existingPlatform -PathType Container)) {
            throw '-SkipFlutterCreate requires an existing client\android directory.'
        }
        Copy-Item -LiteralPath $existingPlatform -Destination $stagePlatform -Recurse -Force
    } else {
        Push-Location $stageClient
        try {
            Invoke-NativeChecked -FilePath ([string]$flutter.Path) -ArgumentList @('create', '--platforms=android', '--project-name', 'waste', '.') -Description 'flutter create (Android staging project)'
        } finally {
            Pop-Location
        }
    }

    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "Android platform was not generated: $manifest"
    }
    Update-AndroidManifest -Path $manifest

    Push-Location $stageClient
    try {
        Invoke-NativeChecked -FilePath ([string]$flutter.Path) -ArgumentList @('pub', 'get') -Description 'flutter pub get (Android staging project)'
        Invoke-NativeChecked -FilePath ([string]$flutter.Path) -ArgumentList @('build', 'apk', '--debug') -Description 'flutter build apk --debug'
    } finally {
        Pop-Location
    }

    if (-not (Test-Path -LiteralPath $stageApk -PathType Leaf) -or (Get-Item -LiteralPath $stageApk -ErrorAction SilentlyContinue).Length -le 0) {
        throw "Flutter did not produce the expected debug APK: $stageApk"
    }
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    Copy-Item -LiteralPath $stageApk -Destination $destination -Force
    if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or (Get-Item -LiteralPath $destination -ErrorAction SilentlyContinue).Length -le 0) {
        throw "The debug APK could not be copied to $destination"
    }
    Write-Output "Created $destination (debug APK; not production-signed)"
} finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
