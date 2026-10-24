param(
    [string]$GoogleWebClientId = $env:GOOGLE_WEB_CLIENT_ID,
    [string]$ApiBaseUrl = 'https://hackathon2026-pinguinos.onrender.com/api/v1',
    [switch]$PrepareBackend
)

$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$GoogleWebClientId = ([string]$GoogleWebClientId).Trim()
$ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')
if ($GoogleWebClientId -notmatch '^\d+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$') {
    throw 'Indica el Client ID WEB publico mediante -GoogleWebClientId o GOOGLE_WEB_CLIENT_ID. No uses un Client Secret.'
}
$api = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$api) -or
    $api.Scheme -ne 'https' -or $api.IsLoopback -or $api.UserInfo -or
    $api.Query -or $api.Fragment -or $api.AbsolutePath -ne '/api/v1') {
    throw 'La compilacion publicada requiere una API HTTPS no local con ruta /api/v1, sin credenciales ni parametros.'
}

Push-Location $project
try {
    & "$PSScriptRoot\flutter-local.ps1" build web --release --no-tree-shake-icons --no-wasm-dry-run --output build/web `
        "--dart-define=GOOGLE_WEB_CLIENT_ID=$GoogleWebClientId" `
        "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'La compilacion Web fallo. No se preparo backend/web_build.' }
    $javascript = [IO.File]::ReadAllText((Join-Path $project 'build/web/main.dart.js'))
    if (-not $javascript.Contains($GoogleWebClientId) -or -not $javascript.Contains($ApiBaseUrl)) {
        throw 'El artefacto no contiene el Client ID Web y la API HTTPS indicados. No se preparo backend/web_build.'
    }
    if ($PrepareBackend) {
        $destination = Join-Path $project 'backend/web_build'
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Copy-Item -Path (Join-Path $project 'build/web/*') -Destination $destination -Recurse -Force
        Write-Output 'backend/web_build actualizado localmente. Revisar y publicar con autorizacion; no se ha desplegado nada.'
    } else {
        Write-Output 'Web release verificada en build/web. Usar -PrepareBackend para preparar la carpeta que sirve Express.'
    }
} finally {
    Pop-Location
}
