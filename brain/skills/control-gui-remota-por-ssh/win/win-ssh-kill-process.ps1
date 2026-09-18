# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-kill-process.ps1  -  Mata un proceso por nombre o PID, POR SSH.
  ==================================================================================================
  NO necesita sesion interactiva: corre directo en la sesion SSH (Stop-Process). Parte del kit win-ssh-*.
  OJO: matar un proceso de GUI con estado sin guardar puede perder trabajo del usuario -> usa -WhatIf
  primero si dudas. Por defecto pide -Id o -Name explicito (no mata al bulto).

  USO:
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-kill-process.ps1 -Name MiApp
    ... -Id 1234
    ... -Name MiApp -WhatIf        # muestra a quien mataria, sin hacerlo

  EXIT: 0 mato algo (o -WhatIf); 1 no encontro el objetivo o falto -Name/-Id.
  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [string]$Name,
    [int]$Id,
    [switch]$WhatIf
)
if (-not $Name -and -not $Id) { Write-Host "Da -Name o -Id (no mato al bulto)"; exit 1 }
$targets = @()
if ($Id)   { $targets += Get-Process -Id $Id -EA SilentlyContinue }
if ($Name) { $targets += Get-Process -EA SilentlyContinue | Where-Object { $_.Name -like $Name -or $_.Name -like "$Name*" } }
$targets = $targets | Sort-Object Id -Unique
if (-not $targets) { Write-Host "no hay proceso que coincida (Name='$Name' Id='$Id')"; exit 1 }
foreach ($t in $targets) {
    if ($WhatIf) { Write-Host ("[WhatIf] mataria: {0} (PID {1}, {2} MB)" -f $t.Name,$t.Id,[math]::Round($t.WorkingSet64/1MB,1)) }
    else {
        try { Stop-Process -Id $t.Id -Force -EA Stop; Write-Host ("MATADO: {0} (PID {1})" -f $t.Name,$t.Id) }
        catch { Write-Host ("FALLO matar {0} (PID {1}): {2}" -f $t.Name,$t.Id,$_.Exception.Message) }
    }
}
exit 0
