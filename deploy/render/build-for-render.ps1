<#
.SYNOPSIS
  Build Flutter web for Render (same-origin API) into server/public
#>
param(
  [string]$FlutterBat = '',
  [string]$GoogleMapsBrowserKey = $env:GOOGLE_MAPS_BROWSER_KEY
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
$defines = @(
  '--dart-define=USE_API=true',
  '--dart-define=API_BASE=.'
)
if ($GoogleMapsBrowserKey) {
  $defines += "--dart-define=GOOGLE_MAPS_BROWSER_KEY=$GoogleMapsBrowserKey"
}
foreach ($k in @(
  'FIREBASE_API_KEY','FIREBASE_APP_ID','FIREBASE_PROJECT_ID','FIREBASE_MESSAGING_SENDER_ID',
  'FIREBASE_AUTH_DOMAIN','FIREBASE_STORAGE_BUCKET','OMISE_PUBLIC_KEY','GOOGLE_SERVER_CLIENT_ID','GOOGLE_WEB_CLIENT_ID'
)) {
  $v = [Environment]::GetEnvironmentVariable($k)
  if ($v) { $defines += "--dart-define=$k=$v" }
}

Write-Host "==> Building Flutter web for Render (USE_API=true, API_BASE=.)"
# pwa-strategy=none: ไม่สร้าง service worker ใหม่ ใช้ tombstone ใน web/ แทน
& $flutter build web --release --pwa-strategy=none @defines
if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }

$webOut = Join-Path $Root 'build\web'
$publicDir = Join-Path $Root 'server\public'
if (Test-Path $publicDir) { Remove-Item $publicDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
Copy-Item -Path (Join-Path $webOut '*') -Destination $publicDir -Recurse -Force

# flutter build เขียน flutter_service_worker.js ว่างทับ ต้องเอา tombstone จาก web/ ใส่กลับ
$swSource = Join-Path $Root 'web\flutter_service_worker.js'
if (Test-Path $swSource) {
  Copy-Item -Path $swSource -Destination (Join-Path $publicDir 'flutter_service_worker.js') -Force
}

if ($GoogleMapsBrowserKey) {
  $indexPath = Join-Path $publicDir 'index.html'
  if (Test-Path $indexPath) {
    $html = Get-Content -Raw -Path $indexPath
    $html = $html -replace 'name="google-maps-api-key" content=""',
      ("name=`"google-maps-api-key`" content=`"$GoogleMapsBrowserKey`"")
    Set-Content -Path $indexPath -Value $html -Encoding UTF8
  }
}

Write-Host "Copied to $publicDir"
Write-Host "Done. Commit server/public and push, then deploy on Render."
