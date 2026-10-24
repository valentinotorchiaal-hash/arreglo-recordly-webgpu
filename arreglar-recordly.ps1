# Arreglo para Recordly en Windows: exportacion que se traba y pantallas que se apagan.
#
# Recordly usa WebGPU para dibujar la exportacion. En algunas GPUs (sobre todo las integradas de AMD) WebGPU
# congela la placa, Windows reinicia el driver de video (las pantallas se apagan un segundo) y la exportacion
# queda trabada o falla con "createBuffer failed". Este script hace que Recordly use WebGL, que funciona bien.
#
# Como lo hace: cambia dos textos dentro de resources\app.asar por textos del MISMO largo, asi el resto del
# archivo queda igual. Antes guarda una copia del original para poder deshacerlo.
#   1. Reemplaza la etiqueta <meta name="viewport"> de index.html (no se usa en una app de escritorio) por un
#      script que borra navigator.gpu. Sin WebGPU disponible, Recordly usa WebGL.
#   2. (Opcional) Cambia la funcion que calcula el tamano "Original" para que exporte a 1080p si la grabacion es
#      mas chica.

param([string]$Option = '')

$ErrorActionPreference = 'Stop'
$latin1 = [Text.Encoding]::GetEncoding(28591)

$viewportMeta = '<meta name="viewport" content="width=device-width, initial-scale=1.0" />'
$noWebGpu = '<script>try{delete Navigator.prototype.gpu}catch(e){}</script>'
$noWebGpuMark = 'try{delete Navigator.prototype.gpu}'
$sizeRegex = 'function (\w+)\(e,t,n\)\{if\("source"===n\)return\{width:(\w+)\(e\),height:\2\(t\)\};const r="medium"===n\?\.6:"good"===n\?\.75:\.9;return\{width:\2\(e\*r\),height:\2\(t\*r\)\}\}'
$sizeMark = '>>4==119?1920:w'

function Write-Title($text) { Write-Host ''; Write-Host $text -ForegroundColor Cyan }
function Fail($text) { Write-Host ''; Write-Host $text -ForegroundColor Red; exit 1 }

# --- Encontrar Recordly --------------------------------------------------------------------------------------
$installDir = @(
  (Join-Path $env:LOCALAPPDATA 'Programs\Recordly'),
  (Join-Path $env:ProgramFiles 'Recordly')
) | Where-Object { Test-Path (Join-Path $_ 'resources\app.asar') } | Select-Object -First 1
if (-not $installDir) { Fail 'No encontre Recordly instalado (busque en AppData\Local\Programs y en Archivos de programa).' }

$asarPath = Join-Path $installDir 'resources\app.asar'
$exePath = Join-Path $installDir 'Recordly.exe'
$version = (Get-Item $exePath).VersionInfo.ProductVersion
$backupPath = "$asarPath.original-$version"

# Si Recordly algun dia activa la verificacion de integridad del asar, un asar modificado no abriria.
$exeText = $latin1.GetString([IO.File]::ReadAllBytes($exePath))
$fuseAt = $exeText.IndexOf('dL7pKGdnNz796PbbjQWNKmHXBZaB9tsX')
if ($fuseAt -ge 0 -and $exeText[$fuseAt + 32 + 2 + 4] -eq '1') {
  Fail 'Esta version de Recordly verifica que sus archivos no se modifiquen. Este arreglo no sirve para ella.'
}

function Read-State {
  $text = $latin1.GetString([IO.File]::ReadAllBytes($asarPath))
  [pscustomobject]@{
    Text     = $text
    NoWebGpu = $text.Contains($noWebGpuMark)
    Size1080 = $text.Contains($sizeMark)
  }
}

function Stop-Recordly {
  $procs = Get-Process Recordly -ErrorAction SilentlyContinue
  if (-not $procs) { return }
  Write-Host ''
  Write-Host 'Recordly esta abierto. Hay que cerrarlo para aplicar el cambio (guarda tu proyecto antes).' -ForegroundColor Yellow
  $answer = Read-Host 'Cerrarlo ahora? (S/N)'
  if ($answer -notmatch '^[sS]') { Fail 'Cancelado. Cerra Recordly (tambien desde la bandeja, junto al reloj) y volve a abrir este archivo.' }
  $procs | Stop-Process -Force
  Start-Sleep -Seconds 2
}

function Save-Asar([string]$text) {
  try {
    if (-not (Test-Path $backupPath)) { Copy-Item $asarPath $backupPath }
    $tmp = "$asarPath.tmp"
    [IO.File]::WriteAllBytes($tmp, $latin1.GetBytes($text))
    Move-Item $tmp $asarPath -Force
  } catch {
    Fail "No pude guardar el cambio ($($_.Exception.Message)). Proba con clic derecho en arreglar-recordly.bat > Ejecutar como administrador."
  }
}

function Apply-Fix([bool]$with1080) {
  Stop-Recordly
  $state = Read-State
  $text = $state.Text
  $changes = @()

  if (-not $state.NoWebGpu) {
    $at = $text.IndexOf($viewportMeta)
    if ($at -lt 0) { Fail 'Esta version de Recordly es distinta a la que conozco: no encontre donde aplicar el arreglo. No toque nada.' }
    $text = $text.Remove($at, $viewportMeta.Length).Insert($at, $noWebGpu.PadRight($viewportMeta.Length))
    $changes += 'Recordly ya no usa WebGPU'
  }

  if ($with1080 -and -not $state.Size1080) {
    $m = [regex]::Match($text, $sizeRegex)
    if (-not $m.Success) {
      Write-Host 'Aviso: en esta version no encontre la funcion del tamano "Original". Se aplica solo el arreglo de WebGPU.' -ForegroundColor Yellow
    } else {
      $fn = $m.Groups[1].Value; $even = $m.Groups[2].Value
      $new = "function $fn(e,t,n){var r={medium:.6,good:.75,high:.9}[n]||Math.max(1,1080/(e<t?e:t)),w=$even(e*r),h=$even(t*r);return{width:w$sizeMark,height:h}}"
      if ($new.Length -gt $m.Length) {
        Write-Host 'Aviso: el cambio a 1080p no entra en esta version. Se aplica solo el arreglo de WebGPU.' -ForegroundColor Yellow
      } else {
        $text = $text.Remove($m.Index, $m.Length).Insert($m.Index, $new.PadRight($m.Length))
        $changes += '"Original" exporta a 1080p'
      }
    }
  }

  if ($changes.Count -eq 0) { Write-Title 'No hacia falta cambiar nada: ya estaba aplicado.'; return }
  Save-Asar $text
  $check = Read-State
  if (-not $check.NoWebGpu) { Fail 'Algo salio mal al guardar. Usa la opcion 3 para volver al original.' }
  Write-Title "Listo: $($changes -join ' y ')."
  Write-Host "Copia del original: $backupPath"
  Write-Host 'Abri Recordly y exporta normalmente. Si Recordly se actualiza, volve a correr este arreglo.'
}

function Restore-Original {
  Stop-Recordly
  if (-not (Test-Path $backupPath)) { Fail "No hay copia del original para la version $version. Si Recordly se actualizo, ya esta como vino." }
  try { Copy-Item $backupPath $asarPath -Force } catch {
    Fail "No pude restaurar ($($_.Exception.Message)). Proba con clic derecho en arreglar-recordly.bat > Ejecutar como administrador."
  }
  Write-Title "Listo: Recordly $version quedo como vino originalmente."
}

# --- Menu ----------------------------------------------------------------------------------------------------
$state = Read-State
Write-Title "Arreglo para Recordly $version"
Write-Host "Instalado en: $installDir"
Write-Host ("Estado: WebGPU {0}, Original a 1080p {1}" -f `
  $(if ($state.NoWebGpu) { 'desactivado (arreglado)' } else { 'activo (sin arreglar)' }), `
  $(if ($state.Size1080) { 'si' } else { 'no' }))
Write-Host ''
Write-Host '  1) Arreglar la exportacion (quitar WebGPU)'
Write-Host '  2) Arreglar la exportacion + "Original" a 1080p'
Write-Host '  3) Deshacer: volver al Recordly original'
Write-Host '  4) Salir'
$choice = if ($Option) { $Option } else { Read-Host 'Elegi una opcion' }
switch ($choice) {
  '1' { Apply-Fix $false }
  '2' { Apply-Fix $true }
  '3' { Restore-Original }
  default { Write-Host 'Sin cambios.' }
}
