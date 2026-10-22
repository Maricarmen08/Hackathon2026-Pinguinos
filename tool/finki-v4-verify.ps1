# FINKI V4: verificación secuencial y sin escritura en desarrollo.
# No compila Android, no toca hackathon_pinguinos_dev, no borra cachés ni datos.
# Uso desde la raíz:  .\tool\finki-v4-verify.ps1            (Flutter + backend en memoria)
#                     .\tool\finki-v4-verify.ps1 -MySql     (además, MySQL aislado _test)
param([switch]$MySql)
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$logs = Join-Path $root 'build\tooling'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$summary = [ordered]@{}

function Step($name, $log, [scriptblock]$body) {
    Write-Host "`n== $name ==" -ForegroundColor Cyan
    & $body *>&1 | Tee-Object -FilePath (Join-Path $logs $log)
    $code = $LASTEXITCODE
    $summary[$name] = if ($code -eq 0) { 'OK' } else { "FALLO (código $code, ver build\tooling\$log)" }
}

Step 'flutter analyze' 'finki-v4-analyze.log' {
    & (Join-Path $PSScriptRoot 'flutter-local.ps1') analyze
}
Step 'flutter test' 'finki-v4-flutter-tests.log' {
    & (Join-Path $PSScriptRoot 'flutter-local.ps1') test --no-pub --concurrency=1
}
Push-Location (Join-Path $root 'backend')
try {
    Step 'npm test (memoria)' 'finki-v4-backend-tests.log' { npm.cmd test }
    if ($MySql) {
        $env:RUN_MYSQL_TESTS = '1'
        try { Step 'npm run test:mysql (_test)' 'finki-v4-mysql.log' { npm.cmd run test:mysql } }
        finally { Remove-Item Env:RUN_MYSQL_TESTS -ErrorAction SilentlyContinue }
    }
} finally { Pop-Location }

Write-Host "`n== Resumen FINKI V4 ==" -ForegroundColor Cyan
$summary.GetEnumerator() | ForEach-Object { Write-Host ("{0,-28} {1}" -f $_.Key, $_.Value) }
