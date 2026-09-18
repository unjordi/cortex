# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-list-windows.ps1  -  Lista las ventanas top-level VISIBLES (titulo + rect + PID), POR SSH.
  ==================================================================================================
  Para saber que hay abierto en la sesion del usuario y con que ventana trabajar. Complementa al
  screenshot con datos ESTRUCTURADOS (titulo, rectangulo, proceso). Para el detalle de los botones de
  UNA ventana usa win-ssh-get-window-coordinates.ps1.

  Se despacha a la SESION INTERACTIVA con `schtasks /IT`. DPI-aware (rects en pixeles fisicos, cuadran
  con win-ssh-screenshot).

  USO (por SSH; admin + usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-list-windows.ps1
    ... -Filter MiApp        # solo ventanas cuyo titulo contenga 'MiApp'
    ... -Csv                 # CSV (Title,PID,X,Y,W,H)

  EXIT: 0 ok; 1 sin sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [string]$Filter,
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
if (-not $ru) { Write-Host "SIN sesion de consola activa -> no hay ventanas que listar"; exit 1 }

$res = Join-Path $WorkDir 'lw-result.txt'
$body = @"
Add-Type @'
using System;using System.Text;using System.Collections.Generic;using System.Runtime.InteropServices;
public class LW {
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 public struct RECT { public int L,T,R,B; }
 public static List<string> All(){ var l=new List<string>(); EnumWindows((h,p)=>{ if(!IsWindowVisible(h))return true; var sb=new StringBuilder(512); GetWindowText(h,sb,512); string t=sb.ToString(); if(t.Length==0)return true; RECT r; GetWindowRect(h,out r); if((r.R-r.L)<=0||(r.B-r.T)<=0)return true; uint pid; GetWindowThreadProcessId(h,out pid); l.Add(t+"\t"+pid+"\t"+r.L+"\t"+r.T+"\t"+(r.R-r.L)+"\t"+(r.B-r.T)); return true;}, IntPtr.Zero); return l; }
}
'@
[void][LW]::SetProcessDPIAware()
Set-Content '$res' ([LW]::All() -join "`n") -Encoding UTF8
"@
$f = Join-Path $WorkDir 'lw.ps1'
$body | Set-Content $f -Encoding UTF8
if (Test-Path $res) { Remove-Item $res -Force }
$tn = 'LW'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null

if (-not (Test-Path $res)) { Write-Host "FALLO: la tarea interactiva no dejo resultado"; exit 1 }
$rows = Get-Content $res | Where-Object { $_ } | ForEach-Object {
    $p = $_ -split "`t"
    [pscustomobject]@{ Title=$p[0]; PID=[int]$p[1]; X=[int]$p[2]; Y=[int]$p[3]; W=[int]$p[4]; H=[int]$p[5] }
}
if ($Filter) { $rows = $rows | Where-Object { $_.Title -like "*$Filter*" } }
if ($Csv) { $rows | ConvertTo-Csv -NoTypeInformation }
else { $rows | Format-Table Title,PID,X,Y,W,H -AutoSize | Out-String -Width 200 }
exit 0
