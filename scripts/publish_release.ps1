# Publish release artifacts to backend/releases and register them via /api/v1/update/releases.
#
# Usage examples:
#   powershell -ExecutionPolicy Bypass -File scripts/publish_release.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/publish_release.ps1 -Platform android
#   powershell -ExecutionPolicy Bypass -File scripts/publish_release.ps1 -SkipBuild
#   $env:RELEASE_API_BASE_URL='https://api.example.com'
#   $env:RELEASE_API_TOKEN='<jwt-access-token>'
#   powershell -ExecutionPolicy Bypass -File scripts/publish_release.ps1 -Mandatory -Notes 'Hotfix'

[CmdletBinding()]
param(
    [ValidateSet('android', 'windows', 'both')]
    [string]$Platform = 'both',

    [string]$Version,

    [switch]$Mandatory,

    [string]$MinSupportedVersion,

    [string]$Notes,

    [switch]$SkipBuild,

    [switch]$SkipRegister,

    [string]$ApiBaseUrl = $env:RELEASE_API_BASE_URL,

    [string]$AccessToken = $env:RELEASE_API_TOKEN,

    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-Checked {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [string]$StepName
    )

    Write-Step $StepName
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $Command $($Arguments -join ' ')"
    }
}

function Get-SemverFromPubspec {
    param([string]$PubspecPath)

    if (-not (Test-Path $PubspecPath)) {
        throw "pubspec.yaml not found: $PubspecPath"
    }

    $content = Get-Content $PubspecPath -Raw
    $match = [regex]::Match($content, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+[0-9]+)?\s*$')
    if (-not $match.Success) {
        throw "Could not parse semver from pubspec.yaml. Expected version like 1.5.0+6"
    }

    return $match.Groups[1].Value
}

function New-ArtifactRecord {
    param(
        [ValidateSet('android', 'windows')]
        [string]$ArtifactPlatform,

        [string]$SourcePath,

        [string]$TargetDir,

        [string]$ReleaseVersion
    )

    if (-not (Test-Path $SourcePath)) {
        throw "Build artifact not found: $SourcePath"
    }

    $extension = if ($ArtifactPlatform -eq 'android') { 'apk' } else { 'exe' }
    $fileName = "collab_notes_${ReleaseVersion}_${ArtifactPlatform}.$extension"
    $targetPath = Join-Path $TargetDir $fileName

    Copy-Item -Path $SourcePath -Destination $targetPath -Force

    $file = Get-Item $targetPath
    $hash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash

    return [PSCustomObject]@{
        Platform    = $ArtifactPlatform
        SourcePath  = $SourcePath
        TargetPath  = $targetPath
        DownloadUrl = "/releases/$fileName"
        Size        = [int64]$file.Length
        Sha256      = $hash
    }
}

function Register-Release {
    param(
        [string]$BaseUrl,
        [string]$Token,
        [string]$ReleaseVersion,
        [bool]$IsMandatory,
        [string]$MinVersion,
        [string]$ReleaseNotes,
        [object]$Artifact
    )

    $normalizedBase = $BaseUrl.TrimEnd('/')
    $uri = "$normalizedBase/api/v1/update/releases"

    $payload = @{
        version             = $ReleaseVersion
        platform            = $Artifact.Platform
        downloadUrl         = $Artifact.DownloadUrl
        sha256              = $Artifact.Sha256
        fileSize            = [int64]$Artifact.Size
        mandatory           = $IsMandatory
        minSupportedVersion = if ([string]::IsNullOrWhiteSpace($MinVersion)) { $null } else { $MinVersion }
        notes               = if ([string]::IsNullOrWhiteSpace($ReleaseNotes)) { $null } else { $ReleaseNotes }
    }

    $body = $payload | ConvertTo-Json -Depth 5 -Compress

    Write-Step "Registering $($Artifact.Platform) release in API"
    $response = Invoke-RestMethod -Method Post -Uri $uri -Headers @{
        Authorization = "Bearer $Token"
    } -ContentType 'application/json; charset=utf-8' -Body $body

    return $response
}

$flutterAppDir = Join-Path $ProjectRoot 'collab_notes_app'
$backendDir = Join-Path $ProjectRoot 'backend'
$releasesDir = Join-Path $backendDir 'releases'
$pubspecPath = Join-Path $flutterAppDir 'pubspec.yaml'

if (-not $Version) {
    $Version = Get-SemverFromPubspec -PubspecPath $pubspecPath
}

if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
    throw "Version must be x.y.z. Received: $Version"
}

if ($MinSupportedVersion -and ($MinSupportedVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$')) {
    throw "MinSupportedVersion must be x.y.z. Received: $MinSupportedVersion"
}

$doAndroid = $Platform -in @('android', 'both')
$doWindows = $Platform -in @('windows', 'both')

if (-not $SkipBuild) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'flutter command not found in PATH'
    }

    Push-Location $flutterAppDir
    try {
        Invoke-Checked -Command 'flutter' -Arguments @('pub', 'get') -StepName 'flutter pub get'

        if ($doAndroid) {
            Invoke-Checked -Command 'flutter' -Arguments @('build', 'apk', '--release') -StepName 'flutter build apk --release'
        }

        if ($doWindows) {
            Invoke-Checked -Command 'flutter' -Arguments @('build', 'windows', '--release') -StepName 'flutter build windows --release'
        }
    }
    finally {
        Pop-Location
    }
}

$null = New-Item -ItemType Directory -Path $releasesDir -Force

$artifacts = @()

if ($doAndroid) {
    $androidSource = Join-Path $flutterAppDir 'build\app\outputs\flutter-apk\app-release.apk'
    $artifacts += New-ArtifactRecord -ArtifactPlatform 'android' -SourcePath $androidSource -TargetDir $releasesDir -ReleaseVersion $Version
}

if ($doWindows) {
    $windowsSource = Join-Path $flutterAppDir 'build\windows\x64\runner\Release\collab_notes.exe'
    $artifacts += New-ArtifactRecord -ArtifactPlatform 'windows' -SourcePath $windowsSource -TargetDir $releasesDir -ReleaseVersion $Version
}

Write-Host ''
Write-Host 'Copied artifacts:' -ForegroundColor Green
$artifacts | Select-Object Platform, TargetPath, DownloadUrl, Size, Sha256 | Format-Table -AutoSize

$shouldRegister = -not $SkipRegister
if ($shouldRegister -and ([string]::IsNullOrWhiteSpace($ApiBaseUrl) -or [string]::IsNullOrWhiteSpace($AccessToken))) {
    Write-Warning 'Skipping API registration: set RELEASE_API_BASE_URL and RELEASE_API_TOKEN, or pass -ApiBaseUrl and -AccessToken.'
    $shouldRegister = $false
}

if ($shouldRegister) {
    foreach ($artifact in $artifacts) {
        $registered = Register-Release -BaseUrl $ApiBaseUrl -Token $AccessToken -ReleaseVersion $Version -IsMandatory ([bool]$Mandatory) -MinVersion $MinSupportedVersion -ReleaseNotes $Notes -Artifact $artifact
        Write-Host "Registered $($artifact.Platform): id=$($registered.id) version=$($registered.version)" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host "Done. Version: $Version" -ForegroundColor Green
Write-Host "Backend releases dir: $releasesDir" -ForegroundColor Green
