$ErrorActionPreference = 'Stop'

flutter build web --release --base-href /idle/

$index = Get-Content -Raw -LiteralPath 'build/web/index.html'
if ($index -notmatch '<base href="/idle/">') {
  throw 'Release build does not contain the /idle/ base href.'
}

Write-Host 'Release candidate ready in idle_flutter/build/web (not deployed).'
