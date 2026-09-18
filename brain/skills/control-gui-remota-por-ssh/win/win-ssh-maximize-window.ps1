# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-maximize-window.ps1  -  Maximiza (o restaura/minimiza) una ventana por titulo, POR SSH.
  ==================================================================================================
  Busca la ventana top-level cuyo titulo CONTENGA -Window y le aplica un estado (maximizar por
  defecto). Util para dejar una ventana en tamano/posicion conocidos antes de clickear por coordenada.
  Se despacha con `schtasks /IT`.

  USO (por SSH; admin + usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-maximize-window.ps1 -Window "MiApp"
    ... -Window "MiApp" -State restore     # normal
    ... -Window "MiApp" -State minimize

  EXIT: 0 hallo y aplico; 1 no la encontro / sin sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Window,
    [ValidateSet('maximize','restore','minimize')][string]$State = 'maximize',
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
$sw = switch ($State) { 'maximize' {3} 'minimize' {6} 'restore' {9} }   # SW_MAXIMIZE / SW_MINIMIZE / SW_RESTORE
$wb = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Window))
$res = Join-Path $WorkDir 'mw-result.txt'
$body = @"
Add-Type @'
using System;using System.Text;using System.Runtime.InteropServices;
public class MW {
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 public static IntPtr Find(string n){ IntPtr f=IntPtr.Zero; EnumWindows((h,p)=>{ if(!IsWindowVisible(h))return true; var s=new StringBuilder(512); GetWindowText(h,s,512); if(s.ToString().ToLower().Contains(n.ToLower())){f=h;return false;} return true;}, IntPtr.Zero); return f; }
}
'@
`$n=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$wb'))
`$h=[MW]::Find(`$n)
if(`$h -eq [IntPtr]::Zero){ Set-Content '$res' "NOTFOUND" -Encoding UTF8 }
else { [void][MW]::ShowWindow(`$h,$sw); [void][MW]::SetForegroundWindow(`$h); Set-Content '$res' "OK" -Encoding UTF8 }
"@
$f = Join-Path $WorkDir 'mw.ps1'; $body | Set-Content $f -Encoding UTF8
if (Test-Path $res) { Remove-Item $res -Force }
$tn = 'WMW'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null
$r = if (Test-Path $res) { Get-Content $res } else { 'SIN-RESULTADO' }
if ($r -eq 'OK') { Write-Host ("OK {0} -> ventana '{1}'" -f $State,$Window); exit 0 }
else { Write-Host ("no aplico ({0}) a '{1}'" -f $r,$Window); exit 1 }
