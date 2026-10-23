param([string]$DeviceId='10AD370TQF002ZS', [switch]$AirplaneMode)
# DEBUG-only diagnostic: real microphone and pure PCM checks, no financial APIs.
# Speech is transient; reports only durations/frame counts, never microphone text.
$ErrorActionPreference='Stop'
if($DeviceId -notmatch '^[A-Za-z0-9:._-]+$'){throw 'Dispositivo no válido'}
$taskAdb='D:\Android\Sdk\platform-tools\adb.exe'
$taskPackage='pe.pinguinos.hackathon_pinguinos_mvp'
$taskRepo=Split-Path $PSScriptRoot -Parent
function Invoke-VoiceDevice([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments) {
  $taskPreference=$ErrorActionPreference
  try { $ErrorActionPreference='Continue'; $taskText=& $taskAdb -s $DeviceId @Arguments 2>&1; $taskExit=$LASTEXITCODE }
  finally { $ErrorActionPreference=$taskPreference }
  if($taskExit -ne 0){throw ('ADB: '+($taskText -join ' '))}
  return $taskText
}
$taskAirplane=((Invoke-VoiceDevice @('shell','settings','get','global','airplane_mode_on')) -join '').Trim()
$taskWifi=((Invoke-VoiceDevice @('shell','settings','get','global','wifi_on')) -join '').Trim()
$taskReverse=((Invoke-VoiceDevice @('reverse','--list')) -join '') -match 'tcp:3000'
$taskResults=@()
try {
  Invoke-VoiceDevice @('shell','run-as',$taskPackage,'mkdir','-p','files/offline_validation') | Out-Null
  Invoke-VoiceDevice @('shell',"run-as $taskPackage sh -c 'test -f files/offline_validation/result.json || printf %s {} > files/offline_validation/result.json'") | Out-Null
  if($AirplaneMode){
    Invoke-VoiceDevice @('shell','cmd','connectivity','airplane-mode','enable') | Out-Null
    Invoke-VoiceDevice @('shell','svc','wifi','disable') | Out-Null
    if($taskReverse){Invoke-VoiceDevice @('reverse','--remove','tcp:3000') | Out-Null}
  }
  foreach($taskCase in @(@('session',0,$false),@('mic',3,$false),@('mic',5,$false),@('mic',10,$false),@('mic',3,$true),@('mic',45,$false))){
    $taskRun=[guid]::NewGuid().ToString()
    Invoke-VoiceDevice @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
    Invoke-VoiceDevice @('shell','am','start','-W','-n',($taskPackage+'/.OfflineValidationActivity'),
      '--es','mode',$taskCase[0],'--es','run_id',$taskRun,'--ei','seconds',([string]$taskCase[1]),
      '--ez','cancel',([string]$taskCase[2]).ToLowerInvariant()) | Out-Null
    $taskDeadline=[DateTime]::UtcNow.AddSeconds(180)
    $taskResult=$null
    do {
      Start-Sleep -Milliseconds 500
      $taskRaw=Invoke-VoiceDevice @('shell','run-as',$taskPackage,'cat','files/offline_validation/result.json')
      try{$taskCandidate=($taskRaw -join '') | ConvertFrom-Json}catch{$taskCandidate=$null}
      if($taskCandidate.run_id -eq $taskRun){$taskResult=$taskCandidate}
    } while(-not $taskResult -and [DateTime]::UtcNow -lt $taskDeadline)
    if(-not $taskResult){throw 'La sesión Android no finalizó dentro del plazo'}
    $taskResults+=$taskResult
    $taskResults | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskRepo 'build/tooling/voice-session-device-results.json') -Encoding UTF8
    $taskResult | ConvertTo-Json -Compress
    if($taskResult.error){throw ('Sesión Android: '+$taskResult.error)}
    if($AirplaneMode -and $taskResult.airplane_mode -ne 1){throw 'Modo avión no verificado'}
  }
} finally {
  if($AirplaneMode){
    $taskRestore=if($taskAirplane -eq '1'){'enable'}else{'disable'}
    Invoke-VoiceDevice @('shell','cmd','connectivity','airplane-mode',$taskRestore) | Out-Null
    $taskRestoreWifi=if($taskWifi -eq '0'){'disable'}else{'enable'}
    Invoke-VoiceDevice @('shell','svc','wifi',$taskRestoreWifi) | Out-Null
    if($taskReverse){Invoke-VoiceDevice @('reverse','tcp:3000','tcp:3000') | Out-Null}
  }
}
