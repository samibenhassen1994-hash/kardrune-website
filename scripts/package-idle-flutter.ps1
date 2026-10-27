param([switch]$Push)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
if ((git branch --show-current).Trim() -ne 'feature/idle-flutter-web-migration') { throw 'Switch to the Flutter migration branch first.' }
if (git status --porcelain) { throw 'Working tree must be clean.' }
git fetch origin main
if ($LASTEXITCODE -ne 0) { throw 'Could not fetch origin/main.' }
$flutter = 'C:\Users\samib\develop\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) { $flutter = 'flutter' }
Push-Location (Join-Path $root 'idle_flutter')
try {
  & $flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'Flutter pub get failed.' }
  & $flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }
  & $flutter test
  if ($LASTEXITCODE -ne 0) { throw 'Flutter test failed.' }
  & $flutter build web --release --base-href /idle/
  if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed.' }
} finally { Pop-Location }
$build = Join-Path $root 'idle_flutter\build\web'
if (-not (Test-Path (Join-Path $build 'flutter_bootstrap.js'))) { throw 'Bootstrap missing.' }
if (-not (Test-Path (Join-Path $build 'assets\AssetManifest.bin'))) { throw 'Asset manifest missing.' }
if (-not (Select-String -Path (Join-Path $build 'index.html') -SimpleMatch '<base href="/idle/">' -Quiet)) { throw 'Incorrect base href.' }
$backup = "idle-before-flutter-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
git tag $backup origin/main
if ($LASTEXITCODE -ne 0) { throw 'Could not create backup tag.' }
git rm -r -- idle
if ($LASTEXITCODE -ne 0) { throw 'Failed to remove old tracked Idle files.' }
if (Test-Path (Join-Path $root 'idle')) { Remove-Item (Join-Path $root 'idle') -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $root 'idle') | Out-Null
Copy-Item (Join-Path $build '*') (Join-Path $root 'idle') -Recurse -Force
git add -A -- idle
if ($LASTEXITCODE -ne 0) { throw 'Could not stage new Idle files.' }
git diff --cached --check
if ($LASTEXITCODE -ne 0) { throw 'Staged changes failed validation.' }
git commit -m 'deploy: replace legacy Idle frontend with Flutter Web'
if ($LASTEXITCODE -ne 0) { throw 'Deployment commit failed.' }
Write-Host "New Flutter frontend staged. Rollback tag: $backup"
if ($Push) {
  git push origin feature/idle-flutter-web-migration
  if ($LASTEXITCODE -ne 0) { throw 'Branch push failed.' }
  git push origin $backup
  if ($LASTEXITCODE -ne 0) { throw 'Backup tag push failed.' }
  Write-Host 'Review the branch preview and merge PR only after login and PvP checks.'
} else { Write-Host 'Not pushed. Review Git changes, then run with -Push.' }
