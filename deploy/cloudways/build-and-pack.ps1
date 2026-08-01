<#
.SYNOPSIS
  Build Flutter Web for Cloudways (PHP / Custom App) and pack upload folder.

.PARAMETER ApiBase
  API URL when -Demo is not set, e.g. https://api.example.com

.PARAMETER Mode
  static = pack build/web + .htaccess for public_html (recommended on free Cloudways)
  node   = pack server + public (only if your plan has Node)

.PARAMETER Demo
  Build with USE_API=false (no backend required). Recommended for free PHP/Custom App.

.EXAMPLE
  .\deploy\cloudways\build-and-pack.ps1 -Mode static -Demo
  .\deploy\cloudways\build-and-pack.ps1 -Mode static -ApiBase https://api.example.com
#>
param(
  [ValidateSet('node', 'static')]
  [string]$Mode = 'static',
  [string]$ApiBase = '.',
  [switch]$Demo,
  [string]$FlutterBat = ''
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $Root

function Resolve-Flutter {
  param([string]$Hint)
  if ($Hint -and (Test-Path $Hint)) { return $Hint }
  if (Get-Command flutter -ErrorAction SilentlyContinue) { return 'flutter' }
  $puro = Join-Path $env:USERPROFILE '.puro\envs\infinity\flutter\bin\flutter.bat'
  if (Test-Path $puro) { return $puro }
  throw 'flutter not found. Pass -FlutterBat or install Flutter / add to PATH.'
}

$flutter = Resolve-Flutter -Hint $FlutterBat
$useApi = if ($Demo) { 'false' } else { 'true' }

Write-Host "==> Flutter: $flutter"
Write-Host "==> Mode=$Mode Demo=$Demo USE_API=$useApi ApiBase=$ApiBase"

$defineArgs = @(
  'build', 'web', '--release',
  "--dart-define=USE_API=$useApi"
)
if (-not $Demo) {
  $defineArgs += "--dart-define=API_BASE=$ApiBase"
}

& $flutter @defineArgs
if ($LASTEXITCODE -ne 0) { throw "flutter build web failed ($LASTEXITCODE)" }

$webOut = Join-Path $Root 'build\web'
$htaccessSrc = Join-Path $Root 'web\.htaccess'
if (Test-Path $htaccessSrc) {
  Copy-Item $htaccessSrc (Join-Path $webOut '.htaccess') -Force
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$dist = Join-Path $Root 'deploy\cloudways\dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

if ($Mode -eq 'static') {
  $packDir = Join-Path $dist "static-$stamp"
  New-Item -ItemType Directory -Force -Path $packDir | Out-Null
  Copy-Item -Path (Join-Path $webOut '*') -Destination $packDir -Recurse -Force
  if (Test-Path (Join-Path $webOut '.htaccess')) {
    Copy-Item (Join-Path $webOut '.htaccess') (Join-Path $packDir '.htaccess') -Force
  }
  # Optional empty PHP so some panels detect the app; Flutter still uses index.html
  $phpStub = Join-Path $packDir 'index.php'
  if (-not (Test-Path $phpStub)) {
    Set-Content -Path $phpStub -Value @'
<?php
// Cloudways PHP/Custom App: prefer Flutter index.html
$flutter = __DIR__ . DIRECTORY_SEPARATOR . 'index.html';
if (is_file($flutter)) {
  header('Content-Type: text/html; charset=UTF-8');
  readfile($flutter);
  exit;
}
http_response_code(404);
echo 'index.html missing — upload Flutter web build to public_html';
'@ -Encoding UTF8
  }
  Write-Host ""
  Write-Host "Ready for PHP / Custom App (public_html):"
  Write-Host "  $packDir"
  Write-Host "Upload ALL contents into public_html (keep .htaccess)."
} else {
  if ($Demo) {
    Write-Host "Warning: node mode with -Demo still packs API sources; web will not call API."
  }
  $publicDir = Join-Path $Root 'server\public'
  if (Test-Path $publicDir) { Remove-Item $publicDir -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
  Copy-Item -Path (Join-Path $webOut '*') -Destination $publicDir -Recurse -Force
  if (Test-Path (Join-Path $webOut '.htaccess')) {
    Copy-Item (Join-Path $webOut '.htaccess') (Join-Path $publicDir '.htaccess') -Force
  }

  $packDir = Join-Path $dist "node-$stamp"
  New-Item -ItemType Directory -Force -Path $packDir | Out-Null
  $serverSrc = Join-Path $Root 'server'
  Copy-Item (Join-Path $serverSrc 'package.json') $packDir -Force
  if (Test-Path (Join-Path $serverSrc 'package-lock.json')) {
    Copy-Item (Join-Path $serverSrc 'package-lock.json') $packDir -Force
  }
  Copy-Item (Join-Path $serverSrc 'src') (Join-Path $packDir 'src') -Recurse -Force
  Copy-Item $publicDir (Join-Path $packDir 'public') -Recurse -Force
  Copy-Item (Join-Path $Root 'deploy\cloudways\env.example') (Join-Path $packDir 'env.example') -Force

  Write-Host ""
  Write-Host "Ready for Node upload (paid Node stack only):"
  Write-Host "  $packDir"
}

Write-Host "Done."
