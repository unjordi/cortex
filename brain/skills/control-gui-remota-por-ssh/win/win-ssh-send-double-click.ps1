# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-send-double-click.ps1  -  Doble-click izquierdo por COORDENADA en la sesion interactiva, POR SSH.
  ==================================================================================================
  Gemelo de win-ssh-send-click.ps1, pero doble-click (abrir iconos, listas, etc.). DPI-aware (coords
  de pantalla fisica, las mismas del screenshot). Se despacha con `schtasks /IT`.

  USO (por SSH; admin + usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-send-double-click.ps1 -X 1590 -Y 130   # abrir icono
    ... -X 900 -Y 400 -Window "MiApp - Ventana principal"

  EXIT: 0 despacho; 1 sin sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][int]$X,
    [Parameter(Mandatory)][int]$Y,
    [string]$Window,
    [string]$User,
    [string]$WorkDir = 'C:\GuiSshWork',
    [int]$WaitMs = 1200
)
if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }
function Get-ConsoleUser {
    if ($User) { return $User }
    foreach ($l in (quser 2>$null)) { if ($l -match '^\s*>?(\S+)\s+console\s') { return "$env:COMPUTERNAME\$($Matches[1])" } }
    $ex = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -EA SilentlyContinue | Select-Object -First 1
    if ($ex) { $o = Invoke-CimMethod -InputObject $ex -MethodName GetOwner; return "$($o.Domain)\$($o.User)" }
    return $null
}
$ru = Get-ConsoleUser
if (-not $ru) { Write-Host "SIN sesion de consola activa -> no hay donde clickear"; exit 1 }
$focus = ''
if ($Window) {
    $wb = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Window))
    $focus = "`$ws=New-Object -ComObject WScript.Shell; [void]`$ws.AppActivate([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$wb'))); Start-Sleep -Milliseconds 400"
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
$focus
[C]::SetCursorPos($X,$Y); Start-Sleep -Milliseconds 200
[C]::mouse_event(0x0002,0,0,0,0); [C]::mouse_event(0x0004,0,0,0,0)
Start-Sleep -Milliseconds 60
[C]::mouse_event(0x0002,0,0,0,0); [C]::mouse_event(0x0004,0,0,0,0)
"@
$f = Join-Path $WorkDir 'dclick.ps1'
$body | Set-Content $f -Encoding UTF8
$tn = 'WDCLICK'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null
Write-Host ("OK doble-click en {0},{1} (usuario {2})" -f $X,$Y,$ru)
exit 0
