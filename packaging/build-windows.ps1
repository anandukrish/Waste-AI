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

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$client = Join-Path $root 'client'
$flutter = @(Get-Command flutter -CommandType Application -ErrorAction SilentlyContinue) |
    Where-Object { $_.Path } |
    Select-Object -First 1
if (-not $flutter) {
    throw 'Flutter is required. Install Flutter, add it to PATH, and run this script again.'
}

$isccCandidates = @(
    Get-Command iscc -CommandType Application -ErrorAction SilentlyContinue | ForEach-Object { $_.Source }
    if ($env:LOCALAPPDATA) {
        Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'
    }
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
    'C:\Program Files\Inno Setup 6\ISCC.exe'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
$isccCandidates = @($isccCandidates)
if ($isccCandidates.Count -eq 0) {
    throw 'Inno Setup is required. Install Inno Setup 6 and run this script again.'
}

$stage = Join-Path ([IO.Path]::GetTempPath()) ('waste-windows-' + [Guid]::NewGuid().ToString('N'))
$stageClient = Join-Path $stage 'client'
$stageRelease = Join-Path $stageClient 'build\windows\x64\runner\Release'
$isccOutput = Join-Path $stage 'installer-output'
$dist = Join-Path $root 'dist'
$installer = Join-Path $dist 'Waste-AI-Setup.exe'

try {
    Copy-ClientSources -Source $client -Destination $stageClient
    $stagePlatform = Join-Path $stageClient 'windows'
    if ($SkipFlutterCreate) {
        $existingPlatform = Join-Path $client 'windows'
        if (-not (Test-Path -LiteralPath $existingPlatform -PathType Container)) {
            throw '-SkipFlutterCreate requires an existing client\windows directory.'
        }
        Copy-Item -LiteralPath $existingPlatform -Destination $stagePlatform -Recurse -Force
    } else {
        Push-Location $stageClient
        try {
            Invoke-NativeChecked -FilePath ([string]$flutter.Path) -ArgumentList @('create', '--platforms=windows', '--project-name', 'waste', '.') -Description 'flutter create (Windows staging project)'
        } finally {
            Pop-Location
        }
    }

    Push-Location $stageClient
    try {
        Invoke-NativeChecked -FilePath ([string]$flutter.Path) -ArgumentList @('pub', 'get') -Description 'flutter pub get (Windows staging project)'
        Invoke-NativeChecked -FilePath ([string]$flutter.Path) -ArgumentList @('build', 'windows', '--release') -Description 'flutter build windows --release'
    } finally {
        Pop-Location
    }

    $nativeExe = Join-Path $stageRelease 'waste.exe'
    if (-not (Test-Path -LiteralPath $nativeExe -PathType Leaf) -or (Get-Item -LiteralPath $nativeExe -ErrorAction SilentlyContinue).Length -le 0) {
        throw "Flutter did not produce the expected native executable: $nativeExe"
    }
    $preview = Join-Path $client 'web-preview\index.html'
    if (-not (Test-Path -LiteralPath $preview -PathType Leaf)) {
        throw "The companion browser preview is required: $preview"
    }

    New-Item -ItemType Directory -Force -Path $isccOutput | Out-Null
    $iscc = @($isccCandidates)[0]
    $startedAt = [DateTime]::UtcNow
    Invoke-NativeChecked -FilePath $iscc -ArgumentList @(
        "/DSourceDir=$stageRelease",
        "/DProjectRoot=$root",
        "/O$isccOutput",
        (Join-Path $PSScriptRoot 'Waste.iss')
    ) -Description 'Inno Setup compiler'

    $builtInstaller = Join-Path $isccOutput 'Waste-AI-Setup.exe'
    if (-not (Test-Path -LiteralPath $builtInstaller -PathType Leaf) -or (Get-Item -LiteralPath $builtInstaller -ErrorAction SilentlyContinue).Length -le 0) {
        throw "Inno Setup completed without creating $builtInstaller"
    }
    if ((Get-Item -LiteralPath $builtInstaller).LastWriteTimeUtc -lt $startedAt) {
        throw "Inno Setup did not produce a fresh installer: $builtInstaller"
    }

    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    Copy-Item -LiteralPath $builtInstaller -Destination $installer -Force
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf) -or (Get-Item -LiteralPath $installer -ErrorAction SilentlyContinue).Length -le 0) {
        throw "The installer could not be copied to $installer"
    }
    Write-Output "Created $installer"
} finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
