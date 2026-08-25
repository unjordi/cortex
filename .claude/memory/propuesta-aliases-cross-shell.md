# Propuesta: detector cross-OS/cross-shell de aliases + artefacto LEAN para `@import`

> Diseño de un agente premium (opus, 2026-08-07), a petición de unjordi. READ-ONLY: es una PROPUESTA
> para implementar, nada tocado aún. Motivo: los aliases muerden comandos de Claude en silencio y
> queman tokens en TODAS las sesiones. La solución (artefacto lean) debe ir en un `@import` del CLAUDE.md
> global per-máquina para estar SIEMPRE en contexto.

## Diagnóstico del mecanismo actual (install-brain.sh bloque (d2), ~L229-314)
Detecta SOLO el shell de LOGIN (`$SHELL -ic 'alias'`), lista FIJA de 5 comandos (`ls rm cp mv grep`),
presencia de 8 tools; siembra el bloque `<!-- detectado-por-bootstrap -->` en `entorno-esta-maquina.md`.
`install-brain.ps1` es solo launcher → **cero cobertura PowerShell**. Huecos:
- (a) solo login shell; (b) solo zsh/bash (ni fish ni PS); (c) lista fija de 5 (frágil);
- (d) el artefacto NO está siempre en contexto (no hay `@import`); 
- (e) BUG `/bin/<cmd>` — el seed ya se corrigió (#284), pero **hay una copia en la sección CURADA A MANO**
  de entorno-esta-maquina.md (L39) que el seed no toca → **ARREGLADO directo 2026-08-07** en el global;
- (f) el escape no es shell-aware: `\<cmd>` no salta funciones ni sirve en fish; el universal es `command <cmd>`.

## Diseño del DETECTOR (misma lógica, comandos por-shell)
Lógica única: detectar OS/arch → enumerar shells INSTALADOS → volcar aliases/funciones cargando su rc →
filtrar a los que SOMBREAN un binario real → emitir línea densa con el escape correcto de ESE shell.
- **`brain/lib/detectar-shells.sh`** (nueva lib bash; corre mac/Linux + Git Bash Windows): zsh/bash/fish.
  Escribe solo su bloque `<!-- shells:posix -->`.
- **`install-brain.ps1`** gana un detector PowerShell NATIVO (`pwsh` + `powershell` 5.1) antes de delegar
  a bash. Escribe solo `<!-- shells:powershell -->`. En Windows corren AMBOS sin pisarse (bloques marcados).
- **Enumerar instalados:** `for sh in zsh bash fish; do command -v "$sh" && …; done` · PS: `Get-Command pwsh,powershell`.
- **Volcado por shell:** zsh/bash `<sh> -ic 'alias'` · fish `fish -ic 'alias'` (formato `alias name valor` SIN `=`) ·
  PS `Get-Alias` + `Get-ChildItem Function:` con Source. PS trae BUILT-INS peligrosos: `ls/cat/rm/cp/mv`, y en
  **5.1** `curl/wget→Invoke-WebRequest` (gotcha grande).
- **"Peligroso" SIN lista fija (hueco c):** el alias muerde ⇔ **existe un binario real homónimo que sombrea**.
  bash/zsh `type -P "$name"` · fish `command -s $name` · PS `Get-Command $name -CommandType Application`.
- **Escape correcto (hueco e+f):** zsh/bash/fish → **`command <cmd>`** (nunca `/bin/<cmd>`); PS →
  `& (Get-Command <cmd> -CommandType Application | Select -First 1).Source`.

## Artefacto LEAN (para `@import`, ≤~20 líneas, answer-first: escape primero)
Archivo GENERADO y derivado (distinto del detector verboso). Ejemplo:
```markdown
<!-- GENERADO por install-brain — NO editar a mano; se regenera cada bootstrap -->
# Aliases activos de ESTA máquina (per-máquina; NO viaja por git)
**Saltar un alias/función:** POSIX/fish → `command <cmd>` · PS → `& (gcm <cmd> -CommandType Application).Source`
(NUNCA `/bin/<cmd>`: la ruta varía por OS. En fish `\<cmd>` NO salta.)
OS: `Darwin 25.5 arm64` · shells: zsh(login), bash, pwsh
Muerden en zsh+bash (sombrean binario real → `command <cmd>`):
- `grep`→`rg` · `ls`→`eza` (flags GNU truenan) · `cat`→`bat` · `find`→`fd`
- `rm`→`trash` (¡NO borra; `rm -rf` truena!) · `cp`/`mv`→`-i` (pueden colgarse pidiendo y/n)
Globs en zsh: comíllalos. · PS built-in: `curl`/`wget`→Invoke-WebRequest (¡no es curl!).
```

## Integración
- Extender `install-brain.sh` (d2) → extraer a `brain/lib/detectar-shells.sh` (patrón `analizar-comando-git.sh`).
- Extender `install-brain.ps1` con el detector PS nativo antes de delegar.
- **Artefacto lean → `~/.claude/aliases-activos.md`** (global per-máquina, NO repo). El detalle curado
  sigue en `entorno-esta-maquina.md`; el lean es VISTA derivada regenerable. Respeta "entorno de máquina = GLOBAL".
- **Cablear `@import`:** el instalador asegura idempotente `@aliases-activos.md` en `~/.claude/CLAUDE.md`
  con su PROPIO marcador (`<!-- brain:import-aliases -->`), fuera del bloque `BEGIN/END claude-brain` que se
  regenera. Claude Code procesa `@imports` recursivos → siempre en contexto sin costar líneas al CLAUDE.md.

## Edge cases
Shell sin rc/tty (`-ic` + `2>/dev/null`, fail-safe a "(sin aliases)") · fish no-POSIX (parseo por espacios,
escape `command`) · PS Core vs 5.1 (condicionar el gotcha curl/wget a la edition) · aliases que son funciones
(por eso `command`, no `\`) · shell no instalado (se excluye) · Windows sin Git Bash/jq (el `.ps1` cubre el
bloque PS aunque bash falle) · doble-escritura evitada por bloques marcados independientes.

## Estado — ✅ IMPLEMENTADO (2026-08-07, rama `feat/detector-aliases-cross-shell`, PR a develop)
Construido TAL CUAL el diseño. Mapeo propuesta → realidad:

| Propuesta | Realidad |
|-----------|----------|
| `brain/lib/detectar-shells.sh` (nueva lib bash, patrón `analizar-comando-git.sh`) | ✅ Creada. Funciones puras + sourceables: `ds_installed_shells`, `ds_dump_aliases`, `ds_parse_posix/fish`, `ds_shadow` (verificador `type -P`), core testeable `ds_biting <fmt> <shadow_fn> <dump>`, `ds_render_posix[_bullets]`, `ds_ensure_artifact_header`, `ds_upsert_block`. Vive en `brain/lib/` (NO en el MANIFEST: es lib de INSTALL-TIME, no hook desplegado). |
| Filtrar a los que SOMBREAN un binario real (hueco c: sin lista fija) | ✅ `ds_shadow` = `type -P` (ruta en disco ⇒ sombrea). En la mac real cazó lo que la lista de 5 se perdía: `mkdir -p`, `vi`→nvim, `mv -i`, etc. |
| Escape correcto `command <cmd>`, nunca `/bin/<cmd>` (huecos e+f) | ✅ En header + bullets; test lo verifica (positivo `command <cmd>`; `/bin/<cmd>` sólo como advertencia NUNCA). |
| Detector PowerShell NATIVO en `install-brain.ps1` (pwsh + 5.1) antes de delegar a bash | ✅ `Get-PSBitingAliases`/`Write-PSBlock`/`Ensure-ArtifactHeader`/`Upsert-Block`. Enumera `Get-Command pwsh,powershell`; muerde ⇔ `Get-Command $name -CommandType Application`; escribe SOLO `<!-- shells:powershell -->`. **ASCII-puro** (guard de 5.1). Parse-check limpio con pwsh. |
| Artefacto LEAN `~/.claude/aliases-activos.md` (≤~20 líneas, answer-first) | ✅ Header con el ESCAPE primero + bloque posix (1 línea densa por shell). GENERADO, no viaja por git. |
| Bloques marcados independientes coexisten en Windows | ✅ `<!-- shells:posix:INICIO/FIN -->` y `<!-- shells:powershell:INICIO/FIN -->`; `ds_upsert_block` (bash) y `Upsert-Block` (PS) usan los MISMOS marcadores → interoperan (probado: PS preserva posix y viceversa). |
| Cablear `@import` idempotente con marcador propio, fuera de BEGIN/END claude-brain | ✅ `<!-- brain:import-aliases -->` + `@aliases-activos.md`. Respeta la guarda anti-truncado (BEGIN-sin-END ⇒ no toca). |
| Extender `install-brain.sh` (reemplaza detección vieja: login-shell / lista-fija-5 / solo-zsh-bash) | ✅ (d2) usa la lib para el bloque detectado de `entorno-esta-maquina.md`; nueva (d3) genera el artefacto + cabla `@import`. `uninstall-brain.sh` (e) quita `@import` + borra el artefacto. |

**Tests (`brain/test-brain.sh`, sección `(ds)` + extensiones a `(c)`/uninstall):** sombra-sí/sombra-no, fish space-format, fail-safe dump vacío, escape correcto, upsert coexistencia/idempotencia, artefacto generado + `@import` 1× tras 2 installs, limpieza al desinstalar. Suite **553 PASS · 0 FAIL**; shellcheck `--severity=error` limpio; `.ps1` ASCII-puro + parse OK.

### Previo (contexto)
- ✅ Hueco (e) instancia viva: `entorno-esta-maquina.md` L39 corregida directo (2026-08-07).
- ✅ Seed del bootstrap: corregido en PR #284 (`command <cmd>`/`\<cmd>`).

### Decisiones tomadas (confirmar con unjordi si algo no cuadra)
- **`brain/lib/` nuevo dir** (no `brain/hooks/`): la lib es de INSTALL-TIME (la sourcea el instalador), no un hook runtime desplegado → fuera del MANIFEST/dedupe. CI ya la cubre (`find brain -name '*.sh'`).
- **`ds_shadow` = `type -P` universal** (en bash) para las 3 familias POSIX, en vez de `command -s` de fish: corremos en bash y "existe un binario homónimo en PATH" es la misma pregunta. Puede marcar aliases como `gs`→git si existe un binario `gs` (ghostscript) — es CORRECTO por la regla (sí sombrea), aunque sorprenda.
- **En Windows el header del artefacto lo escribe el `.ps1` (ASCII)**; en Mac/Linux lo escribe bash (UTF-8). El primero en correr gana; el otro respeta el marcador `GENERADO`. El cuerpo (bullets) SÍ lleva UTF-8 aunque en Windows — el artefacto lo lee Claude Code (UTF-8), sólo el `.ps1` FUENTE debe ser ASCII.
