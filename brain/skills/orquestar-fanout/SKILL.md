---
name: orquestar-fanout
description: >
  Orquestar un fan-out de agentes SIN NIÑERA: asignar ítems autocontenidos del backlog, y que al
  terminar cada agente su avance quede registrado y su worktree limpio AUTOMÁTICAMENTE — no
  monitoreándolos a mano. Define el modelo de estado (2 archivos, sin redundancia) y el contrato de
  reporte. Úsalo cuando delegues trabajo paralelizable a varios agentes.
---

# orquestar-fanout — fan-out con auto-reporte (sin niñera)

El hueco que cierra: los agentes hacían el trabajo pero NO reportaban; el estado del proyecto
dependía de que el humano lo pidiera y monitoreara a mano. Esta skill hace del **auto-reporte el
default** y mata la redundancia de dónde vive el estado.

## Modelo de estado — DOS archivos, roles claros (cero redundancia)
- **`.claude/memory/estado-proyecto.md`** = la **fuente de verdad**: dónde estamos + **BACKLOG VIVO**
  (pendientes autocontenidos, con prioridad + HELD "esperan tu decisión" + follow-ups + justificación).
  **Aquí empiezas siempre.** Lo **cura el orquestador** (no los agentes en paralelo → cero conflictos).
- **`.claude/memory/bitacora.md`** = **log cronológico append-only** (qué se cerró y cuándo). `merge=union`
  → parallel-safe. **Aquí APPENDAN los agentes/orquestador** una línea por slice.
- Regla anti-redundancia: **el mismo dato NO se escribe en 3 lados.** bitácora = *qué pasó*;
  estado-proyecto = *qué sigue*. El estado "actual" se DERIVA (leer ambos), no se triplica.
- La lista de **TodoWrite** del harness es **scratch de sesión** — el backlog DURABLE es
  estado-proyecto.md. No confundas una con la otra.
- **Corolario — lo DELEGADO a un artefacto tampoco es el backlog:** un ítem que empujaste al TEXTO de un
  entregable (sección "Pendientes/Delegados/§ fuera de alcance" de un skill, un dictamen, un README) NO
  está resuelto ni registrado — es log disfrazado de backlog. Va a estado-proyecto.md con severidad. El
  paso de cierre que lo exige vive en [[cerrar-slice]].

## PREREQUISITO: la sesión debe vivir DENTRO de un repo git
El fan-out con worktrees aislados **exige que el cwd de la sesión sea un repo git** — Claude Code
solo sabe crear worktrees vía git. Si lanzas un agente con `isolation: "worktree"` desde una sesión
cuyo cwd NO es un repo, truena con:
`Cannot create agent worktree: not in a git repository and no WorktreeCreate hooks are configured`
(los hooks `WorktreeCreate`/`WorktreeRemove` que menciona el error son para OTROS VCS — no aplican aquí).
**Regla práctica:** inicia la sesión EN el repo (además así carga sus hooks/`CLAUDE.md` — las sesiones
se INICIAN en el repo, no se mudan a él, ver abajo). Si el trabajo es multi-repo, ancla la sesión en el
repo principal y que los agentes creen sus worktrees con `git -C <ruta-del-repo> worktree add …`.
(Caso real: CachyOS, 2026-07-20.)

## Regla dura de AISLAMIENTO (lo que evita que un agente te coma trabajo)
**Todo agente que MUTE archivos o COMMITEE corre en un WORKTREE AISLADO, NUNCA en el árbol de trabajo
COMPARTIDO/principal.** Spawnéalo con `isolation: "worktree"` (el Agent tool crea un worktree fresco) o
dale tú un worktree disjunto. El árbol principal es SOLO del orquestador (o del humano). **Por qué muerde:**
un agente que corre `git reset`/`checkout`/`rebase` en el árbol compartido puede **mover el HEAD y dejar
huérfanos los commits del orquestador** → la fuente queda a medias y el build compila eso (lección REAL,
2026-07: un agente de verificación se metió al árbol principal, reseteó HEAD y orfanó un commit; se
recuperó por cherry-pick, pero casi se pierde). Si un ítem NO se puede aislar en su worktree, **lo hace el
orquestador**, no un agente suelto en el árbol compartido. Lo respalda el guard `proteger-arbol` (avisa
antes de un git destructivo que orfanaría commits sin pushear).

> **GOTCHA del worktree — base equivocada (feedback real, 2026-07).** El Agent tool crea el
> worktree basado en **`origin/HEAD`** (= el default branch remoto, normalmente `origin/main`), **NO** en
> el HEAD de tu rama activa. Si `main` es release-only y tu trabajo vive en `develop`/una ramita (p. ej. una
> migración a una nueva estructura aún NO promovida a main), el worktree nace en un commit VIEJO (la estructura
> previa) y el agente NO encuentra los archivos que espera. **Workaround defensivo (ponlo en el prompt del agente):**
> *"al iniciar, `git reset --hard <rama-objetivo>` en TU worktree aislado para nacer sobre la base correcta"*
> — es seguro porque es tu worktree AISLADO (no el compartido). Disparará `proteger-arbol` (aviso, no bloqueo):
> es un falso positivo conocido en worktree aislado (backlog H14). Fix de raíz = harness (backlog H15).
>
> **El workaround NO basta por sí solo — el ORQUESTADOR verifica la BASE, no la cree (lección REAL, C7, 2026-07-21).**
> Un agente reportó "reseteé a `DevelopUnjordi`" pero su commit salió con **parent = tip de `main`**
> (el reset no ocurrió, o falló en silencio): al nacer sobre `main` NO vio infra que sí existía en
> `develop` y **rehízo trabajo redundante**. El auto-reporte del agente sobre su propia base es
> exactamente lo que NO es evidencia. **Antes de integrar el commit de un agente, el orquestador
> COMPRUEBA su linaje con git** (no confía en la prosa del reporte):
> `git merge-base --is-ancestor <commit>^ <rama-objetivo>` (¿su padre YA está en mi rama?) y
> `git log --oneline -1 <commit>^` / `git show --stat <commit>` (¿el padre y el diff son los esperados?).
> Si el padre resultó ser `main` (u otra base equivocada) → **NO integres**: descarta la rama y rehaz
> el ítem sobre la base correcta. **Integra por CHERRY-PICK del delta** (no `merge`) cuando la base del
> agente pueda estar vieja — el merge arrastraría el árbol viejo; el cherry-pick trae solo el cambio neto.

> **GOTCHA del worktree — UBICACIÓN equivocada (feedback real de unjordi, 2026-07-29).** Un worktree
> creado a mano/por agente con `git worktree add <ruta>` puede aterrizar **donde no debe** y ensuciar el
> folder del usuario. Dos formas vistas de verdad, ambas en la misma sesión:
> - un **hermano `<repo>.wt/`** al lado del repo, en `~/code/` (el usuario lo VE en Finder y estorba);
> - un worktree de **OTRO repo ANIDADO dentro** del worktree de un repo distinto
>   (`potenciaDatabases/.claude/worktrees/agent-XXXX/wt-cablear` era un worktree de `pisamrpclaude`).
>
> **Regla dura:** todo worktree va SIEMPRE a **`<ese-mismo-repo>/.claude/worktrees/<nombre>`** — la
> convención del harness (`isolation: "worktree"` y `EnterWorktree` ya lo hacen bien; el riesgo está en
> el `git worktree add` MANUAL). Nunca un hermano `.wt`, nunca dentro del árbol de otro repo. Multi-repo:
> `git -C <repoB> worktree add <repoB>/.claude/worktrees/<nombre>` — la ruta destino pertenece al repo
> DUEÑO de la rama, no al repo donde estás parado.
>
> **Por qué muerde (no es cosmético):** el barredor `limpiar-worktrees.sh` opera por repo; si un worktree
> de B vive anidado dentro de uno de A, al barrer A como zombie **se lleva el worktree de B y su trabajo
> sin commitear**, y deja el admin de git de B (`.git/worktrees/<n>/gitdir`) apuntando a una ruta borrada.
> En el caso real el anidado traía un cambio staged sin commitear (además una REGRESIÓN abandonada).
> **Al orquestar:** si ves un worktree fuera de `<repo>/.claude/worktrees/`, NO lo barras a ciegas —
> revisa primero `git -C <wt> status` + si sus commits ya están integrados, y muévelo/ciérralo aparte.

## Con agentes ACTIVOS — reglas anti-desastre (destiladas de un caso real, 2026-07)
- **El sub-agente es TERMINAL.** Su prompt DEBE decírselo: *"eres terminal — cuando tu turno acaba NADA
  tuyo sigue corriendo; NO puedes 'lanzar en background' ni esperar notificaciones. Ejecuta el trabajo
  COMPLETO en ESTE turno."* (En un caso real un agente se despidió creyendo que dejó algo "corriendo en background"
  — no había hecho nada, esperaba una notificación que jamás llegaría.)
- **Verifica ANTES de creer — incluida la BASE del commit.** El reporte de un agente NO es evidencia: el
  orquestador comprueba el resultado real (git status/worktree/archivo existe/compila) **read-only** antes
  de marcar el ítem hecho — **y verifica el LINAJE del commit** (que su padre esté sobre la rama-objetivo,
  no sobre `main`; ver el GOTCHA de base equivocada arriba) ANTES de integrar. Un "reseteé a la rama X" del
  agente es justo lo que hay que comprobar, no creer (caso C7, 2026-07-21).
  El prompt del agente exige *"ENTREGA el artefacto ejecutado y verificado, NO un plan ni un stub; si no
  puedes completarlo, dilo explícito"* (agentes devolvieron esqueletos en vez del trabajo real).
- **NUNCA publiques/deployes desde el worktree de un agente.** Los worktrees NO heredan archivos
  gitignored (p. ej. `appsettings.json`) → un publish desde ahí sale con manifiesto inconsistente y
  **rompe la app** (en un caso real tumbó el login del usuario). El deploy sale SIEMPRE del clon principal tras `git pull`.
- **Con agentes activos, el orquestador NO hace `git checkout`/build en el clon principal** (cruzaría la
  rama que un worktree tiene tomada — "is already used by worktree"). Usa tu propio worktree o espera.
- **Mensajería con dirección explícita.** Encabeza los mensajes a un agente con `[DE: orquestador → PARA:
  agente X]` para que no confunda una instrucción-descendente con un reporte-ascendente (un agente prudente
  lee un mensaje ambiguo como posible inyección y se traba).
- **PORTA, no REHAGAS** (migración/armonización). Si ya existe la fuente VIVA (el código de la app legada
  / otra app / un proyecto de referencia), el agente la **cita y la LEE ANTES de escribir** y la ADAPTA.
  **PROHIBIDO reconstruir desde cero** un componente que ya funciona (rehacerlo en vez de traer el que servía).
  El prompt del agente lo dice explícito: *"PORTAR = copiar el artefacto que YA funciona y adaptarlo; cita
  el archivo origen; si no existe fuente, dilo — no inventes"*.
- **Emite un LATIDO de estado** mientras haya agentes EN VUELO — no quedes mudo. El usuario no debería
  preguntar "¿sigues? ¿todo bien?": reporta avance periódico (qué agente va en qué), no solo el volcado a
  bitácora al cerrar. Señal de desvío: el usuario preguntó "¿ping?".
- **INICIA cada agente EN el repo destino; PROHIBIDO "cambia de folder" a media sesión.** Los hooks y el
  `CLAUDE.md` de un repo se cargan SOLO al INICIAR la sesión/agente en él — mudarse a otro folder a mitad
  NO los carga (el agente opera con las normas equivocadas). Si un agente debe trabajar otro repo, se
  INICIA ahí. Recuerda esto si un agente corre en un cwd distinto al de su arranque.

## El flujo (lo que hace el orquestador)
1. **Asigna:** saca del backlog (estado-proyecto.md) ítems **autocontenidos** (uno que un agente
   pueda cerrar solo, sin depender de otro en vuelo). Reparte **archivos disjuntos** (regla anti-choque)
   y **cada agente que toque código va en su WORKTREE AISLADO** (ver regla dura arriba).
2. **Contrato del agente:** cada agente DEVUELVE, además del trabajo:
   - **`informe`: la RUTA de un `.md` que el agente ESCRIBIÓ a disco** — nunca el análisis en prosa
     dentro del valor de retorno. **Regla dura (unjordi 2026-07-30): el reporte de un agente SIEMPRE
     se entrega como archivo `.md`, aunque el agente no haya usado worktree y aunque "solo investigue".**
     Lo que vuelve al orquestador es el *resumen ejecutivo + la ruta*; el desarrollo completo vive en el
     archivo. Porqué: un análisis que solo viaja en el valor de retorno vive únicamente en el CONTEXTO
     del orquestador → **el siguiente compact lo borra** (caso real: 4 agentes analizaron los módulos
     sin migrar de `pisamrp_4.6`, entregaron ~30 páginas en prosa, y al compactar se perdieron; lo único
     que sobrevivió fue lo que alguien había appendeado a la bitácora). Dónde: si el agente trabaja en un
     worktree, el `.md` va en su rama (viaja con el MR); si NO tiene worktree (agente de solo-lectura /
     investigación), va a la carpeta de análisis del repo (`docs/`, `.claude/memory/` o el scratchpad de
     la sesión **solo si es desechable de verdad**). Un informe que vale releer se **versiona**.
   - `qué hizo` (el cambio neto),
   - `base`: la rama y el **SHA real** sobre los que construyó, **verificado con git** (`git rev-parse HEAD^`,
     `git rev-parse --abbrev-ref HEAD`), NO asumido — el orquestador lo re-verifica antes de integrar (ver GOTCHA de base),
   - `línea-de-bitácora` curada (prosa, no el pegote de commits),
   - `pendiente` que deje para otro (o "ninguno"),
   - `worktree`: `limpio` (rama mergeada) o `dejado-con-<nota>`.
3. **Cierra el loop (AUTOMÁTICO al terminar cada agente — lo recuerda el hook `delegacion-reporte`):**
   - **APPENDA** la línea a `bitacora.md`.
   - **ACTUALIZA/cierra** el ítem en `estado-proyecto.md` (backlog vivo).
   - **WORKTREE:** corre `limpiar-worktrees.sh` (borra los de ramas ya mergeadas; los vivos/a-medias
     los DEJA y anota su pendiente en la bitácora para quien lo retome).
   → No monitoreas a los agentes: el reporte y la limpieza son el cierre estándar.

## Verificar antes de creer (el bucle de revisión — no le creas al agente su "listo")
Regla dura (ver norma global): **no relates el reporte de un agente al usuario como verdad, ni
construyas encima, sin haber verificado sus afirmaciones concretas contra la realidad tú mismo.** Lo
verificado se relata como verificado; lo no verificado se etiqueta "según el agente, sin verificar aún".
Dos costos de creerle a ciegas: (1) el error se propaga (el agente confabula o sobre-afirma "✓" y tú lo
relatas como cierto — el usuario lo descubre después), y (2) nunca mejoras tus prompts (es justo en
CÓMO tropieza donde está la señal de qué refinar — revisar SIEMPRE es terapia con datos de más de una
corrida, no anécdota).

**El bucle, por cada agente que reporta:**
1. **Extrae las afirmaciones concretas y comprobables** ("escribí X en Y", "N items coinciden", "0
   errores", "corre").
2. **Verifica cada una contra la fuente real** — barato, tú mismo, sin pedirle QA al usuario: *"escribí/
   edité Z"* → léelo (¿existe la sección? ¿se truncó el resto?); *"N coinciden / cuenta = K"* → re-mídelo
   con un comando barato (find/stat/grep/parse), no aceptes el número; *"cambié estado vivo"* → re-lee el
   estado y confirma que no rompió lo de al lado + que el backup existe; *"corre / funciona / se ve"* → o
   lo compruebas por una vía programática (proceso, log, exit code), o lo etiquetas NO verificado (no lo
   declares LISTO).
3. **Muestrea lo caro.** Si verificar TODO es carísimo (p. ej. 300 items), verifica una muestra
   representativa (primeros/últimos/aleatorios) + los invariantes (conteos, totales) y DILO ("verifiqué N
   de M + los totales") — nunca finjas cobertura total. Barato = hazlo siempre (re-contar con un parse,
   `stat`/`find -printf %s`, `grep -c`, leer el archivo, `diff` contra un backup); caro = muestrea.
4. **Clasifica el resultado:** CONFIRMADO (lo comprobé) · CORREGIDO (encontré y arreglé un error) ·
   REFUTADO (la afirmación era falsa → no se relata como hecho, se re-trabaja).
5. **Cierra el bucle de prompt.** Anota cómo tropezó (dejó "?" por un caso que el prompt no cubría,
   sobre-afirmó, malinterpretó el alcance) y qué refinar la próxima vez. Si el mismo tropiezo se repite
   entre agentes, apúntalo a la memoria del proyecto o al estado.

**El caso REBUILD/REEMPLAZO — el DIFF DE PRESERVACIÓN (lo que un rebuild SILENCIA).** Cuando el
entregable REEMPLAZA un archivo existente (un agente reescribe un `CLAUDE.md`, un README, una config
"desde cero"), el modo de falla NO es una afirmación falsa — es la OMISIÓN SILENCIOSA: el rebuild suelta
contenido real y no lo dice (no hay un "✓" que verificar). El bucle de arriba no lo caza porque el agente
no AFIRMA lo que dejó fuera. Antídoto obligatorio antes de aplicar el reemplazo:
1. `diff` viejo → nuevo y enumera TODO lo que el rebuild QUITÓ (secciones, punteros, datos, comandos,
   advertencias).
2. Clasifica cada cosa quitada: **basura temporal/obsoleta botada correctamente** (changelog fechado,
   estado viejo, duplicación) — pero verifica que su contenido vigente ya viva en su casa durable, no lo
   asumas — **vs. conocimiento REAL** (un gotcha, una corrección, un puntero, una advertencia destructiva,
   un dato que no se regenera) → NO se pierde: se preserva/reubica, o el rebuild se corrige/rechaza.
3. Cada `[[wikilink]]`/"ver memoria X"/"§Y" que el rebuild introduce debe EXISTIR (colgados = mentira
   nueva).

Caso real: un rebuild de agente de un `CLAUDE.md` botó —bien— un changelog fechado, PERO también soltó
una corrección que vivía SOLO en ese archivo (las memorias tenían el nombre viejo); sin el diff de
preservación se hubiera perdido la corrección.

**Qué NO hacer:** copiar el reporte del agente al usuario como si fuera tu verificación · declarar
"LISTO/quedó" con base en el "✓" del agente (verde de agente ≠ verificado) · poner al USUARIO a hacer el
QA de tu agente cuando podías leer el archivo y comprobarlo tú en medio segundo · construir la siguiente
fase encima de un entregable sin verificar su base.

## Hooks/tools que lo sostienen
- **`delegacion-gate`** (PreToolUse/Task) — consentimiento de costo por ventana de 5h (ver el flujo de gasto).
- **`delegacion-reporte`** (PostToolUse/Task) — tras cada subagente, recuerda registrar avance + limpiar worktree.
- **`limpiar-worktrees.sh`** — barre worktrees zombies (rama mergeada) y anota los vivos en la bitácora.
- **`proteger-arbol`** (PreToolUse/Bash) — avisa antes de un git DESTRUCTIVO (`reset --hard`/`checkout -f`/`rebase`/`branch -D`) que orfanaría commits sin pushear; antídoto al "agente reseteó HEAD en el árbol compartido".
- **`checkpoint`** (skill) + **`rehidratar-hilo`** (SessionStart) + **`aviso-contexto`** (watermark) — compactar sin perder el hilo del fan-out (el hook `precompact` se retiró: PreCompact no puede inyectar ni pedir acción).

## Anti-patrones
- ❌ Monitorear agentes "de niñera" y actualizar el estado a mano al final. → El auto-reporte es el default.

## Cuando SÍ hay que mirar: distinguir "trabajando" de "colgado"

No monitorear de niñera **no es no mirar nunca**. Un agente puede **entregar su reporte y quedarse colgado**,
y la interfaz lo seguirá mostrando activo — con su reloj corriendo y sus tokens subiendo. Pasó dos veces el
mismo día (sep-2026): uno con **1 h 41 m y 304 k tokens** en pantalla llevaba **14 horas sin escribir una
sola línea**, atascado en un append trivial; otro devolvió tres notificaciones seguidas diciendo *"esperaré
a que termine"* sin avanzar, con 460 k tokens y 542 llamadas encima.

**El reloj de pantalla es tiempo ACUMULADO, no señal de vida.** La señal fiable es **la última escritura de
su transcript**:

```bash
D=~/.claude/projects/<slug>/<session-id>/subagents
for f in "$D"/agent-*.jsonl; do
  printf '%-22s hace %6ds · %s\n' "$(basename "$f" .jsonl)" \
    "$(( $(date +%s) - $(stat -f %m "$f") ))" "$(du -h "$f" | cut -f1)"
done
```
Segundos = trabajando · minutos sin entregable = revisar · horas = zombi, **y se mata** (`TaskStop`). Sus
commits ya están en su rama: matarlo no pierde nada, y lo que seguía consumiendo era el bucle.

**Un agente agotado no se reanima: se releva.** Si ya hizo su trabajo y entra en bucle de espera, mátalo y
lanza uno FRESCO con el contexto de lo que falta. Reanudar conserva su contexto —barato— pero también su
estado degradado.

**No leas su transcript para averiguarlo**: son cientos de MB y te inundan el contexto. El `mtime` contesta
la pregunta en un comando.

- ❌ Escribir el mismo pendiente en estado-proyecto Y bitácora Y un backlog aparte. → Un dato, un lugar.
- ❌ Dejar worktrees zombies acumulándose. → `limpiar-worktrees.sh` al cerrar la ola.
- ❌ Asignar ítems NO autocontenidos (que dependen de otro agente en vuelo). → Serialízalos o únelos.
- ❌ Dejar que un agente mute/commitee en el árbol de trabajo COMPARTIDO (o corra `git reset`/`checkout`/`rebase` ahí). → Worktree AISLADO por agente, o lo hace el orquestador. Es lo que orfanó un commit en un caso real.
- ❌ Creer el reporte de un agente sin verificar el resultado real. → Comprueba read-only (git/archivo/compila) antes de marcar hecho; el agente pudo devolver un stub o "alucinar" trabajo en background.
- ❌ Publicar/deployar desde el worktree de un agente (no hereda gitignored → rompe el deploy). → Del clon principal tras `git pull`.
