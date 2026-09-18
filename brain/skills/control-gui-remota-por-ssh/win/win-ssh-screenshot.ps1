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

  `-Window "titulo"` (agregado 2026-09-18, PARIDAD con el `-Window` de linux-ssh-screenshot.sh /
  mac-ssh-screenshot.sh -- misma semantica: substring del titulo, mismo fallback si no se halla):
  REUSA la MISMA tecnica que win-ssh-get-window-coordinates.ps1 (EnumWindows + GetWindowText para
  hallar el HWND cuyo titulo CONTIENE el texto, case-insensitive) -- no se reimplementa la busqueda,
  solo se repite la MISMA rutina Find() dentro del cuerpo despachado (cada gesto de este kit se
  despacha como una tarea `/IT` INDEPENDIENTE -- no hay forma de que dos .ps1 distintos compartan
  una funcion en la MISMA invocacion de schtasks, mismo patron ya documentado en
  lib-linux-ssh-env.sh sobre por que Windows repite Get-ConsoleUser en cada script).
  Con el HWND resuelto, la captura usa `PrintWindow(hwnd, hdc, PW_RENDERFULLCONTENT)` -- nativo
  por-ventana, no necesita recortar el VirtualScreen ni calcular offsets (funciona igual si la
  ventana esta en un monitor con origen negativo). Si el titulo no se encuentra, o PrintWindow
  falla (ventana minimizada o sin superficie que copiar), cae al MISMO VirtualScreen completo del
  modo default -- igual patron de fallback que Linux/Mac.

  SIN CONFIRMAR EN HARDWARE: el ultimo test real de HW de este kit fue 2026-08-27 (screenshot
  default / VirtualScreen). El modo `-Window` es NUEVO (2026-09-18) y solo paso el parse-check de
  sintaxis (`pwsh -NoProfile`) en una Mac -- NO se corrio contra una estacion Windows real. Antes de
  darlo por bueno, verificalo contra HW real y actualiza esta nota con fecha+resultado.

  USO (por SSH; correr COMO admin, con un usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-screenshot.ps1                 # -> guarda PNG, imprime ruta+tamano
    powershell ... -File win-ssh-screenshot.ps1 -B64                                           # -> ademas IMPRIME el PNG en base64 (para traerlo)
    powershell ... -File win-ssh-screenshot.ps1 -Window "Bloc de notas"                        # -> SOLO esa ventana (por titulo)
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
    [string]$Window,                       # SOLO esa ventana (substring del titulo, case-insensitive)
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
$statusFile = Join-Path $work 'ss-status.txt'
$statusEsc = $statusFile -replace '\\','\\'

if ($Window) {
    # modo por-ventana: PrintWindow del HWND hallado por titulo; fallback = VirtualScreen completo.
    $wb = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Window))
    $body = @"
Add-Type @'
using System;using System.Text;using System.Drawing;using System.Drawing.Imaging;using System.Runtime.InteropServices;
public class WS {
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
 public delegate bool EnumProc(IntPtr h, IntPtr p);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdcBlt, uint flags);
 public struct RECT { public int L,T,R,B; }
 public static IntPtr Find(string needle){ IntPtr found=IntPtr.Zero; EnumWindows((h,p)=>{ if(!IsWindowVisible(h))return true; var sb=new StringBuilder(512); GetWindowText(h,sb,512); if(sb.ToString().ToLower().Contains(needle.ToLower())){ found=h; return false;} return true;}, IntPtr.Zero); return found; }
 public static bool Capture(IntPtr h, string path){
   RECT r; if(!GetWindowRect(h, out r)) return false;
   int w = r.R - r.L, ht = r.B - r.T;
   if (w<=0 || ht<=0) return false;
   Bitmap bmp = new Bitmap(w, ht);
   Graphics g = Graphics.FromImage(bmp);
   IntPtr hdc = g.GetHdc();
   bool ok = PrintWindow(h, hdc, 2);
   g.ReleaseHdc(hdc);
   g.Dispose();
   if (ok) { bmp.Save(path, ImageFormat.Png); }
   bmp.Dispose();
   return ok;
 }
}
'@
[void][WS]::SetProcessDPIAware()
`$needle=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$wb'))
`$h=[WS]::Find(`$needle)
`$status='OK'
`$ok=`$false
if (`$h -ne [IntPtr]::Zero) { `$ok=[WS]::Capture(`$h, "$outEsc") }
if (`$h -eq [IntPtr]::Zero) { `$status='NOTFOUND' } elseif (-not `$ok) { `$status='PWFAIL' }
if (`$status -ne 'OK') {
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    `$b=[System.Windows.Forms.SystemInformation]::VirtualScreen
    `$bmp=New-Object Drawing.Bitmap `$b.Width,`$b.Height
    `$g=[Drawing.Graphics]::FromImage(`$bmp)
    `$g.CopyFromScreen(`$b.Location,[Drawing.Point]::Empty,`$b.Size)
    `$bmp.Save("$outEsc",[Drawing.Imaging.ImageFormat]::Png)
}
Set-Content '$statusEsc' `$status -Encoding UTF8
"@
} else {
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
}

$f = Join-Path $work 'ss-shot.ps1'
$body | Set-Content $f -Encoding UTF8
if (Test-Path $Out) { Remove-Item $Out -Force }
if (Test-Path $statusFile) { Remove-Item $statusFile -Force }

$tn = 'SS_SHOT'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null

if ($Window -and (Test-Path $statusFile)) {
    $st = (Get-Content $statusFile -Raw).Trim()
    Remove-Item $statusFile -Force
    if ($st -eq 'NOTFOUND') { Write-Host "no encontre una ventana visible cuyo titulo contenga '$Window' -- capturo VirtualScreen completo en su lugar" }
    elseif ($st -eq 'PWFAIL') { Write-Host "AVISO: PrintWindow fallo para '$Window' (minimizada / sin superficie) -- capturo VirtualScreen completo en su lugar" }
}

if (-not (Test-Path $Out)) { Write-Host "FALLO: no se genero el PNG"; exit 1 }
$sz = (Get-Item $Out).Length
if ($B64) {
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($Out))
} else {
    Write-Host ("OK screenshot -> {0} ({1} bytes, usuario {2})" -f $Out, $sz, $ru)
}
exit 0
