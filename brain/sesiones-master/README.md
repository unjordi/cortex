# claude-sessions — sesiones master (sincronizadas por Google Drive)

Hace que las sesiones "master" de Claude Code (una por dominio) **viajen entre las computadoras del usuario**
(Mac ↔ Linux) para poder `claude --resume` la MISMA conversación en cualquiera.

**No hay repo git.** Esta carpeta vive en Google Drive, que ya sincroniza pasivo entre las dos máquinas
— y los transcripts comprimidos son binarios opacos (git no los podría diffear: solo bloat). Drive no
tiene el límite de 100 MB de GitHub ni quota de LFS. (El viejo problema de Drive era corromper `.git`;
aquí NO hay repo, solo `.gz` sueltos → no aplica.)

- **Mac:** `~/Mi unidad/claude-sessions/`
- **Linux:** `<ruta de Google Drive>/claude-sessions/`

## Cómo funciona

Las sesiones de Claude Code viven en `~/.claude/projects/<slug>/<id>.jsonl` (fuera de todo repo), donde
`<slug>` se deriva de la **carpeta (cwd)** en la que corres `claude`. `--resume` las busca por la carpeta
en la que estás parado — la rama de git es irrelevante. Esta carpeta de Drive es el **camión**: guarda
cada transcript comprimido; `seed.sh` lo descomprime en `~/.claude/projects/<slug-local>/` reescribiendo
el cwd a la ruta local (el swap `/Users`↔`/home` sale solo porque el target es `$HOME/code/<repo>`).

## Los masters

| master | se resume desde |
|---|---|
| `claude-brain-master` | `~/code/plantilladotnet` |
| `powerscripts-master` | `~/code/PowerScripts` |
| `databases-master` | `~/code/potenciaDatabases` |
| `cps-master` | `~/code/cps` |
| `sae-master` | `~/code/potenciaDatabases` (hermano de databases; el picker los distingue por nombre) |

## Sembrar en una máquina

```bash
cd ~/Mi\ unidad/claude-sessions      # (Linux: cd <ruta de Google Drive>/claude-sessions)
./seed.sh                             # siembra lo presente (salta lo ya local; --force pisa)
# luego: párate en la carpeta del master y  claude --resume  → elígela por nombre
```
Requisitos: `cortex` instalado (aporta `session-import.js`) + `node`. En la Cachy, que la unidad
`SteamAndFiles` esté montada y Drive haya terminado de bajar los `.gz`.

## Actualización automática (hook)

No hay que exportar a mano: el hook **`exportar-sesion-master.sh`** (canónico AQUÍ en Drive; `install-hook.sh`
lo copia a `~/.claude/hooks/` y lo cablea) re-exporta el `.gz` de las sesiones `*-master` a esta carpeta,
y Drive lo sincroniza. Corre una vez por máquina: `./install-hook.sh`.

**Gatillos (3, cableados por `install-hook.sh`):**
- **`Stop`** — *backbone*. Dispara al final de **cada turno**, con **debounce** (a lo mucho 1 export cada
  ~20 min por sesión; override `CLAUDE_SESSIONS_DEBOUNCE_MIN`). Mantiene la master fresca **durante** la
  sesión, aunque nunca "termine". Fast-path barato: en `Stop` solo actúa si el `sid` ya tiene su
  `<sid>.meta.json` (ya se exportó alguna vez; no escanea el transcript gigante cada turno).
- **`SessionEnd`** — estado final en salida limpia; aquí sí escanea el título para **detectar** un master
  nuevo y exportarlo (su primer export escribe el `<sid>.meta.json`).
- **`PreCompact`** — bonus, justo antes de compactar (no crítico: `Stop` ya cubre la frescura).

> **Por qué 3 y no solo `SessionEnd`:** las master son de **vida larga** — se resumen por días y nunca
> cierran limpio → `SessionEnd` casi nunca dispara. El backbone `Stop`+debounce evita que el export quede congelado.

## El roster de masters — sin `masters.json` compartido

Un **`masters.json` compartido** en Drive con `{id,name,target}` de cada master generaría conflictos:
varios masters concurrentes escribiéndolo producen **conflictos de sync de Drive** (`masters.json.conflict1-4`)
y **drift** (ids viejos, targets que eran worktrees, nombres repetidos). Por eso el roster se **mantiene a mano
y local**:

- **El hook YA NO escribe `masters.json`.** Solo exporta el `.gz` + su **`<sid>.meta.json`** per-sid
  (`id`, `label`, `originCwd`), que es **conflict-free** (un archivo por sesión).
- **El roster lo DERIVA `seed.sh`** de: (1) los **`masters-<host>.json`** que cada máquina **cura a mano** y
  publica a esta carpeta; (2) el `masters.json` legacy si todavía existe (compat); (3) los `<id>.meta.json`
  como **respaldo** para ids no curados a mano (`name`=`label`, `target`=`originCwd` sin el prefijo del `$HOME`
  de origen). La entrada **curada a mano gana** sobre la derivada (fija el `target` canónico, no un worktree).

Registrar un master nuevo = renombrar la sesión a `<algo>-master` (su export escribe el `<sid>.meta.json`
automáticamente); para fijar un `target` canónico o un nombre distinto, agrégalo a mano a tu
`masters-<host>.json`.
