# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  send-click-ssh.ps1  -  Manda UN click (o doble/derecho) por COORDENADA a la sesion interactiva, POR SSH.
  ===================================================================================================
  Complemento enfocado de win-gui-ssh.ps1 (que hace shot/keys/click). Este SOLO hace click, para
  invocarlo rapido y directo desde tu maquina por SSH mientras miras un screenshot.

  POR QUE NO ES TRIVIAL: la sesion SSH corre en otra logon-session que la consola del usuario
  (aislamiento de Windows) -> no puede dibujar/clickear el escritorio del usuario. Se despacha el
  click a la SESION INTERACTIVA con una tarea `schtasks /IT`. Ademas el click DEBE ser DPI-aware:
  con escala 125/150% (comun en laptops), SetCursorPos sin SetProcessDPIAware() DESVIA el click
  (multiplica la coord por el factor de escala). Las coordenadas son de PANTALLA FISICA -> las mismas
  que ves en un screenshot tomado DPI-aware (win-gui-ssh.ps1 -Action shot). VERIFICADO 2026-08-27:
  cerro un dialogo real en una estacion de prueba real clickeando su boton "No".

  USO (por SSH; correr COMO admin de la maquina, con un usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File send-click-ssh.ps1 -X 1180 -Y 590
    ... -X 1180 -Y 590 -Window "MiApp - Herramienta"   # enfoca esa ventana antes de clickear
    ... -X 900 -Y 400 -Button right                          # click derecho
    ... -X 240 -Y 560 -Double                                # doble click (abrir icono)

  EXIT: 0 si despacho el click; 1 si no hay sesion de consola (nadie logueado -> no hay donde clickear).
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][int]$X,
    [Parameter(Mandatory)][int]$Y,
    [ValidateSet('left','right')][string]$Button = 'left',
    [switch]$Double,
    [string]$Window,                       # titulo de ventana a enfocar (AppActivate) antes del click
    [string]$User,                         # dominio\usuario de consola; default = el que este logueado
    [string]$WorkDir = 'C:\GuiSshWork',         # carpeta de trabajo SIN espacios (para el .ps1 temporal)
    [int]$WaitMs = 1200
)

if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }

# --- usuario de la sesion de consola (para /IT) ---
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
if (-not $ru) { Write-Host "SIN sesion de consola activa (nadie logueado) -> no hay escritorio donde clickear"; exit 1 }

# down/up segun boton
$down = if ($Button -eq 'right') { '0x0008' } else { '0x0002' }   # RIGHTDOWN / LEFTDOWN
$up   = if ($Button -eq 'right') { '0x0010' } else { '0x0004' }   # RIGHTUP   / LEFTUP
$dbl  = if ($Double) { "Start-Sleep -Milliseconds 60`n[C]::mouse_event($down,0,0,0,0); [C]::mouse_event($up,0,0,0,0)" } else { '' }

$winFocus = ''
if ($Window) {
    $wb = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Window))
    $winFocus = "`$ws=New-Object -ComObject WScript.Shell; [void]`$ws.AppActivate([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$wb'))); Start-Sleep -Milliseconds 400"
}

$body = @"
Add-Type @'
using System;using System.Runtime.InteropServices;
public class C {
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,int e);
}
'@
[void][C]::SetProcessDPIAware()
$winFocus
[C]::SetCursorPos($X,$Y); Start-Sleep -Milliseconds 250
[C]::mouse_event($down,0,0,0,0); [C]::mouse_event($up,0,0,0,0)
$dbl
"@

$f = Join-Path $WorkDir 'sc-click.ps1'
$body | Set-Content $f -Encoding UTF8

$tn = 'SC_CLICK'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null

Write-Host ("OK click {0}{1} en {2},{3} (usuario {4})" -f $Button, $(if($Double){'-doble'}else{''}), $X, $Y, $ru)
exit 0
