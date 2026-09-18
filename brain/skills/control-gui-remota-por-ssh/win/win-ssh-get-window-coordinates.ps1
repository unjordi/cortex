# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-get-window-coordinates.ps1  -  De UNA ventana: su rectangulo + el CENTRO de cada control
  (botones, checkboxes, edits...), POR SSH. Para clickear con precision, sin adivinar pixeles.
  ==================================================================================================
  Busca la ventana top-level cuyo titulo CONTENGA -Window (case-insensitive), y enumera sus controles
  hijos: por cada uno da su TEXTO (etiqueta), su CLASE (Button/Edit/Static/CheckBox...) y el CENTRO
  (X,Y) en coordenadas de PANTALLA FISICA -> exactamente lo que necesitan win-ssh-send-click /
  win-ssh-send-double-click, y lo que ves en win-ssh-screenshot (ambos DPI-aware).

  Se despacha a la SESION INTERACTIVA con `schtasks /IT` (la sesion SSH no ve ese escritorio).
  DPI-aware (SetProcessDPIAware) para que las coords sean fisicas, no escaladas.

  USO (por SSH; correr COMO admin, con un usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-get-window-coordinates.ps1 -Window "MiApp"
    ... -Window "MiApp" -Csv           # salida CSV (Text,Class,CenterX,CenterY,X,Y,W,H)

  Salida por defecto (tabla): la ventana + una fila por control con su centro clickeable.
  EXIT: 0 si hallo la ventana; 1 si no la encontro o no hay sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Window,
    [switch]$Csv,
    [string]$User,
    [string]$WorkDir = 'C:\GuiSshWork',
    [int]$WaitMs = 1500
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
if (-not $ru) { Write-Host "SIN sesion de consola activa -> no hay ventanas que inspeccionar"; exit 1 }

$wb  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Window))
$res = Join-Path $WorkDir 'gwc-result.txt'
$body = @"
Add-Type @'
using System;using System.Text;using System.Collections.Generic;using System.Runtime.InteropServices;
public class GWC {
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
 [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr p);
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 public struct RECT { public int L,T,R,B; }
 public static IntPtr Find(string needle){ IntPtr found=IntPtr.Zero; EnumWindows((h,p)=>{ if(!IsWindowVisible(h))return true; var sb=new StringBuilder(512); GetWindowText(h,sb,512); if(sb.ToString().ToLower().Contains(needle.ToLower())){ found=h; return false;} return true;}, IntPtr.Zero); return found; }
 public static string Rect(IntPtr h){ RECT r; GetWindowRect(h,out r); return r.L+","+r.T+","+(r.R-r.L)+","+(r.B-r.T); }
 public static List<string> Children(IntPtr top){ var l=new List<string>(); EnumChildWindows(top,(h,p)=>{ if(!IsWindowVisible(h))return true; var t=new StringBuilder(256); GetWindowText(h,t,256); var c=new StringBuilder(128); GetClassName(h,c,128); RECT r; GetWindowRect(h,out r); int cx=(r.L+r.R)/2, cy=(r.T+r.B)/2; l.Add(t.ToString()+"\t"+c.ToString()+"\t"+cx+"\t"+cy+"\t"+r.L+","+r.T+","+(r.R-r.L)+","+(r.B-r.T)); return true;}, IntPtr.Zero); return l; }
}
'@
[void][GWC]::SetProcessDPIAware()
`$needle=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$wb'))
`$h=[GWC]::Find(`$needle)
`$out=New-Object System.Collections.ArrayList
if(`$h -eq [IntPtr]::Zero){ [void]`$out.Add("__NOTFOUND__") }
else {
  [void]`$out.Add("WINDOW`t"+`$needle+"`tRECT`t"+[GWC]::Rect(`$h))
  foreach(`$c in [GWC]::Children(`$h)){ [void]`$out.Add("CTRL`t"+`$c) }
}
Set-Content '$res' (`$out -join "`n") -Encoding UTF8
"@
$f = Join-Path $WorkDir 'gwc.ps1'
$body | Set-Content $f -Encoding UTF8
if (Test-Path $res) { Remove-Item $res -Force }
$tn = 'GWC'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null

if (-not (Test-Path $res)) { Write-Host "FALLO: la tarea interactiva no dejo resultado"; exit 1 }
$lines = Get-Content $res
if ($lines -contains '__NOTFOUND__' -or -not $lines) { Write-Host "no encontre una ventana visible cuyo titulo contenga '$Window'"; exit 1 }

$win = ($lines | Where-Object { $_ -like 'WINDOW*' }) -replace '^WINDOW\t',''
$ctrls = $lines | Where-Object { $_ -like 'CTRL*' } | ForEach-Object {
    $p = ($_ -replace '^CTRL\t','') -split "`t"
    [pscustomobject]@{ Text=$p[0]; Class=$p[1]; CenterX=[int]$p[2]; CenterY=[int]$p[3]; Rect=$p[4] }
}
Write-Host ("VENTANA: {0}" -f $win)
if ($Csv) { $ctrls | ConvertTo-Csv -NoTypeInformation }
else { $ctrls | Format-Table Text,Class,CenterX,CenterY,Rect -AutoSize | Out-String -Width 200 }
exit 0
