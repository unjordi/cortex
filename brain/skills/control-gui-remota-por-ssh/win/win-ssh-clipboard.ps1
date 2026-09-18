# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-clipboard.ps1  -  Lee o escribe el PORTAPAPELES de la sesion interactiva, POR SSH.
  ==================================================================================================
  El portapapeles es per-sesion; se opera en la SESION INTERACTIVA via `schtasks /IT` con powershell
  -STA (Clipboard exige STA). Util para: PEGAR texto confiable en un campo (set + Ctrl+V con
  win-ssh-send-keys "^v"), o LEER lo que una app copio.

  USO (por SSH; admin + usuario en consola):
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-clipboard.ps1 -Get           # imprime el texto del portapapeles
    powershell ... -File win-ssh-clipboard.ps1 -Set "texto a poner en el portapapeles"

  EXIT: 0 ok; 1 sin sesion de consola o sin -Get/-Set.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [switch]$Get,
    [string]$Set,
    [string]$User,
    [string]$WorkDir = 'C:\GuiSshWork',
    [int]$WaitMs = 1200
)
if (-not $Get -and -not $PSBoundParameters.ContainsKey('Set')) { Write-Host "da -Get o -Set <texto>"; exit 1 }
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
$res = Join-Path $WorkDir 'clip-result.txt'
if ($Get) {
    $body = @"
Add-Type -AssemblyName System.Windows.Forms
`$t = [System.Windows.Forms.Clipboard]::GetText()
Set-Content '$res' `$t -Encoding UTF8
"@
} else {
    $sb = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Set))
    $body = @"
Add-Type -AssemblyName System.Windows.Forms
`$t = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$sb'))
[System.Windows.Forms.Clipboard]::SetText(`$t)
Set-Content '$res' "OK" -Encoding UTF8
"@
}
$f = Join-Path $WorkDir 'clip.ps1'; $body | Set-Content $f -Encoding UTF8
if (Test-Path $res) { Remove-Item $res -Force }
$tn = 'WCLIP'
& schtasks /delete /tn $tn /f *> $null
& schtasks /create /tn $tn /tr "powershell -NoProfile -STA -ExecutionPolicy Bypass -File $f" /sc once /st 23:59 /it /ru $ru /rl limited /f *> $null
& schtasks /run /tn $tn *> $null
Start-Sleep -Milliseconds $WaitMs
& schtasks /delete /tn $tn /f *> $null
if (-not (Test-Path $res)) { Write-Host "FALLO: sin resultado"; exit 1 }
if ($Get) { Get-Content $res -Raw }
else { Write-Host "OK portapapeles seteado" }
exit 0
