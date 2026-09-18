# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-launch.ps1  -  Lanza un programa EN la sesion interactiva del usuario (entorno COMPLETO), POR SSH.
  ==================================================================================================
  Por que importa: lanzar por SSH directo corre en otra logon-session (sin el escritorio ni los drives
  mapeados del usuario, p.ej. una unidad de red mapeada). Este despacha el lanzamiento a la SESION INTERACTIVA con
  `schtasks /IT` (token del usuario logueado, su escritorio, sus drives). Por defecto lanza VIA SHELL
  (`explorer.exe <path>`) que es lo mas parecido a un doble-clic real (hereda TODO el entorno de la
  sesion); con -Direct usa Start-Process (permite -Args). NO-elevado (rl limited) = como un usuario normal.

  USO (por SSH; admin + usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-launch.ps1 -Path "C:\Programas\MiApp\MiApp.exe"
    ... -Path "C:\Programas\MiApp\MiApp.exe" -Direct -Args "/algo"     # Start-Process con argumentos
  Tip: si un GUI no renderiza por aqui, prueba doble-clic a su icono de escritorio con
       win-ssh-send-double-click.ps1 (va 100% por el shell).

  EXIT: 0 despacho el lanzamiento; 1 sin sesion de consola.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Args,
    [switch]$Direct,                       # Start-Process (permite -Args) en vez de explorer.exe
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
if (-not $ru) { Write-Host "SIN sesion de consola activa -> no hay donde lanzar"; exit 1 }

$pb = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Path))
$ab = if ($Args) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Args)) } else { '' }
if ($Direct) {
    $launch = "if('$ab'){ Start-Process -FilePath `$p -ArgumentList ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$ab'))) } else { Start-Process -FilePath `$p }"
} else {
    $launch = "Start-Process explorer.exe -ArgumentList `$p"
}
$body = @"
`$p = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$pb'))
$launch
"@
$f = Join-Path $WorkDir 'launch.ps1'
$body | Set-Content $f -Encoding UTF8
$tn = 'WLAUNCH'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null
Write-Host ("OK lanzado '{0}' {1} (usuario {2})" -f $Path, $(if($Direct){'[Start-Process]'}else{'[via shell]'}), $ru)
exit 0
