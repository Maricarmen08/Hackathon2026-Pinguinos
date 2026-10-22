# FINKI: valida database\hackathon_pinguinos_dev.sql en una base TEMPORAL nueva.
#   - Crea hackathon_pinguinos_install_check importando el SQL único.
#   - Compara su estructura con hackathon_pinguinos_dev SOLO LECTURA (si existe).
#   - Ejecuta el recorrido real de la API (registro, negocio, ventas, fiados, PDF, IA con doble).
# Nunca escribe en hackathon_pinguinos_dev ni en hackathon_pinguinos_test.
#
# Uso, desde la raíz del repositorio, con Laragon/MySQL iniciado:
#   .\tool\finki-verify-install.ps1               (conserva la base temporal para inspección)
#   .\tool\finki-verify-install.ps1 -DropAfter    (al terminar borra SOLO la base temporal)
#   .\tool\finki-verify-install.ps1 -AdminUser root -Port 3306
param(
    [string]$AdminUser = 'root',
    [string]$DbHost = '127.0.0.1',
    [int]$Port = 3306,
    [switch]$DropAfter
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$backend = Join-Path $root 'backend'
$logs = Join-Path $root 'build\tooling'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$log = Join-Path $logs 'finki-install-check.log'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Instala Node.js 22 o superior.' }
if (-not (Test-Path (Join-Path $backend 'node_modules\mysql2'))) {
    throw 'Faltan dependencias del backend. Ejecuta primero: cd backend; npm.cmd install'
}

Write-Host "Usuario administrador MySQL: $AdminUser@$DbHost`:$Port"
$secure = Read-Host 'Contraseña de ese usuario (Enter si está vacía, como en Laragon por defecto)' -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

$env:FINKI_ADMIN_USER = $AdminUser
$env:FINKI_ADMIN_PASSWORD = $plain
$env:DB_HOST = $DbHost
$env:DB_PORT = "$Port"
$arguments = @('scripts\verify-install.js', '--install-check')
if ($DropAfter) { $arguments += '--drop-after' }
Push-Location $backend
try {
    & node @arguments 2>&1 | Tee-Object -FilePath $log
    $code = $LASTEXITCODE
} finally {
    Pop-Location
    Remove-Item Env:FINKI_ADMIN_PASSWORD, Env:FINKI_ADMIN_USER, Env:DB_HOST, Env:DB_PORT -ErrorAction SilentlyContinue
    $plain = $null
}
Write-Host "`nLog guardado en build\tooling\finki-install-check.log (sin contraseñas)."
exit $code
