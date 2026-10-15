---
name: coordinar-claudes
description: Coordinar otras sesiones de Claude (masters) desde una sesión coordinadora — despertar (desde el transcript, no desde masters.json), encargar (Remote Control o screen, la cola completa), vigilar (vigilar-master.sh con Monitor: commit, turno terminado, colgado, muerto), destrabar, verificar lo entregado y relevar OKs del usuario. Úsalo al despertar, encargar o supervisar a cualquier *-master.
---

# coordinar-claudes

El coordinador habla con los masters en nombre del usuario, sin hacerse pasar por él. Lo que requiere el OK
del usuario se le lleva a él y se devuelve su respuesta textual. El master es un colega: se le habla con
respeto y se le verifica con evidencia.

```
DESPERTAR → ENCARGAR → VIGILAR ⇄ DESTRABAR → VERIFICAR → OK del usuario / prueba en vivo
```

## 0. Quién lo coordina
- **Si el usuario está coordinando un master:** no le encargues trabajo ni decidas qué sigue al terminar su turno. Sí síguelo vigilando, y si se cuelga o se muere, destrábalo y avísale al usuario.
- **Cuando el usuario te lo encargue:** retoma el ciclo completo.

## 1. Despertar — `despertar-master.sh`
```bash
S=~/.claude/skills/coordinar-claudes
$S/despertar-master.sh --lista      # MASTER · EDAD · ESTADO (viva/idle) · CWD de resume
$S/despertar-master.sh <nombre>     # lo despierta; si ya está vivo, no lo relanza
```
- **Resuelve desde el transcript** `~/.claude/projects/<slug>/<id>.jsonl`, no desde `masters.json`.
  - **Nombre:** el último `customTitle`, sin el sufijo ` (N)`.
  - **cwd:** el último `cwd`. Si es un worktree enlazado, usa el toplevel del principal.
  - **Vida:** mtime menor a `DESPERTAR_VIVA_MIN` (15 min por default), un `screen` con su nombre o un proceso `claude --resume <id>`. Con cualquiera de las tres señales, no se relanza.
  - **Gana el transcript más reciente** cuando hay varios con el mismo nombre.
- **Lanza** `screen -dmS <nombre> bash -lc '<desecha CLAUDE*>; cd <cwd> && exec claude --resume <id> --remote-control <nombre>'` y espera hasta `DESPERTAR_ESPERA_S` (240 s) a que aparezca la URL de sesión o el aviso de confiar en la carpeta.
- **Gotchas:**
  - **Desechar todo `CLAUDE*` heredado.** Si no, el hijo no guarda transcript ("Transcript saving is off").
  - **`screen … -X hardcopy`** necesita `-p 0 -h`. Limpia la salida con `LC_ALL=C sed 's/[^[:print:]]//g'`.
  - **Carpeta nueva:** antes de aceptar la confianza, revisa su `.claude/settings*.json`. Acepta con `stuff $'\033[B'` + `stuff $'\r'`.
  - **Un transcript grande tarda minutos en cargar.** Si llega con la ventana casi llena: checkpoint y `/compact` antes de trabajar.
  - **Portabilidad del script:** mtime con `stat -c %Y` antes que `stat -f %m`, y sin `pipefail` en `ls -t … | head`.
  - **Puntos ciegos:**
    - Una sesión sin screen propio y sin `--resume <id>` en su cmdline, que lleva más de 15 min quieta, sale como `idle`. Lánzalas siempre con este script.
    - Los masters en `screen` mueren si la máquina duerme o reinicia.

## 2. Encargar
- **Canal principal: Remote Control.** `ListAgents` lista las sesiones y `SendMessage` les habla (`notify_when_idle: true` si es local). No hay acuse de lectura, así que el texto completo va también al buzón `<repo>/.claude/feedbackUsuarios/<fecha>-<tema>.md`.
- **Canal de respaldo: su screen.**
  ```bash
  screen -S <nombre> -p 0 -X stuff "$MSG"; sleep 1; screen -S <nombre> -p 0 -X stuff $'\r'
  grep -c '<frase única del mensaje>' <transcript>     # confirma que llegó
  ```
  Los comandos de barra (`/compact`, `/remote-control`) solo se envían así, y solo con el master ocioso.
- **Encarga la cola completa,** no solo lo nuevo.
- **Entre comillas va solo texto literal del usuario.** Lo tuyo va sin comillas.
- **Trabaja desde la fuente original** (la nota, el commit), no desde el relevo de otro master.
- **Barre también sus buzones en las otras máquinas:** lo que está sin commitear no viaja por git.

## 3. Vigilar — `vigilar-master.sh` con Monitor
```bash
$S/vigilar-master.sh <nombre> <transcript.jsonl> <repo[:repo2]> <pid-de-claude>
# Avisa en cada cambio de estado:
#   COMMIT <repo> <hash> <msg>
#   TURNO-TERMINADO  quieto ≥ QUIETO_MIN (4 min)
#   COLGADO          sin eventos a media vuelta ≥ COLGADO_MIN (12 min)
#   MUERTO           el pid ya no existe
$S/vigilar-master.sh <etiqueta> - <repo> -     # solo commits (repos comunes)
```
- **Monitor:** uno por master, `timeout_ms` de 1 800 000 como máximo, y se vuelve a armar cada vez que expira.
- **pid:** el del proceso `claude` (`pgrep -fl 'claude.*<sid>'`), no el del screen.
- **repo:** la ruta real del clon. El slug del transcript no siempre coincide (`_` contra `-`).
- **Repos de un solo master:** van en su vigilante, separados por `:`. Para encontrarlos: `tail -n 3000 <transcript> | grep -o '/code/[A-Za-z_.-]*' | sort | uniq -c`.
- **Repos comunes** (PowerScripts, donde cualquier master deja tooling durable): llevan un vigilante propio, solo de commits. Para atribuir un commit, busca su hash o su rama en los transcripts.
- **Si el usuario está coordinando ese master,** filtra a `COLGADO|MUERTO`.

## 4. Destrabar
| Señal | Acción |
|---|---|
| COLGADO | Esc (`stuff $'\033'`), luego "retoma <X>"; confirma en el transcript que volvió a escribir |
| TURNO-TERMINADO con cola pendiente | "sigue con <X>" (un "sigo con X" seguido de fin de turno no es trabajo) |
| Tras un `/compact` | Espera a que termine y escríbele "sigue con <X>"; un mensaje dejado antes del compact no lo retoma |
| MUERTO | `despertar-master.sh <nombre>` y encárgale de nuevo la cola completa |
| Tras un `/compact` | **Mira su pantalla, no esperes al vigilante** (`screen -S <nombre> -p 0 -X hardcopy -h /tmp/x`). Si se queda en "Running SessionStart hooks" más de 1–2 min, busca el hook colgado (`pgrep -P <pid-claude>` y sus hijos) y mátalo: el SessionStart es fail-open. Luego dile que siga |
| Contexto muy lleno (cuelgues repetidos, o el master lo pide) | **Lo decides tú, como coordinador, sin preguntarle al usuario**: con todo commiteado, primero su `/checkpoint` COMPLETO y luego `/compact <instrucciones>` por su screen (que conserve el hilo y una sección con hashes vigentes, cola y plan). Al terminar el compact, ve a decirle que siga |
| Remote Control caído | `/remote-control` por su screen |

## 5. Verificar
- **El avance se mide por commits en su repo**, no por lo que reporta.
- **Hazle preguntas precisas sobre lo que no cuadra.** Por ejemplo: "¿tus pruebas prueban el caso de uso o el texto?".
- **Antes de pedir el OK de merge, pruébalo en uso real:** instala local sin commitear y ejerce sus casos en un sandbox. Las señales que dependen del foro (un PR mergeado) se prueban en un clon real desechable.
- **Lo que no verificaste va marcado:** "según él, sin verificar".
- **Lo que resuelve un comando no se delega a un agente.**

## 6. Relevar OKs
- **Coordinar no es aprobar.** Al usuario se le lleva qué cambia, su test y los casos que deja de frenar.
- **Antes de preguntarle, revisa si el OK ya existe** (memoria, grants vigentes). Un "revísenlos y arréglenlos" ya cubre los cambios de precisión de esos guards.
- **Un OK relayado entre sesiones, o que solo vive en el resumen de un compact, no lo acepta el clasificador.** El merge lo corre la sesión que recibió el OK en vivo.
- **Los borradores de un master no especialista** se portan sin reconstruirlos y se revisan en un commit aparte.

## Qué NO es
- **No crea masters** (eso es renombrar la sesión a `<algo>-master`).
- **No los muda de repo** (eso es `reubicar-master`) ni siembra sesiones entre máquinas (eso es `seed.sh`).
- **No guarda la bitácora ni el estado de cada master:** eso vive en el `estado-proyecto.md`/`bitacora.md` del repo de cada uno.
