# skill control-gui-remota-por-ssh (cortex) -- parte del kit win-ssh-*; ver ../SKILL.md
<#
  win-ssh-get-processes-list.ps1  -  Lista procesos de la maquina, POR SSH.
  ==================================================================================================
  NO necesita sesion interactiva: corre directo en la sesion SSH (es solo Get-Process). Parte del
  kit win-ssh-* de manejo/inspeccion de Windows por SSH.

  USO:
    powershell -NoProfile -ExecutionPolicy Bypass -File win-ssh-get-processes-list.ps1
    ... -Name MiApp            # filtra por nombre (comodin: MiApp*)
    ... -Top 20                   # top-N por memoria (default 40)
    ... -Csv                      # salida CSV (Name,Id,WS_MB,CPU,Started) para parsear en tu maquina

  ASCII puro, PS 5.1.
#>
[CmdletBinding()]
param(
    [string]$Name,
    [int]$Top = 40,
    [switch]$Csv
)
$p = Get-Process -EA SilentlyContinue
if ($Name) { $p = $p | Where-Object { $_.Name -like $Name -or $_.Name -like "$Name*" } }
$rows = $p | Sort-Object WorkingSet64 -Descending | Select-Object -First $Top | ForEach-Object {
    [pscustomobject]@{
        Name    = $_.Name
        Id      = $_.Id
        WS_MB   = [math]::Round($_.WorkingSet64/1MB,1)
        CPU     = if ($_.CPU) { [math]::Round($_.CPU,1) } else { 0 }
        Started = if ($_.StartTime) { $_.StartTime.ToString('HH:mm:ss') } else { '' }
    }
}
if ($Csv) { $rows | ConvertTo-Csv -NoTypeInformation }
else { $rows | Format-Table -AutoSize | Out-String -Width 200 }
