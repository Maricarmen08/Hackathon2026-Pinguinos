# Local, explicitly fictitious OCR inputs. Never upload these to a real business.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskFixtureRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'build\tooling\offline-fixtures'
New-Item -ItemType Directory -Path $taskFixtureRoot -Force | Out-Null
$taskSamples = @{
    'receipt.png' = @('FINKI PRUEBA - SIN VALIDEZ', 'BOLETA DE ENSAYO', 'Fecha: 22/10/2026', 'Concepto: Arroz', 'SUBTOTAL S/ 42.37', 'IGV S/ 7.63', 'TOTAL S/ 50.00')
    'ticket.png' = @('FINKI PRUEBA - SIN VALIDEZ', 'TICKET DE ENSAYO', 'Fecha: 2026-10-22', 'Concepto: Azúcar', 'TOTAL S/ 23.00')
    'yape.png' = @('FINKI PRUEBA - SIN VALIDEZ', 'YAPE', 'Transferencia de prueba', 'S/ 40.00', '22 oct. 2026', 'N° de operación: 0012345', 'Concepto: Abono')
    'plin.png' = @('FINKI PRUEBA - SIN VALIDEZ', 'PLIN', 'Transferencia de prueba', 'S/ 40.00', '22 oct. 2026', 'N° de operación: 0012345', 'Concepto: Abono')
}
foreach ($taskName in $taskSamples.Keys) {
    $taskBitmap = New-Object Drawing.Bitmap 1200,1200
    $taskGraphics = [Drawing.Graphics]::FromImage($taskBitmap)
    $taskFont = New-Object Drawing.Font 'Arial',34
    try {
        $taskGraphics.Clear([Drawing.Color]::White)
        $taskGraphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $taskY = 45
        foreach ($taskLine in $taskSamples[$taskName]) {
            $taskGraphics.DrawString($taskLine,$taskFont,[Drawing.Brushes]::Black,35,$taskY)
            $taskY += 100
        }
        $taskBitmap.Save((Join-Path $taskFixtureRoot $taskName),[Drawing.Imaging.ImageFormat]::Png)
    } finally { $taskFont.Dispose(); $taskGraphics.Dispose(); $taskBitmap.Dispose() }
}
$taskReceipt = [Drawing.Bitmap]::FromFile((Join-Path $taskFixtureRoot 'receipt.png'))
try {
    $taskCropped = $taskReceipt.Clone([Drawing.Rectangle]::new(0,0,1200,610),$taskReceipt.PixelFormat)
    try { $taskCropped.Save((Join-Path $taskFixtureRoot 'cropped.png'),[Drawing.Imaging.ImageFormat]::Png) }
    finally { $taskCropped.Dispose() }
} finally { $taskReceipt.Dispose() }
$taskTicket = [Drawing.Bitmap]::FromFile((Join-Path $taskFixtureRoot 'ticket.png'))
$taskTiny = New-Object Drawing.Bitmap 70,70
$taskBlurred = New-Object Drawing.Bitmap 1200,1200
try {
    $taskTinyGraphics = [Drawing.Graphics]::FromImage($taskTiny)
    try { $taskTinyGraphics.DrawImage($taskTicket,0,0,70,70) } finally { $taskTinyGraphics.Dispose() }
    $taskBlurGraphics = [Drawing.Graphics]::FromImage($taskBlurred)
    try { $taskBlurGraphics.DrawImage($taskTiny,0,0,1200,1200) } finally { $taskBlurGraphics.Dispose() }
    $taskBlurred.Save((Join-Path $taskFixtureRoot 'blurred.png'),[Drawing.Imaging.ImageFormat]::Png)
} finally { $taskTicket.Dispose(); $taskTiny.Dispose(); $taskBlurred.Dispose() }
# Mono PCM16, 16000 Hz, eight seconds of silence, for the decoder only.
$taskSilencePath = Join-Path $taskFixtureRoot 'silence.wav'
$taskWave = [IO.BinaryWriter]::new([IO.File]::Create($taskSilencePath))
try {
    $taskWave.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $taskWave.Write([int](36+256000))
    $taskWave.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $taskWave.Write([int]16)
    $taskWave.Write([int16]1); $taskWave.Write([int16]1); $taskWave.Write([int]16000)
    $taskWave.Write([int]32000); $taskWave.Write([int16]2); $taskWave.Write([int16]16)
    $taskWave.Write([Text.Encoding]::ASCII.GetBytes('data')); $taskWave.Write([int]256000)
    $taskWave.Write((New-Object byte[] 256000))
} finally { $taskWave.Dispose() }
Get-ChildItem -LiteralPath $taskFixtureRoot -File | Select-Object Name,Length
