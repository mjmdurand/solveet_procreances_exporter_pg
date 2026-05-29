$ErrorActionPreference = "Stop"

$npgsqlVersion = "3.2.7"
$driversDir    = Join-Path $PSScriptRoot "drivers"
$targetDll     = Join-Path $driversDir "Npgsql40.dll"

Write-Host "=== Setup Npgsql $npgsqlVersion ==="

if (Test-Path $targetDll) {
    Write-Host "OK — $targetDll déjà présent, rien à faire."
    exit 0
}

New-Item -ItemType Directory -Force -Path $driversDir | Out-Null

# Localiser ou télécharger nuget.exe
$nuget = (Get-Command nuget -ErrorAction SilentlyContinue)?.Source
if (-not $nuget) {
    $nuget = Join-Path $env:TEMP "nuget.exe"
    if (-not (Test-Path $nuget)) {
        Write-Host "Téléchargement de nuget.exe..."
        Invoke-WebRequest "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nuget -UseBasicParsing
    }
}

# Télécharger le package Npgsql
$tmpDir = Join-Path $env:TEMP "npgsql_setup"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

Write-Host "Téléchargement de Npgsql $npgsqlVersion..."
& $nuget install Npgsql -Version $npgsqlVersion -OutputDirectory $tmpDir `
    -Source "https://api.nuget.org/v3/index.json" -NonInteractive | Out-Null

$src = Join-Path $tmpDir "Npgsql.$npgsqlVersion\lib\netstandard2.0\Npgsql.dll"
if (-not (Test-Path $src)) {
    throw "DLL introuvable après installation : $src"
}

Copy-Item $src -Destination $targetDll
Write-Host "OK — Npgsql $npgsqlVersion copié dans drivers\Npgsql40.dll"

Remove-Item $tmpDir -Recurse -Force
