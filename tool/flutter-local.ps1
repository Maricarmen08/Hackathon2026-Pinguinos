# Mantiene temporales y cachés de esta app en su propia unidad, sin tocar otros proyectos.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$localBuild = Join-Path $projectRoot 'build\tooling'
New-Item -ItemType Directory -Path (Join-Path $localBuild 'temp') -Force | Out-Null
$env:TEMP = Join-Path $localBuild 'temp'
$env:TMP = $env:TEMP
$env:GRADLE_USER_HOME = Join-Path $localBuild 'gradle-home'
if (-not $env:JAVA_TOOL_OPTIONS) {
    # Gradle owns its heap limit; do not inject a second conflicting -Xmx.
    $env:JAVA_TOOL_OPTIONS = '-XX:ActiveProcessorCount=2 -XX:+UseSerialGC -XX:TieredStopAtLevel=1'
}
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExecutable = if ($flutterCommand) { $flutterCommand.Source } elseif (Test-Path 'D:\desarrollo\flutter\bin\flutter.bat') { 'D:\desarrollo\flutter\bin\flutter.bat' } else { throw 'Agrega Flutter al PATH.' }
$buildLock = $null
try {
    $buildLock = [System.IO.File]::Open((Join-Path $localBuild 'flutter-local.lock'),
        [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None)
} catch {
    throw 'Ya hay otra ejecución de flutter-local.ps1 en este proyecto. Espera a que termine.'
}
Push-Location $projectRoot
try { & $flutterExecutable @args; $result = $LASTEXITCODE } finally { Pop-Location; $buildLock.Dispose() }
exit $result
