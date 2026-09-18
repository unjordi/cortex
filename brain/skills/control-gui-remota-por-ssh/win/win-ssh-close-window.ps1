# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-close-window.ps1  -  Cierra una ventana por titulo (WM_CLOSE, cierre GRACIOSO), POR SSH.
  ==================================================================================================
  Busca la ventana top-level cuyo titulo CONTENGA -Window y le manda WM_CLOSE (como el boton X). Es
  GRACIOSO: si la app tiene cambios sin guardar, PUEDE mostrar su propio dialogo "guardar?". Para
  matar el proceso a la fuerza usa win-ssh-kill-process.ps1. Se despacha con `schtasks /IT`.

  USO (por SSH; admin + usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-close-window.ps1 -Window "MiApp"

  EXIT: 0 hallo y mando cerrar; 1 no la encontro / sin sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Window,
    [string]$User,
    [string]$WorkDir = 'C:\GuiSshWork',
    [int]$WaitMs = 1000
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
$wb = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Window))
$res = Join-Path $WorkDir 'cw-result.txt'
$body = @"
Add-Type @'
using System;using System.Text;using System.Runtime.InteropServices;
public class CW {
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
 public static IntPtr Find(string n){ IntPtr f=IntPtr.Zero; EnumWindows((h,p)=>{ if(!IsWindowVisible(h))return true; var s=new StringBuilder(512); GetWindowText(h,s,512); if(s.ToString().ToLower().Contains(n.ToLower())){f=h;return false;} return true;}, IntPtr.Zero); return f; }
}
'@
`$n=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$wb'))
`$h=[CW]::Find(`$n)
if(`$h -eq [IntPtr]::Zero){ Set-Content '$res' "NOTFOUND" -Encoding UTF8 }
else { [void][CW]::PostMessage(`$h,0x0010,[IntPtr]::Zero,[IntPtr]::Zero); Set-Content '$res' "OK" -Encoding UTF8 }
"@
$f = Join-Path $WorkDir 'cw.ps1'; $body | Set-Content $f -Encoding UTF8
if (Test-Path $res) { Remove-Item $res -Force }
$tn = 'WCW'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null
$r = if (Test-Path $res) { Get-Content $res } else { 'SIN-RESULTADO' }
if ($r -eq 'OK') { Write-Host ("OK cerre (WM_CLOSE) -> '{0}'" -f $Window); exit 0 }
else { Write-Host ("no cerre ({0}) a '{1}'" -f $r,$Window); exit 1 }
