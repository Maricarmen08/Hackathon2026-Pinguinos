param([Parameter(Mandatory=$true)][string]$SourceImagePath,
  [string]$CameraEvidenceToken, [string]$DeviceId='10AD370TQF002ZS', [switch]$AirplaneMode)
# Deterministic test transforms only. Source and business originals stay unchanged.
$ErrorActionPreference='Stop'
if($DeviceId -notmatch '^[A-Za-z0-9:._-]+$'){throw 'Dispositivo no válido'}
if($CameraEvidenceToken -and $CameraEvidenceToken -notmatch '^[a-f0-9]{64}$'){throw 'Token no válido'}
$taskAdb='D:\Android\Sdk\platform-tools\adb.exe'
$taskPackage='pe.pinguinos.hackathon_pinguinos_mvp'
$taskRepo=Split-Path $PSScriptRoot -Parent
$taskFixtures=Join-Path $taskRepo 'build/tooling/receipt-fixtures'
New-Item -ItemType Directory -Force -Path $taskFixtures | Out-Null
Add-Type -AssemblyName System.Drawing
$taskSource=Resolve-Path -LiteralPath $SourceImagePath
Copy-Item -LiteralPath $taskSource.Path -Destination (Join-Path $taskFixtures 'receipt-source.png') -Force
$taskBitmap=[Drawing.Bitmap]::FromFile($taskSource.Path)
try {
  foreach($taskAngle in @(90,180,270)) {
    $taskCopy=$taskBitmap.Clone()
    try {
      $taskRotation=[Enum]::Parse([Drawing.RotateFlipType],('Rotate'+$taskAngle+'FlipNone'))
      $taskCopy.RotateFlip($taskRotation)
      $taskCopy.Save((Join-Path $taskFixtures ('receipt-rotate'+$taskAngle+'.png')),[Drawing.Imaging.ImageFormat]::Png)
    } finally {$taskCopy.Dispose()}
  }
  $taskRect=New-Object Drawing.Rectangle 0,0,$taskBitmap.Width,([int]($taskBitmap.Height*.60))
  $taskCrop=$taskBitmap.Clone($taskRect,$taskBitmap.PixelFormat)
  try {$taskCrop.Save((Join-Path $taskFixtures 'receipt-cropped.png'),[Drawing.Imaging.ImageFormat]::Png)} finally {$taskCrop.Dispose()}
  $taskSmall=New-Object Drawing.Bitmap 60,80
  $taskG=[Drawing.Graphics]::FromImage($taskSmall)
  try {$taskG.DrawImage($taskBitmap,0,0,60,80)} finally {$taskG.Dispose()}
  $taskBlur=New-Object Drawing.Bitmap $taskBitmap.Width,$taskBitmap.Height
  $taskG=[Drawing.Graphics]::FromImage($taskBlur)
  try {$taskG.DrawImage($taskSmall,0,0,$taskBitmap.Width,$taskBitmap.Height)
    $taskBlur.Save((Join-Path $taskFixtures 'receipt-blurred.png'),[Drawing.Imaging.ImageFormat]::Png)
  } finally {$taskG.Dispose();$taskBlur.Dispose();$taskSmall.Dispose()}
} finally {$taskBitmap.Dispose()}
function Invoke-ReceiptDevice([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments) {
  $taskPreference=$ErrorActionPreference
  try {$ErrorActionPreference='Continue';$taskText=& $taskAdb -s $DeviceId @Arguments 2>&1;$taskExit=$LASTEXITCODE}
  finally {$ErrorActionPreference=$taskPreference}
  if($taskExit -ne 0){throw ('ADB: '+($taskText -join ' '))}
  return $taskText
}
Invoke-ReceiptDevice @('shell','run-as',$taskPackage,'mkdir','-p','files/offline_validation') | Out-Null
$taskNames=@('receipt-source.png','receipt-rotate90.png','receipt-rotate180.png','receipt-rotate270.png','receipt-cropped.png','receipt-blurred.png')
foreach($taskName in $taskNames) {
  $taskFile=Join-Path $taskFixtures $taskName
  $taskRemote='/data/local/tmp/finki-ocr-'+$taskName
  Invoke-ReceiptDevice @('push',$taskFile,$taskRemote) | Out-Null
  Invoke-ReceiptDevice @('shell','run-as',$taskPackage,'cp',$taskRemote,('files/offline_validation/'+$taskName)) | Out-Null
  $taskActual=((Invoke-ReceiptDevice @('shell','run-as',$taskPackage,'sha256sum',('files/offline_validation/'+$taskName))) -join '').Split(' ')[0]
  if($taskActual -ne (Get-FileHash -LiteralPath $taskFile -Algorithm SHA256).Hash.ToLowerInvariant()){throw 'Fixture alterado durante copia'}
}
if($CameraEvidenceToken){
  Invoke-ReceiptDevice @('shell','run-as',$taskPackage,'cp',('files/finki_evidence/'+$CameraEvidenceToken),'files/offline_validation/receipt-camera.jpg') | Out-Null
  $taskNames=@('receipt-camera.jpg')+$taskNames
}
$taskAirplane=((Invoke-ReceiptDevice @('shell','settings','get','global','airplane_mode_on')) -join '').Trim()
$taskWifi=((Invoke-ReceiptDevice @('shell','settings','get','global','wifi_on')) -join '').Trim()
$taskReverse=((Invoke-ReceiptDevice @('reverse','--list')) -join '') -match 'tcp:3000'
$taskResults=@()
try {
  if($AirplaneMode){
    Invoke-ReceiptDevice @('shell','cmd','connectivity','airplane-mode','enable') | Out-Null
    Invoke-ReceiptDevice @('shell','svc','wifi','disable') | Out-Null
    if($taskReverse){Invoke-ReceiptDevice @('reverse','--remove','tcp:3000') | Out-Null}
  }
  foreach($taskName in ($taskNames+@('receipt-source.png'))) {
    $taskRun=[guid]::NewGuid().ToString()
    Invoke-ReceiptDevice @('shell','am','start','-W','-n',($taskPackage+'/.OfflineValidationActivity'),
      '--es','mode','ocr','--es','input',$taskName,'--es','run_id',$taskRun) | Out-Null
    $taskDeadline=[DateTime]::UtcNow.AddSeconds(60);$taskResult=$null
    do {
      Start-Sleep -Milliseconds 300
      $taskRaw=Invoke-ReceiptDevice @('shell','run-as',$taskPackage,'cat','files/offline_validation/result.json')
      try{$taskCandidate=($taskRaw -join '') | ConvertFrom-Json}catch{$taskCandidate=$null}
      if($taskCandidate.run_id -eq $taskRun){$taskResult=$taskCandidate}
    } while(-not $taskResult -and [DateTime]::UtcNow -lt $taskDeadline)
    if(-not $taskResult){throw ('Sin resultado: '+$taskName)}
    $taskResults+=$taskResult
    $taskResults | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $taskRepo 'build/tooling/receipt-device-results.json') -Encoding UTF8
    Write-Output ($taskName+': '+$taskResult.text.Replace("`n",' | '))
    if($taskResult.error){throw $taskResult.error}
    if($AirplaneMode -and $taskResult.airplane_mode -ne 1){throw 'Modo avión no verificado'}
  }
} finally {
  if($AirplaneMode){
    $taskRestore=if($taskAirplane -eq '1'){'enable'}else{'disable'}
    Invoke-ReceiptDevice @('shell','cmd','connectivity','airplane-mode',$taskRestore) | Out-Null
    $taskRestoreWifi=if($taskWifi -eq '0'){'disable'}else{'enable'}
    Invoke-ReceiptDevice @('shell','svc','wifi',$taskRestoreWifi) | Out-Null
    if($taskReverse){Invoke-ReceiptDevice @('reverse','tcp:3000','tcp:3000') | Out-Null}
  }
}
