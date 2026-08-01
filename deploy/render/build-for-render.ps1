<#
.SYNOPSIS
  Build Flutter web for Render (same-origin API) into server/public
#>
param(
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
  throw 'flutter not found'
}

$flutter = Resolve-Flutter -Hint $FlutterBat
Write-Host "==> Building Flutter web for Render (USE_API=true, API_BASE=.)"
& $flutter build web --release --dart-define=USE_API=true --dart-define=API_BASE=.
if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }

$webOut = Join-Path $Root 'build\web'
$publicDir = Join-Path $Root 'server\public'
if (Test-Path $publicDir) { Remove-Item $publicDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
Copy-Item -Path (Join-Path $webOut '*') -Destination $publicDir -Recurse -Force
Write-Host "Copied to $publicDir"
Write-Host "Done. Commit server/public and push, then deploy on Render."
