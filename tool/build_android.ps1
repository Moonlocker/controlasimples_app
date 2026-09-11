#Requires -Version 5.1
<#
.SYNOPSIS
    Gera o APK/AAB de release do Controla Simples com o ambiente Android correto.

.DESCRIPTION
    Detecta automaticamente o JDK e o Android SDK (portáteis em %LOCALAPPDATA%\Android
    ou instalações via Android Studio / variáveis de ambiente), configura JAVA_HOME /
    ANDROID_HOME e roda o build do Flutter. Ao final, copia o artefato para a pasta
    ..\dist.

.PARAMETER Target
    apk   -> gera apenas o APK de release (padrão)
    aab   -> gera apenas o App Bundle (Play Store)
    both  -> gera os dois

.PARAMETER Bump
    Incrementa o build number em pubspec.yaml antes de compilar (ex.: 1.0.0+1 -> 1.0.0+2).

.EXAMPLE
    .\tool\build_android.ps1
    .\tool\build_android.ps1 -Target both -Bump
#>
param(
    [ValidateSet('apk', 'aab', 'both')]
    [string]$Target = 'apk',
    [switch]$Bump
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Resolve-Jdk {
    $candidates = @(
        $env:JAVA_HOME,
        (Join-Path $env:LOCALAPPDATA 'Android\jdk17'),
        (Join-Path $env:LOCALAPPDATA 'Android\jdk21'),
        'C:\Program Files\Android\Android Studio\jbr',
        'C:\Program Files\Eclipse Adoptium'
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path (Join-Path $candidate 'bin\java.exe'))) { return $candidate }
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            $java = Get-ChildItem -Path $candidate -Filter 'java.exe' -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\bin\\java\.exe$' } | Select-Object -First 1
            if ($java) { return (Split-Path -Parent (Split-Path -Parent $java.FullName)) }
        }
    }
    throw 'JDK nao encontrado. Instale o JDK 17+ ou defina a variavel JAVA_HOME.'
}

function Resolve-AndroidSdk {
    $candidates = @(
        $env:ANDROID_HOME,
        $env:ANDROID_SDK_ROOT,
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path (Join-Path $candidate 'platform-tools'))) { return $candidate }
    }
    throw 'Android SDK nao encontrado. Instale o SDK ou defina a variavel ANDROID_HOME.'
}

$env:JAVA_HOME = Resolve-Jdk
$env:ANDROID_HOME = Resolve-AndroidSdk
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PATH = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:PATH"

Write-Host "JAVA_HOME    : $env:JAVA_HOME"
Write-Host "ANDROID_HOME : $env:ANDROID_HOME"

if ($Bump) {
    $pubspec = Join-Path $root 'pubspec.yaml'
    $content = [System.IO.File]::ReadAllText($pubspec)
    if ($content -match '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
        $newVersion = "$($matches[1])+$([int]$matches[2] + 1)"
        $content = $content -replace '(?m)^version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersion"
        [System.IO.File]::WriteAllText($pubspec, $content)
        Write-Host "Versao incrementada para $newVersion"
    }
}

Push-Location $root
try {
    $artifacts = @()
    if ($Target -eq 'apk' -or $Target -eq 'both') {
        flutter build apk --release
        if ($?) { $artifacts += 'build\app\outputs\flutter-apk\app-release.apk' }
    }
    if ($Target -eq 'aab' -or $Target -eq 'both') {
        flutter build appbundle --release
        if ($?) { $artifacts += 'build\app\outputs\bundle\release\app-release.aab' }
    }

    $version = ((Get-Content (Join-Path $root 'pubspec.yaml') | Select-String '^version:').ToString() -replace 'version:\s*', '')
    $dist = Join-Path (Split-Path -Parent $root) 'dist'
    New-Item -ItemType Directory -Force -Path $dist | Out-Null

    foreach ($relative in $artifacts) {
        $source = Join-Path $root $relative
        if (-not (Test-Path $source)) { continue }
        $extension = [System.IO.Path]::GetExtension($source)
        $name = "ControlaSimples-$version$extension"
        $destination = Join-Path $dist $name
        Copy-Item $source $destination -Force
        Write-Host "OK -> $destination" -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
