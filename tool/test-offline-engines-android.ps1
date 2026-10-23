param(
    [string]$DeviceId = '10AD370TQF002ZS',
    [switch]$AirplaneMode
)
# Runs the DEBUG-ONLY isolated activity; never enters financial UI or calls Express.
$ErrorActionPreference = 'Stop'
if ($DeviceId -notmatch '^[A-Za-z0-9:._-]+$') { throw 'Identificador de dispositivo no válido' }
$taskRepo = Split-Path $PSScriptRoot -Parent
$taskFixtures = Join-Path $taskRepo 'build\tooling\offline-fixtures'
$taskOutput = Join-Path $taskRepo 'build\tooling\offline-device-results.json'
$taskAdb = 'D:\Android\Sdk\platform-tools\adb.exe'
$taskPackage = 'pe.pinguinos.hackathon_pinguinos_mvp'
function Invoke-Device([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments) {
    $taskPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $taskText = & $taskAdb -s $DeviceId @Arguments 2>&1
        $taskExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $taskPreference }
    if ($taskExit -ne 0) { throw ('ADB: '+($taskText -join ' ')) }
    return $taskText
}
function Send-PrivateFixture([string]$Path) {
    $taskFileName = [IO.Path]::GetFileName($Path)
    if ($taskFileName -notmatch '^[a-z0-9_.-]+$') { throw 'Nombre de fixture no válido' }
    # Short acknowledged shell commands avoid truncated stdin/EOF on this ADB.
    # Base64 contains no shell metacharacters; names are validated above.
    $taskEncoded = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
    for ($taskOffset=0; $taskOffset -lt $taskEncoded.Length; $taskOffset+=12000) {
        $taskChunk = $taskEncoded.Substring($taskOffset, [Math]::Min(12000,$taskEncoded.Length-$taskOffset))
        $taskRedirect = if ($taskOffset -eq 0) { '>' } else { '>>' }
        $taskRemote = "run-as $taskPackage sh -c 'printf %s $taskChunk | base64 -d $taskRedirect files/offline_validation/$taskFileName'"
        Invoke-Device @('shell',$taskRemote) | Out-Null
    }
    $taskExpected = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $taskActual = ((Invoke-Device @('shell','run-as',$taskPackage,'sha256sum',('files/offline_validation/'+$taskFileName))) -join '').Split(' ')[0]
    if ($taskActual -ne $taskExpected) { throw ('Fixture truncado o alterado: '+$taskFileName) }
}
$taskPriorAirplane = ((Invoke-Device @('shell','settings','get','global','airplane_mode_on')) -join '').Trim()
$taskPriorWifi = ((Invoke-Device @('shell','settings','get','global','wifi_on')) -join '').Trim()
$taskHadReverse = ((Invoke-Device @('reverse','--list')) -join '') -match 'tcp:3000'
$taskResults = @()
try {
    if ($AirplaneMode) {
        Invoke-Device @('shell','cmd','connectivity','airplane-mode','enable') | Out-Null
        Invoke-Device @('shell','svc','wifi','disable') | Out-Null
        if ($taskHadReverse) { Invoke-Device @('reverse','--remove','tcp:3000') | Out-Null }
    }
    Invoke-Device @('shell','run-as',$taskPackage,'mkdir','-p','files/offline_validation') | Out-Null
    $taskNames = @('voice-real.wav','silence.wav','receipt.png','ticket.png','yape.png','plin.png','cropped.png','blurred.png')
    foreach ($taskName in $taskNames) {
        $taskPath = Join-Path $taskFixtures $taskName
        if (-not (Test-Path -LiteralPath $taskPath)) { throw ('Falta fixture: '+$taskName) }
        Send-PrivateFixture $taskPath
    }
    # Repeat exactly the same Yape bytes without creating proposals or links.
    foreach ($taskName in ($taskNames + @('yape.png'))) {
        $taskMode = if ($taskName.EndsWith('.wav')) { 'audio' } else { 'ocr' }
        $taskRun = [guid]::NewGuid().ToString()
        Invoke-Device @('shell','am','start','-W','-n',($taskPackage+'/.OfflineValidationActivity'),
            '--es','mode',$taskMode,'--es','input',$taskName,'--es','run_id',$taskRun) | Out-Null
        $taskResult = $null
        $taskDeadline = [DateTime]::UtcNow.AddSeconds(50)
        do {
            Start-Sleep -Milliseconds 250
            $taskPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'SilentlyContinue'
                $taskRaw = & $taskAdb -s $DeviceId shell run-as $taskPackage cat files/offline_validation/result.json 2>$null
                $taskReadExit = $LASTEXITCODE
            } finally { $ErrorActionPreference = $taskPreference }
            if ($taskReadExit -eq 0) {
                try { $taskCandidate = ($taskRaw -join '') | ConvertFrom-Json } catch { $taskCandidate = $null }
                if ($taskCandidate.run_id -eq $taskRun) { $taskResult = $taskCandidate }
            }
        } while (-not $taskResult -and [DateTime]::UtcNow -lt $taskDeadline)
        if (-not $taskResult) { throw ('Sin resultado Android: '+$taskName) }
        if ($AirplaneMode -and $taskResult.airplane_mode -ne 1) { throw 'No se verificó modo avión' }
        $taskResults += $taskResult
        $taskResults | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $taskOutput -Encoding UTF8
        $taskResult | ConvertTo-Json -Compress
        if ($taskResult.error) { throw ('Error de motor: '+$taskResult.error) }
    }
} finally {
    if ($AirplaneMode) {
        $taskRestore = if ($taskPriorAirplane -eq '1') { 'enable' } else { 'disable' }
        Invoke-Device @('shell','cmd','connectivity','airplane-mode',$taskRestore) | Out-Null
        $taskWifiRestore = if ($taskPriorWifi -eq '0') { 'disable' } else { 'enable' }
        Invoke-Device @('shell','svc','wifi',$taskWifiRestore) | Out-Null
        if ($taskHadReverse) { Invoke-Device @('reverse','tcp:3000','tcp:3000') | Out-Null }
    }
}
