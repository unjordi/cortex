---
name: despertar-master
description: Despierta (o lista) una sesión master de Claude Code resolviéndola desde la FUENTE CONFIABLE —los transcripts—, no desde el masters.json que driftea. Para cada nombre *-master toma el transcript MÁS RECIENTE (último `customTitle` = nombre, último `cwd` = dónde resumir, mtime = vida), así "cortex-master (2)" vivo le gana al "cortex-master" viejo; si ya está viva NO la relanza (evita lanzar una segunda instancia sobre un id muerto, el error del masters.json chafa). Úsalo con `/despertar-master <nombre>` para revivir un master, o `/despertar-master --lista` para ver quién está vivo/idle y desde qué carpeta resume. Reemplaza "mirar masters.json y lanzar a ciegas".
---

# despertar-master — revivir un master desde la verdad, no desde masters.json

## Qué hace (y por qué así)
Resuelve y DESPIERTA una sesión "master" de Claude Code (`screen` + `claude --resume`) leyendo la **fuente
confiable**: los transcripts en `~/.claude/projects/<slug>/<id>.jsonl`. **Nunca** confía en `masters.json`
para despertar — ese archivo driftea (ids viejos, targets que son worktrees, nombres repetidos) y genera
conflictos de sync en Drive; el 2026-10-14 por eso se lanzó una segunda sesión de `cortex-master` sobre un
id muerto. La verdad vive en el transcript:

- **nombre** = último `"customTitle"` del transcript (el CLI agrega `" (N)"` al duplicar → se le quita).
- **cwd de resume** = último `"cwd"` del transcript (dónde estaba parada la sesión). Si ese cwd cae en un
  worktree ENLAZADO (que puede borrarse tras un merge → carpeta muerta), se resuelve al toplevel del
  worktree PRINCIPAL; un subfolder legítimo del repo principal se deja intacto.
- **vida** = mtime reciente (`< DESPERTAR_VIVA_MIN`, def 15m) **O** un `screen` con ese nombre **O** un
  proceso `claude --resume <id>`. Un master puede estar VIVO pero idle > 15m (p. ej. en un screen sin
  actividad); relanzarlo crearía un 2º escritor sobre su transcript → **viva por cualquiera de las 3 señales
  ⇒ NO relanzar**.
  - **Límite conocido:** una sesión que NO corre bajo un `screen` con el nombre del master Y cuyo proceso
    NO trae `--resume <id>` en su cmdline (hospedada por `claude daemon`, o abierta desde VSCodium con
    `/resume` interactivo) es indetectable por señal directa; si además lleva > `DESPERTAR_VIVA_MIN` sin
    escribir su transcript, sale `idle` y se relanzaría. El mtime la cubre mientras se use (escribe su
    transcript), pero una verdaderamente quieta no se distingue de una muerta sin el id en algún lado.
    Mitigación práctica: lánzala/resúmela SIEMPRE por esta skill (que usa `screen -dmS <nombre>`), así
    queda detectable por su screen.
- **cuál gana por nombre** = el transcript MÁS RECIENTE (así `cortex-master (2)` vivo le gana al viejo).

## Uso
```bash
despertar-master.sh                 # = --lista
despertar-master.sh --lista         # tabla: MASTER · EDAD · ESTADO (viva/idle) · CWD de resume
despertar-master.sh <nombre>        # despierta ese master (o avisa que ya está vivo y NO lo relanza)
despertar-master.sh <nombre> --no-esperar   # lanza y regresa sin esperar a que cargue
despertar-master.sh --help
```
El script vive JUNTO a este SKILL.md (`despertar-master.sh`). Al invocar `/despertar-master`:
1. Si el usuario nombró un master → córrelo con ese nombre; devuelve la URL de sesión cuando cargue.
2. Si no nombró ninguno → corre `--lista` y muestra el retrato (quién está vivo, desde dónde resume).

## Cómo despierta (el lanzamiento)
`screen -dmS <nombre> bash -lc '<desecha CLAUDE*>; cd <cwd> && exec claude --resume <id> --remote-control <nombre>'`
y luego espera (hasta `DESPERTAR_ESPERA_S`, def 240s) a que la pantalla pinte `https://claude.ai/code/session_…`
(la devuelve) o pida **confiar el folder** (lo reporta para que lo aceptes a mano con `screen -r`).

## Gotchas (medidos — no los re-descubras)
- **`screen … -X hardcopy` necesita `-p 0 -h`** para capturar la pantalla de Claude; sin eso sale vacía y
  parece que no cargó.
- **Desechar TODO `CLAUDE*` heredado antes de lanzar** (`CLAUDECODE`, `CLAUDE_PID`, …): si el hijo los
  hereda se cree anidado y **no guarda transcript**. El claude hijo re-lee su `settings.json`, así que
  desecharlos es seguro.
- **mtime portable GNU-primero** (`stat -c %Y` antes que `stat -f %m`): al revés, en GNU `-f`=`--file-system`
  vuelca basura con exit 0 y rompe la aritmética. Esta skill corre en la Mac (BSD) y en la Cachy (GNU).
- **Un transcript grande tarda en pintar** (arsenal-master ~4 min): el timeout no significa que falló.
- **`ls -t <glob> | head` bajo `set -o pipefail`** tumba el script si no hay match → aquí NO se usa pipefail.

## Relación con el resto de la infra de masters
- **`masters.json` NO es la fuente de verdad** (lo es el transcript). El auto-registro de `masters.json`
  lo hacía `brain/hooks/exportar-sesion-master.sh`; ese archivo compartido es el que driftea/conflictúa.
  Cada sesión exportada además deja un `<id>.meta.json` per-sid (id, label, originCwd) SIN contención —
  esa es la pieza confiable para resolver masters exportados a otra máquina.
- **`seed.sh`** (sembrar sesiones en otra máquina) es un flujo distinto: siembra los `.gz` de Drive. Esta
  skill es para DESPERTAR en la máquina donde ya viven los transcripts.
- **`reubicar-master`** MUEVE un master de repo (reescribe cwd/slug/refs). Esta skill solo lo DESPIERTA
  donde ya está. Si un master quedó "a medias" tras una mudanza, eso es `reubicar-master`, no esto.

## Qué NO es
- No crea masters (eso es renombrar una sesión a `<algo>-master`). No exporta (eso es el hook). No siembra
  cross-máquina (eso es `seed.sh`). No edita `masters.json` (resolver desde el transcript lo vuelve
  innecesario para despertar).
