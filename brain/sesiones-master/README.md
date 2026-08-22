# claude-sessions — sesiones master de unjordi (sincronizadas por Google Drive)

Hace que las sesiones "master" de Claude Code (una por dominio) **viajen entre las compus de unjordi**
(Mac ↔ Cachy) para poder `claude --resume` la MISMA conversación en cualquiera.

**No hay repo git.** Esta carpeta vive en Google Drive, que ya sincroniza pasivo entre las dos máquinas
— y los transcripts comprimidos son binarios opacos (git no los podría diffear: solo bloat). Drive no
tiene el límite de 100 MB de GitHub ni quota de LFS. (El viejo problema de Drive era corromper `.git`;
aquí NO hay repo, solo `.gz` sueltos → no aplica.)

- **Mac:** `~/Mi unidad/claude-sessions/`
- **Cachy:** `/run/media/unjordi/SteamAndFiles/GoogleDrive/claude-sessions/`

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
cd ~/Mi\ unidad/claude-sessions      # (Cachy: cd /run/media/unjordi/SteamAndFiles/GoogleDrive/claude-sessions)
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
  sesión, aunque nunca "termine". Fast-path barato: en `Stop` solo actúa si el `sid` ya está en
  `masters.json` (no escanea el transcript gigante cada turno).
- **`SessionEnd`** — estado final en salida limpia; aquí sí escanea el título para **detectar/registrar**
  un master nuevo.
- **`PreCompact`** — bonus, justo antes de compactar (no crítico: `Stop` ya cubre la frescura).

> **Por qué 3 y no solo `SessionEnd` (bug real, 2026-07-26):** las master son de **vida larga** — se
> resumen por días y nunca cierran limpio → `SessionEnd` casi nunca disparaba → el export se quedó
> **congelado 2 días** (todo en la Cachy salía viejo). El backbone `Stop`+debounce mata esa causa raíz.

Registrar un master nuevo = renombrar la sesión a `<algo>-master`; en su primer `SessionEnd`/`PreCompact`
se auto-registra en `masters.json` (o agrégalo a mano para que `seed.sh` sepa a qué carpeta pertenece).
