#!/usr/bin/env pwsh
# install-brain.ps1 - lanzador DELGADO de Windows para el instalador del cerebro (claude-brain).
# Los hooks del cerebro corren bajo BASH en TODAS las plataformas (decision "bash en todos lados",
# sin drift .sh/.ps1). En Windows eso lo provee Git Bash (viene con Git for Windows). Este script
# NO reimplementa la logica: solo verifica bash + jq y delega en `bash brain/install-brain.sh`,
# que es idempotente y hace todo el trabajo real (hooks, cableado, skill, dashboard, normas).
# Correr tras clonar:  pwsh -File brain\install-brain.ps1
$ErrorActionPreference = 'Continue'

# -- Dependencia dura: GIT BASH (NO el bash de WSL) --
# OJO: `Get-Command bash` en una maquina con WSL devuelve C:\Windows\System32\bash.exe (el lanzador
# de WSL), que NO entiende rutas Windows (C:/... no existe en WSL, seria /mnt/c/...) ni trae las
# herramientas del cerebro (jq, etc.) -> el instalador fallaba con "No such file or directory" y
# "jq no disponible" (bug real Windows+WSL, 2026-07-20). Por eso buscamos PRIMERO el bash.exe de Git
# for Windows en sus ubicaciones conocidas, y solo caemos al 'bash' del PATH si NO es el de System32.
$bash = $null
foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe","${env:ProgramFiles(x86)}\Git\bin\bash.exe","$env:LOCALAPPDATA\Programs\Git\bin\bash.exe")) {
  if (Test-Path $p) { $bash = $p; break }
}
if (-not $bash) {
  $cmd = Get-Command bash -ErrorAction SilentlyContinue
  # Ignora el bash de WSL (System32\bash.exe): no sirve para los hooks del cerebro.
  if ($cmd -and $cmd.Source -and ($cmd.Source -notlike "*\System32\*")) { $bash = $cmd.Source }
}
if (-not $bash) {
  Write-Host "ERROR: no encuentro Git Bash. Los hooks del cerebro corren bajo bash (Git Bash, NO WSL)."
  Write-Host "  En Windows instala Git for Windows (trae Git Bash):  winget install Git.Git"
  Write-Host "  (Si 'bash' te resuelve al de WSL en System32, este instalador ahora lo ignora a proposito.)"
  Write-Host "  Luego re-corre: pwsh -File brain\install-brain.ps1"
  exit 1
}
$bashExe = $bash

# -- Puente HOME <-> USERPROFILE (solo Windows) --
# install-brain.sh cabla el cerebro en $HOME/.claude; el widget (BrainInspector.cs/.swift) lo LEE desde
# %USERPROFILE%\.claude. En Windows el $HOME de Git Bash puede DIVERGIR de %USERPROFILE% (p.ej. un
# HOMESHARE de dominio) -> el cerebro quedaria en un ~/.claude que el widget NO mira. Forzamos
# HOME=%USERPROFILE% para este proceso; el bash hijo (install-brain.sh) lo hereda -> ambos apuntan al
# MISMO .claude. Este es un .ps1 (solo Windows), no afecta a Mac/Linux.
if ($env:USERPROFILE) { $env:HOME = $env:USERPROFILE }

# -- PATH: asegurar que 'bash' quede en el PATH de USUARIO (persistente) --
# Git for Windows / winget ponen git.exe (Git\cmd) en el PATH, pero NO bash.exe (vive en Git\bin).
# Claude Code corre los hooks con "shell":"bash" -> si bash no esta en el PATH, los guardrails NO
# aplican. Anadimos Git\bin (bash.exe) al PATH de usuario; NO anadimos Git\usr\bin (evita que
# find/sort de Unix ensombrezcan los de Windows) - bash resuelve sus coreutils solo al arrancar.
$gitBin = Split-Path -Parent $bashExe
$userPath = [Environment]::GetEnvironmentVariable('PATH','User')
if ($null -eq $userPath) { $userPath = '' }
if (($userPath -split ';') -notcontains $gitBin) {
  Write-Host "==> claude-brain: agrego '$gitBin' al PATH de usuario (Claude Code necesita 'bash' para los hooks)"
  [Environment]::SetEnvironmentVariable('PATH', ($userPath.TrimEnd(';') + ';' + $gitBin), 'User')
  $env:PATH = $env:PATH.TrimEnd(';') + ';' + $gitBin   # visible ya en esta sesion
  $script:pathChanged = $true
}

# -- Forzar que Claude Code (CLI) use ESTE Git Bash, NO el de WSL --
# En una maquina con WSL, 'bash' del PATH resuelve a System32\bash.exe (WSL); Claude Code lo ve como
# "Git Bash no disponible" y corre los hooks con WSL/PowerShell -> los .sh (rutas Windows, jq) fallan
# y los guardrails NO aplican. La env var oficial CLAUDE_CODE_GIT_BASH_PATH apunta a Claude Code al
# bash.exe de Git Bash explicitamente, sin depender del orden del PATH (persistente, por usuario).
# (Fuente: docs de Claude Code, troubleshoot-install.) Bug real diagnosticado 2026-07-20 (Windows+WSL).
if ([Environment]::GetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH','User') -ne $bashExe) {
  [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $bashExe, 'User')
  $env:CLAUDE_CODE_GIT_BASH_PATH = $bashExe
  Write-Host "==> claude-brain: CLAUDE_CODE_GIT_BASH_PATH -> $bashExe (Claude Code usara Git Bash, no WSL)"
}

# -- Auto-sanar CRLF: Git for Windows (core.autocrlf=true) clona los .sh con CRLF y bash muere con el \r --
# El .gitattributes del repo lo previene en clones FUTUROS, pero un clon ya existente (o con config
# rara) sigue con CRLF. Aqui quitamos los CR (byte 0x0D) de TODO .sh del repo antes de correr bash,
# byte a byte para no meter BOM ni tocar la codificacion. Idempotente (si ya esta en LF, no hace nada).
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
# C1 (FMEA post-integracion 2026-07-30): en una instalacion MANUAL de Windows (pwsh -File brain\install-brain.ps1
# tras un clon a mano, SIN pasar por bootstrap.ps1) CLAUDE_BRAIN_DIR quedaba sin definir -> los hooks bash caian
# a ~/.claude-brain (inexistente en Windows; aqui el clon vive en %LOCALAPPDATA%\claude-brain-repo) y el auto-sync
# del cerebro fallaba MUDO. Si no esta definida, la exportamos desde el RepoRoot en FORWARD-SLASH (bash se
# atraganta con backslashes) -- mismo patron que bootstrap.ps1. Si bootstrap ya la puso, se respeta.
if (-not $env:CLAUDE_BRAIN_DIR) {
  $brainBash = $RepoRoot -replace '\\','/'
  [Environment]::SetEnvironmentVariable('CLAUDE_BRAIN_DIR', $brainBash, 'User')
  $env:CLAUDE_BRAIN_DIR = $brainBash
}
$fixed = 0
Get-ChildItem -Path $RepoRoot -Recurse -Filter *.sh -File -ErrorAction SilentlyContinue | ForEach-Object {
  $bytes = [IO.File]::ReadAllBytes($_.FullName)
  if ($bytes -contains 13) {
    [IO.File]::WriteAllBytes($_.FullName, [byte[]]($bytes | Where-Object { $_ -ne 13 }))
    $fixed++
  }
}
if ($fixed -gt 0) { Write-Host "==> claude-brain: normalice a LF $fixed script(s) .sh que venian con CRLF (fix Git-for-Windows)" }

# -- Dependencia de los hooks: jq (sin jq los guards fallan abierto y no puedo cablear settings.json) --
# jq lo instala winget en %LOCALAPPDATA%\Microsoft\WinGet\Links (u otra carpeta): ese dir SI esta en el
# PATH de Windows y PowerShell lo ve, pero un bash de LOGIN (-l) reconstruye su PATH desde /etc/profile
# y puede NO incluirlo. Resolvemos jq desde PowerShell y prependemos su carpeta a $env:PATH del proceso,
# para que el bash hijo (que hereda este PATH) lo vea igual que PowerShell. Verificamos con un bash
# NO-login (-c), el MISMO modo con que abajo corre install-brain.sh (el check refleja el run).
$jqCmd = Get-Command jq -ErrorAction SilentlyContinue
$jqExe = if ($jqCmd) { $jqCmd.Source } else { $null }
# Si jq NO esta en el PATH, LOCALIZARLO en las rutas conocidas de WinGet (mismo patron con que arriba
# hallamos bash.exe fuera del PATH). Caso real: `winget install jqlang.jq` deja jq como shim en
# %LOCALAPPDATA%\Microsoft\WinGet\Links\jq.exe o dentro de ...\WinGet\Packages\jqlang.jq*\...\jq.exe,
# pero esa carpeta puede NO estar en el PATH -> `command -v jq` en bash falla y el instalador no cablea
# (y peor: install-brain.sh SALE 0 igual -> el heal del widget diria "curado" mintiendo). Al hallarlo lo
# agregamos al PATH de este PROCESO (lo hereda el bash hijo, para cablear ya) y al PATH de USUARIO
# (persistente, para terminales/Claude Code futuros).
if (-not $jqExe) {
  $jqLink = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\jq.exe'
  if (Test-Path $jqLink) {
    $jqExe = $jqLink
  } else {
    $pkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path $pkgRoot) {
      $found = Get-ChildItem -Path $pkgRoot -Filter 'jq.exe' -Recurse -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Directory.FullName -like '*jqlang.jq*' } | Select-Object -First 1
      if ($found) { $jqExe = $found.FullName }
    }
  }
}
if ($jqExe) {
  $jqDir = Split-Path -Parent $jqExe
  # PATH del PROCESO: para que el bash hijo (que hereda este PATH) vea jq en esta misma corrida.
  if (($env:PATH -split ';') -notcontains $jqDir) { $env:PATH = $jqDir + ';' + $env:PATH }
  # PATH de USUARIO (persistente): para que jq siga visible mas alla de esta sesion (igual que Git\bin).
  $jqUserPath = [Environment]::GetEnvironmentVariable('PATH','User')
  if ($null -eq $jqUserPath) { $jqUserPath = '' }
  if (($jqUserPath -split ';') -notcontains $jqDir) {
    Write-Host "==> claude-brain: agrego '$jqDir' al PATH de usuario (jq lo REQUIEREN los hooks del cerebro)"
    [Environment]::SetEnvironmentVariable('PATH', ($jqUserPath.TrimEnd(';') + ';' + $jqDir), 'User')
    $script:pathChanged = $true
  }
}
& $bashExe -c "command -v jq >/dev/null 2>&1"
if ($LASTEXITCODE -ne 0) {
  Write-Host "ADVERTENCIA: 'jq' no esta disponible en bash. Los hooks lo REQUIEREN (sin jq el"
  Write-Host "  git-branch-guard falla abierto y el instalador no cablea el settings.json)."
  Write-Host "  Instalalo: winget install jqlang.jq  (o choco/scoop install jq)"
}

# -- Detector de aliases de PowerShell NATIVO (bloque <!-- shells:powershell --> del artefacto LEAN) --
# La lib bash (detectar-shells.sh) cubre zsh/bash/fish y escribe el bloque <!-- shells:posix -->; PowerShell
# NO lo puede ver (aliases de PS son objetos del runtime, no lineas de un rc). Por eso este detector corre
# ANTES de delegar a bash y escribe SOLO el bloque powershell. En Windows ambos bloques coexisten (marcados).
# Regla igual que en POSIX: un alias MUERDE un comando de Claude si SOMBREA un binario real
# (Get-Command -CommandType Application). Gotcha de 5.1: curl/wget son ALIAS a Invoke-WebRequest y Windows
# 10+ trae curl.exe real -> el alias lo sombrea (se detecta solo). Salto correcto: & (gcm cmd -CommandType
# Application).Source, NUNCA /bin/cmd. Todo este .ps1 es ASCII puro (PowerShell 5.1 lee un .ps1 sin BOM
# como ANSI; un no-ASCII rompe la tokenizacion) -> el artefacto GENERADO si puede llevar UTF-8, este fuente no.
function Get-PSBitingAliases([string]$psExe) {
  # Corre en el PS destino (con su perfil, para ver los alias del usuario). Por cada alias cuyo nombre
  # sombrea una Application real, emite "nombre->definicion". Devuelve tambien edicion/version en la 1a linea.
  $probe = @'
$ErrorActionPreference = 'SilentlyContinue'
$ed = $PSVersionTable.PSEdition; if (-not $ed) { $ed = 'Desktop' }
$ver = $PSVersionTable.PSVersion.ToString()
$bite = @()
foreach ($a in (Get-Alias)) {
  $app = Get-Command $a.Name -CommandType Application -ErrorAction SilentlyContinue
  if ($app) { $bite += ('`{0}`->`{1}`' -f $a.Name, $a.Definition) }
}
Write-Output ("EDITION`t{0} {1}" -f $ed, $ver)
Write-Output ("BITE`t" + (($bite | Select-Object -Unique) -join ' * '))
'@
  & $psExe -NoLogo -NonInteractive -Command $probe 2>$null
}

function Write-PSBlock() {
  $claudeDir = Join-Path $env:HOME '.claude'
  if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }
  $art = Join-Path $claudeDir 'aliases-activos.md'

  # Enumerar los PowerShell INSTALADOS (pwsh = Core 6+, powershell = Windows PowerShell 5.1).
  $lines = @()
  foreach ($name in @('pwsh','powershell')) {
    $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { continue }
    $out = Get-PSBitingAliases $cmd.Source
    $edition = ''; $bite = ''
    foreach ($l in $out) {
      if ($l -like 'EDITION`t*') { $edition = $l.Substring(8) }
      elseif ($l -like 'BITE`t*') { $bite = $l.Substring(5) }
    }
    if (-not $bite) { $bite = '(ningun alias sombrea un binario real)' }
    $lines += ('- {0} ({1}): {2}' -f $name, $edition, $bite)
  }
  if ($lines.Count -eq 0) { return }  # no hay PowerShell util que reportar

  # Contenido del bloque (ASCII en el fuente; el artefacto ya escrito puede tener UTF-8 de la parte POSIX).
  $content = @('Muerden en PowerShell (sombrean un binario real -> `& (gcm <cmd> -CommandType Application).Source`):')
  $content += $lines
  $content += 'Gotcha 5.1 (Desktop): curl/wget son alias a Invoke-WebRequest (NO son el curl.exe real).'

  Ensure-ArtifactHeader $art
  Upsert-Block $art 'powershell' $content
  Write-Host "==> claude-brain: bloque <!-- shells:powershell --> escrito en $art"
}

function Ensure-ArtifactHeader([string]$file) {
  if ((Test-Path $file) -and (Select-String -Path $file -Pattern 'GENERADO por install-brain' -SimpleMatch -Quiet)) { return }
  # Header ASCII (answer-first): el escape PRIMERO. En Mac/Linux lo escribe bash (puede llevar UTF-8);
  # en Windows lo escribe esto (ASCII) y bash luego lo respeta (ya trae el marcador GENERADO).
  $header = @(
    '<!-- GENERADO por install-brain - NO editar a mano; se regenera en cada bootstrap -->',
    '# Aliases activos de ESTA maquina (per-maquina; NO viaja por git)',
    '**Saltar un alias/funcion:** POSIX/fish -> `command <cmd>` * PS -> `& (gcm <cmd> -CommandType Application).Source`',
    '(NUNCA `/bin/<cmd>`: la ruta varia por OS. En fish `\<cmd>` NO salta una funcion.)'
  )
  [IO.File]::WriteAllText($file, ($header -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Upsert-Block([string]$file, [string]$name, [string[]]$content) {
  $begin = "<!-- shells:${name}:INICIO -->"
  $end   = "<!-- shells:${name}:FIN -->"
  $existing = if (Test-Path $file) { [IO.File]::ReadAllLines($file) } else { @() }
  $out = New-Object System.Collections.Generic.List[string]
  $skip = $false; $replaced = $false
  foreach ($l in $existing) {
    if ($l -eq $begin) { $out.Add($begin); foreach ($c in $content) { $out.Add($c) }; $skip = $true; $replaced = $true; continue }
    if ($l -eq $end)   { $out.Add($end); $skip = $false; continue }
    if (-not $skip) { $out.Add($l) }
  }
  if (-not $replaced) {
    $out.Add($begin); foreach ($c in $content) { $out.Add($c) }; $out.Add($end)
  }
  [IO.File]::WriteAllText($file, ($out -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

try { Write-PSBlock } catch { Write-Host "aviso: no pude detectar aliases de PowerShell ($($_.Exception.Message)); sigo (bash cubre POSIX)" }

# -- Delegar TODO el trabajo real al instalador .sh (fuente unica, idempotente) --
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Installer = Join-Path $ScriptDir 'install-brain.sh'
if (-not (Test-Path $Installer)) {
  Write-Host "ERROR: no encuentro el instalador $Installer"
  exit 1
}
Write-Host "==> claude-brain: delegando en bash $Installer"
# Pasar la ruta a bash con '/' (NO '\'): bash lee cada '\U','\A','\L'... de una ruta Windows como
# secuencia de escape y se COME los backslashes -> "No such file or directory" y el instalador real
# nunca corre (bug real en Windows, 2026-07-20). Una ruta con forward-slashes (C:/Users/.../
# install-brain.sh) la entiende Git Bash sin ambiguedad.
& $bashExe ($Installer -replace '\\','/')
$rc = $LASTEXITCODE
if ($script:pathChanged) {
  Write-Host ""
  Write-Host "NOTA: agregue una carpeta (bash y/o jq) al PATH de usuario. Para que Claude Code (y tu"
  Write-Host "  terminal) la vean, ABRE UNA TERMINAL NUEVA (o reinicia Claude Code). En la actual ya quedo lista."
}
exit $rc
