#!/usr/bin/env pwsh
# Uninstall Cortex Widget (Windows): stop it, drop autostart, remove the app and
# its cache. Also cleans up the old 'ClaudeQuota' name if a previous install left it.
# Leaves your Claude Code credentials/transcripts untouched.
#
#   pwsh -File uninstall.ps1
#   pwsh -File uninstall.ps1 -KeepCache
#
[CmdletBinding()]
param([switch]$KeepCache)

$ErrorActionPreference = 'SilentlyContinue'
$cache   = Join-Path $env:LOCALAPPDATA 'cortex'    # dir de cache interno (state/stats/machine-id/account)
# nombres viejos del cache (migracion): 'claude-quota' (era vieja-vieja) y 'claude-brain' (era intermedia
# del rename #312) -> se limpian igual por si un install previo los dejo.
$cachesOld = @((Join-Path $env:LOCALAPPDATA 'claude-quota'), (Join-Path $env:LOCALAPPDATA 'claude-brain'))
$runKey  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

Write-Host "==> Deteniendo..." -ForegroundColor Cyan
Get-Process Cortex,ClaudeBrain,ClaudeQuota | Stop-Process -Force
Start-Sleep -Milliseconds 400

Write-Host "==> Quitando autoarranque..." -ForegroundColor Cyan
Remove-ItemProperty -Path $runKey -Name 'Cortex'
Remove-ItemProperty -Path $runKey -Name 'ClaudeBrain'   # era intermedia (migracion)
Remove-ItemProperty -Path $runKey -Name 'ClaudeQuota'   # nombre viejo-viejo (migracion)

Write-Host "==> Quitando acceso directo del menu Inicio..." -ForegroundColor Cyan
$startMenu = [Environment]::GetFolderPath('Programs')
Remove-Item (Join-Path $startMenu 'Cortex.lnk') -Force
Remove-Item (Join-Path $startMenu 'Claude Brain.lnk') -Force   # era intermedia (#312)
Remove-Item (Join-Path $startMenu 'Claude Quota.lnk') -Force   # nombre viejo-viejo

foreach ($n in @('Cortex','ClaudeBrain','ClaudeQuota')) {
    $d = Join-Path $env:LOCALAPPDATA "Programs\$n"
    if (Test-Path $d) { Write-Host "==> Borrando $d ..." -ForegroundColor Cyan; Remove-Item $d -Recurse -Force }
}

if (-not $KeepCache) {
    Write-Host "==> Borrando cache $cache ..." -ForegroundColor Cyan
    Remove-Item $cache -Recurse -Force
    foreach ($co in $cachesOld) { Remove-Item $co -Recurse -Force }   # nombres viejos (migracion)
}

Write-Host "Desinstalado." -ForegroundColor Green
