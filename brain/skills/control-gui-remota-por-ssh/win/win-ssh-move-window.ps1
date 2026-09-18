# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-move-window.ps1  -  Mueve/redimensiona una ventana por titulo a X,Y[,W,H], POR SSH.
  ==================================================================================================
  Busca la ventana top-level cuyo titulo CONTENGA -Window y la coloca en (X,Y). Si das -W/-H tambien
  la redimensiona; si no, conserva su tamano. Sirve para dejar una ventana en POSICION CONOCIDA antes
  de clickear por coordenada (coords fisicas, DPI-aware). Se despacha con `schtasks /IT`.

  USO (por SSH; admin + usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-move-window.ps1 -Window "MiApp" -X 0 -Y 0
    ... -Window "MiApp" -X 100 -Y 100 -W 1280 -H 800

  EXIT: 0 hallo y movio; 1 no la encontro / sin sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Window,
    [Parameter(Mandatory)][int]$X,
    [Parameter(Mandatory)][int]$Y,
    [int]$W = -1,
    [int]$H = -1,
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
$res = Join-Path $WorkDir 'mvw-result.txt'
$body = @"
Add-Type @'
using System;using System.Text;using System.Runtime.InteropServices;
public class MVW {
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
 public struct RECT { public int L,T,R,B; }
 public static IntPtr Find(string n){ IntPtr f=IntPtr.Zero; EnumWindows((h,p)=>{ if(!IsWindowVisible(h))return true; var s=new StringBuilder(512); GetWindowText(h,s,512); if(s.ToString().ToLower().Contains(n.ToLower())){f=h;return false;} return true;}, IntPtr.Zero); return f; }
}
'@
`$n=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$wb'))
`$h=[MVW]::Find(`$n)
if(`$h -eq [IntPtr]::Zero){ Set-Content '$res' "NOTFOUND" -Encoding UTF8 }
else {
  `$w=$W; `$ht=$H
  if(`$w -lt 0 -or `$ht -lt 0){ `$r=New-Object MVW+RECT; [void][MVW]::GetWindowRect(`$h,[ref]`$r); if(`$w -lt 0){`$w=`$r.R-`$r.L}; if(`$ht -lt 0){`$ht=`$r.B-`$r.T} }
  [void][MVW]::MoveWindow(`$h,$X,$Y,`$w,`$ht,`$true); Set-Content '$res' "OK" -Encoding UTF8
}
"@
$f = Join-Path $WorkDir 'mvw.ps1'; $body | Set-Content $f -Encoding UTF8
if (Test-Path $res) { Remove-Item $res -Force }
$tn = 'WMVW'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null
$r = if (Test-Path $res) { Get-Content $res } else { 'SIN-RESULTADO' }
if ($r -eq 'OK') { Write-Host ("OK movi '{0}' -> {1},{2}" -f $Window,$X,$Y); exit 0 }
else { Write-Host ("no movi ({0}) a '{1}'" -f $r,$Window); exit 1 }
