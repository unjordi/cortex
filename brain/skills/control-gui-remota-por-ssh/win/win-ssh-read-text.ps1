# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-read-text.ps1  -  Lee el TEXTO de una ventana y sus controles (sin OCR), POR SSH.
  ==================================================================================================
  Busca la ventana top-level cuyo titulo CONTENGA -Window y devuelve su titulo + el texto de cada
  control hijo (mensaje del dialogo, etiquetas de botones, valores de campos Edit/Static). Es la via
  ESTRUCTURADA de leer un dialogo (p.ej. el mensaje de error de licencias de la app) sin OCR sobre el
  screenshot. Funciona con dialogos Win32 clasicos (Win32/Delphi SI; apps UWP no exponen hijos).
  Se despacha con `schtasks /IT`.

  USO (por SSH; admin + usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-read-text.ps1 -Window "MiApp"

  EXIT: 0 hallo la ventana; 1 no la encontro / sin sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Window,
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
if (-not $ru) { Write-Host "SIN sesion de consola activa"; exit 1 }
$wb  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Window))
$res = Join-Path $WorkDir 'rt-result.txt'
$body = @"
Add-Type @'
using System;using System.Text;using System.Collections.Generic;using System.Runtime.InteropServices;
public class RT {
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
 [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr p);
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 public static IntPtr Find(string n){ IntPtr f=IntPtr.Zero; EnumWindows((h,p)=>{ if(!IsWindowVisible(h))return true; var s=new StringBuilder(512); GetWindowText(h,s,512); if(s.ToString().ToLower().Contains(n.ToLower())){f=h;return false;} return true;}, IntPtr.Zero); return f; }
 public static List<string> Texts(IntPtr top){ var l=new List<string>(); EnumChildWindows(top,(h,p)=>{ var t=new StringBuilder(512); GetWindowText(h,t,512); string s=t.ToString(); if(s.Length>0) l.Add(s); return true;}, IntPtr.Zero); return l; }
 public static string Title(IntPtr h){ var s=new StringBuilder(512); GetWindowText(h,s,512); return s.ToString(); }
}
'@
`$n=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$wb'))
`$h=[RT]::Find(`$n)
if(`$h -eq [IntPtr]::Zero){ Set-Content '$res' "__NOTFOUND__" -Encoding UTF8 }
else { `$o=New-Object System.Collections.ArrayList; [void]`$o.Add("TITULO: "+[RT]::Title(`$h)); foreach(`$t in [RT]::Texts(`$h)){ [void]`$o.Add(`$t) }; Set-Content '$res' (`$o -join "`n") -Encoding UTF8 }
"@
$f = Join-Path $WorkDir 'rt.ps1'; $body | Set-Content $f -Encoding UTF8
if (Test-Path $res) { Remove-Item $res -Force }
$tn = 'WRT'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null
if (-not (Test-Path $res)) { Write-Host "FALLO: sin resultado"; exit 1 }
$c = Get-Content $res
if ($c -contains '__NOTFOUND__') { Write-Host "no encontre ventana con titulo que contenga '$Window'"; exit 1 }
$c | ForEach-Object { $_ }
exit 0
