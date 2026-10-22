---
name: coordinar-claudes
description: Coordinar otras sesiones de Claude (masters) desde una sesión coordinadora — despertar (desde el transcript, no desde masters.json), encargar (Remote Control o screen, la cola completa), vigilar (las señales son lo que el master reporta por mensaje y su pantalla mirada en el momento; vigilar-master.sh con Monitor solo como fallback para un master que NO puede mandar mensajes), destrabar, verificar lo entregado y relevar OKs del usuario. Úsalo al despertar, encargar o supervisar a cualquier *-master.
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
$S/despertar-master.sh <nombre> --mensaje <archivo>   # lo despierta y el archivo es su PRIMER mensaje
$S/despertar-master.sh --cerrar <nombre>              # cierra su proceso claude y su screen; verifica
```
- **Resuelve desde el transcript** `~/.claude/projects/<slug>/<id>.jsonl`, no desde `masters.json`.
  - **Nombre:** el último `customTitle`, sin el sufijo ` (N)`.
  - **cwd:** el último `cwd`. Si es un worktree enlazado, usa el toplevel del principal.
  - **Vida:** mtime menor a `DESPERTAR_VIVA_MIN` (15 min por default), un `screen` con su nombre, o un proceso `claude` retomado por su id o por su título (`--resume <id>`, `--resume=<id>`, `--resume [--flags] <título>`). Con cualquiera de las señales, no se relanza. Con `--mensaje` no cuenta la edad del transcript: solo proceso o screen.
  - **Procesos:** solo cuenta un proceso cuyo ejecutable (argv[0]) es `claude`, leído con `ps`. Así nunca se cuenta a sí mismo ni a un bash/grep que lleve el patrón en su línea de comando. Nada de `pgrep -f`/`pkill -f` para esto: se matchean solos, y en macOS `pgrep -f` no ve los argumentos de algunos procesos.
  - **Gana el transcript más reciente** cuando hay varios con el mismo nombre.
- **Lanza** `screen -dmS <nombre> bash -lc '<desecha CLAUDE*>; cd <cwd> && exec claude --resume <id> --remote-control <nombre>'` y espera hasta `DESPERTAR_ESPERA_S` (240 s) a que aparezca la URL de sesión o el aviso de confiar en la carpeta.
- **Gotchas:**
  - **Desechar todo `CLAUDE*` heredado.** Si no, el hijo no guarda transcript ("Transcript saving is off").
  - **`screen … -X hardcopy`** necesita `-p 0 -h`. Limpia la salida con `LC_ALL=C sed 's/[^[:print:]]//g'`.
  - **Carpeta nueva:** antes de aceptar la confianza, revisa su `.claude/settings*.json`. Acepta con `stuff $'\033[B'` + `stuff $'\r'`.
  - **Un transcript grande tarda minutos en cargar.** Si llega con la ventana casi llena: checkpoint y `/compact` antes de trabajar.
  - **Portabilidad del script:** mtime con `stat -c %Y` antes que `stat -f %m`, y sin `pipefail` en `ls -t … | head`.
  - **Punto ciego:** los masters en `screen` mueren si la máquina duerme o reinicia.

## 2. Encargar
- **Canal principal: Remote Control.** `ListAgents` lista las sesiones y `SendMessage` les habla (`notify_when_idle: true` si es local). No hay acuse de lectura, así que el texto completo va también al buzón `<repo>/.claude/feedbackUsuarios/<fecha>-<tema>.md`.
- **Canal de respaldo: su screen.**
  ```bash
  screen -S <nombre> -p 0 -X stuff "$MSG"; sleep 1; screen -S <nombre> -p 0 -X stuff $'\r'
  grep -c '<frase única del mensaje>' <transcript>     # confirma que llegó
  ```
  Los comandos de barra (`/compact`, `/remote-control`) solo se envían así, y solo con el master ocioso.
- **Confirma SIEMPRE la llegada** con el `grep -c` en su transcript. Sin eso, el mensaje no llegó.
- **Si ninguno de los dos canales entrega** (visto el 2026-10-19: la TUI dejó de aceptar `stuff`/`paste` de screen y el texto no aparecía ni en pantalla ni en el transcript): `despertar-master.sh --cerrar <nombre>` y luego `despertar-master.sh <nombre> --mensaje <archivo>`. El mensaje entra como prompt inicial del resume, sin teclear en la TUI. Solo con el master ocioso: cerrarlo corta lo que esté haciendo.
- **Encarga la cola completa,** no solo lo nuevo.
- **Entre comillas va solo texto literal del usuario.** Lo tuyo va sin comillas.
- **Trabaja desde la fuente original** (la nota, el commit), no desde el relevo de otro master.
- **Barre también sus buzones en las otras máquinas:** lo que está sin commitear no viaja por git.

## 3. Vigilar — el MENSAJE del master y su PANTALLA, no un vigilante
> Decisión de unjordi 2026-10-21 [user: "no tardan nada en compactar. no dejes vigilantes para eso!"; "qué carajos mide el vigilante? no tiene sentido."]. Medido: el vigilante (a) NO veía commits hechos en un **worktree** (miraba el toplevel equivocado), (b) avisaba commits ya revisados minutos después, y (c) duplicaba lo que el master ya manda por `SendMessage`.

- **Las señales son DOS: lo que el master REPORTA por mensaje** (`SendMessage` / su buzón `feedbackUsuarios`) **y su PANTALLA mirada EN EL MOMENTO** (`screen -S <nombre> -p 0 -X hardcopy -h /tmp/x`). NO armes un Monitor ni un loop de espera para commits o fin de turno — un master que coordina sabe reportar; si no reporta, miras su pantalla.
- **Tras mandarle `/compact`:** un timer SIMPLE (~2 min, `sleep 120` con `run_in_background`) te despierta a MIRAR su pantalla y decirle que siga. No un vigilante (compactar no tarda nada) [user: "pon un vil timer que te despierte en 2 minutos o algo así cuando lo mandes a compactar!"].
- **Sus diálogos de permiso los apruebas TÚ por su screen** (entrar a su worktree, operar en su repo/rama, lo que el harness pregunte de más) — no le preguntas al usuario si les das permiso de trabajar.
- **`vigilar-master.sh` + Monitor queda SOLO como fallback para un master que NO puede mandar mensajes** (sin Remote Control ni screen accesible):
```bash
$S/vigilar-master.sh <nombre> <transcript.jsonl> <repo[:repo2]> <pid-de-claude>   # COMMIT / TURNO-TERMINADO / COLGADO / MUERTO
```
  - **Monitor:** uno por master, `timeout_ms` ≤ 1 800 000, re-armado al expirar. **pid:** el del proceso `claude` (`pgrep -fl 'claude.*<sid>'`), no el del screen. **repo:** la ruta real del clon (el slug del transcript no siempre coincide, `_` vs `-`) — y OJO: un master que trabaja en un **worktree** commitea AHÍ, no en el toplevel (causa (a) del descarte del vigilante).

## 4. Destrabar
| Señal | Acción |
|---|---|
| COLGADO | Esc (`stuff $'\033'`), luego "retoma <X>"; confirma en el transcript que volvió a escribir |
| TURNO-TERMINADO con cola pendiente | "sigue con <X>" (un "sigo con X" seguido de fin de turno no es trabajo) |
| Tras un `/compact` | Espera a que termine y escríbele "sigue con <X>"; un mensaje dejado antes del compact no lo retoma |
| MUERTO | `despertar-master.sh <nombre>` y encárgale de nuevo la cola completa |
| Tras un `/compact` | **Pon un timer SIMPLE (~2 min, `sleep 120` con `run_in_background`) y mira su pantalla, no armes un vigilante** (`screen -S <nombre> -p 0 -X hardcopy -h /tmp/x`). Si se queda en "Running SessionStart hooks" más de 1–2 min, busca el hook colgado (`pgrep -P <pid-claude>` y sus hijos) y mátalo: el SessionStart es fail-open. Luego dile que siga |
| Contexto muy lleno (cuelgues repetidos, o el master lo pide) | **Lo decides tú, como coordinador, sin preguntarle al usuario**: con todo commiteado, primero su `/checkpoint` COMPLETO y luego `/compact <instrucciones>` por su screen (que conserve el hilo y una sección con hashes vigentes, cola y plan). Al terminar el compact, ve a decirle que siga |
| Remote Control caído | `/remote-control` por su screen |
| No le entra nada (ni SendMessage ni screen; `grep -c` en 0) | Con el master ocioso: `--cerrar <nombre>` y `<nombre> --mensaje <archivo>` con la cola completa; confirma con `grep -c` |

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
