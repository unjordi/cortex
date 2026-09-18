# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-screenshot.ps1  -  Captura la pantalla de la sesion interactiva del usuario, POR SSH.
  ==================================================================================================
  POR QUE NO ES TRIVIAL: la sesion SSH corre en otra logon-session que la consola del usuario
  (aislamiento de Windows) -> no ve ese escritorio. Se despacha la captura a la SESION INTERACTIVA
  con una tarea `schtasks /IT`, que corre COMO el usuario logueado y SI tiene su escritorio.
  Ademas DEBE ser DPI-aware: con escala 125/150% (laptops), sin SetProcessDPIAware() la captura sale
  TRUNCADA a la esquina superior-izquierda (reporta 1280x720 de un 1920x1080 real). Con el fix se
  captura TODO el VirtualScreen (multi-monitor incluido). Las coordenadas de este screenshot son las
  MISMAS que esperan win-ssh-send-click.ps1 / win-ssh-send-keys.ps1. VERIFICADO 2026-08-27 (estacion de prueba real).

  USO (por SSH; correr COMO admin, con un usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-screenshot.ps1                 # -> guarda PNG, imprime ruta+tamano
    powershell ... -File win-ssh-screenshot.ps1 -B64                                           # -> ademas IMPRIME el PNG en base64 (para traerlo)
    powershell ... -File win-ssh-screenshot.ps1 -Out C:\GuiSshWork\x.png -B64

  Para TRAERLO a tu maquina: captura el stdout base64 y decodifica (ver ../SKILL.md, seccion "traer un screenshot").
  EXIT: 0 si genero el PNG; 1 si no hay sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [string]$Out = 'C:\GuiSshWork\ssh-shot.png',
    [switch]$B64,                          # ademas de guardar, imprime el PNG en base64 por stdout
    [string]$User,                         # dominio\usuario de consola; default = el logueado
    [int]$WaitMs = 1600
)
$work = Split-Path $Out -Parent
if (-not (Test-Path $work)) { New-Item -ItemType Directory -Path $work -Force | Out-Null }

function Get-ConsoleUser {
    if ($User) { return $User }
    foreach ($l in (quser 2>$null)) {
        if ($l -match '^\s*>?(\S+)\s+console\s') { return "$env:COMPUTERNAME\$($Matches[1])" }
    }
    $ex = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -EA SilentlyContinue | Select-Object -First 1
    if ($ex) { $o = Invoke-CimMethod -InputObject $ex -MethodName GetOwner; return "$($o.Domain)\$($o.User)" }
    return $null
}

$ru = Get-ConsoleUser
if (-not $ru) { Write-Host "SIN sesion de consola activa -> no hay escritorio que capturar"; exit 1 }

$outEsc = $Out -replace '\\','\\'
$body = @"
Add-Type @'
using System;using System.Runtime.InteropServices;
public class D { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
'@
[void][D]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
`$b=[System.Windows.Forms.SystemInformation]::VirtualScreen
`$bmp=New-Object Drawing.Bitmap `$b.Width,`$b.Height
`$g=[Drawing.Graphics]::FromImage(`$bmp)
`$g.CopyFromScreen(`$b.Location,[Drawing.Point]::Empty,`$b.Size)
`$bmp.Save("$outEsc",[Drawing.Imaging.ImageFormat]::Png)
"@

$f = Join-Path $work 'ss-shot.ps1'
$body | Set-Content $f -Encoding UTF8
if (Test-Path $Out) { Remove-Item $Out -Force }

$tn = 'SS_SHOT'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null

if (-not (Test-Path $Out)) { Write-Host "FALLO: no se genero el PNG"; exit 1 }
$sz = (Get-Item $Out).Length
if ($B64) {
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($Out))
} else {
    Write-Host ("OK screenshot -> {0} ({1} bytes, usuario {2})" -f $Out, $sz, $ru)
}
exit 0
