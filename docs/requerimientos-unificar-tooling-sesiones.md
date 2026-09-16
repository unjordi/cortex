# Requerimientos — unificar el tooling de sesiones master (respaldar · checkpointear · mudar)

> **Qué es esto.** Una auditoría de PROCESO + ALGORITMO cuyo entregable es un documento de
> requerimientos, no un parche. Nada del tooling se tocó al escribirlo: solo se leyó.
> **Quién lo va a usar.** Los agentes constructores. Se basta solo: cada requerimiento trae su
> evidencia con `archivo:línea`, su criterio de aceptación verificable y su prioridad.
>
> **Procedencia, marcada en todo el documento:**
> `[MEDIDO: archivo:línea]` = lo leí/lo corrí · `[INFER]` = razonamiento mío · «entrecomillado» = cita de unjordi.
>
> **Fecha de medición:** 2026-09-16 (sellada con `date` de bash en esta máquina).
> **Rama:** `docs/requerimientos-unificar-tooling-sesiones` · base `develop` (`2a010a0`).
>
> **Diagramas** (en `docs/req-sesiones/`, ver §8): `00-hoy-divergencia-medida` ·
> `01-interaccion-propuesta` · `02-logica-hook-export-propuesta` · `03-logica-reubicar-propuesta`.

---

## 1 · Resumen ejecutivo — la respuesta a la tesis

La tesis de unjordi: «*el checkpoint es una mudanza chiquita, y el mecanismo de respaldar master es
literalmente la misma mudanza pero sin aplicar*».

1. **«Respaldar = mudar sin aplicar» SE SOSTIENE, y con la evidencia más dura posible:** el hook de
   respaldo y la mudanza **ya invocan el MISMO motor con los MISMOS flags**
   (`node session-export.js <id> --repo <tmp> --name <título> --force`) [MEDIDO:
   `brain/hooks/exportar-sesion-master.sh:141` y `brain/skills/reubicar-master/reubicar-master.sh:S3`].
   Lo que divergió no es el motor: es **el bash alrededor del motor**.
2. **«El checkpoint es una mudanza chiquita» NO se sostiene.** `checkpoint-mecanico.sh` tiene **0**
   menciones de `masters.json`, `.jsonl`, `slug` y `CLAUDE_SESSIONS_DRIVE` [MEDIDO, conteo en §3.1];
   no es master-scoped, no registra nada y su salida va al `.claude/memory/` del repo, no a la carpeta
   de sesiones. Lo que SÍ comparte con el hook de respaldo es el **envoltorio de hook**
   (stdin→guard→lock por-sid→`nohup … &`→escritura atómica), que su propia cabecera declara copiado:
   «*usa el MISMO patrón ya probado*» [MEDIDO: `brain/hooks/checkpoint-mecanico.sh:7-8`].
   ⇒ **son el mismo HOOK, no la misma pipeline.**
3. **Por eso el factoring correcto son DOS libs, no una** (§2): `lib-sesiones.sh` (el dominio) y
   `lib-hook.sh` (el envoltorio). Meterlas en una sola reproduce el error de creer que checkpoint
   pertenece al subsistema de sesiones.
4. **La pregunta central del encargo tiene respuesta MEDIDA, y no es ninguna de las tres que se
   ofrecían.** `session-lib.js` no es inalcanzable por falta de funciones: **no es ejecutable
   (`-rw-r--r--`), no tiene shebang y solo expone `module.exports`** [MEDIDO: `ls -la bin/session-lib.js`
   + `head -1`]. Desde bash solo se alcanza con `node -e '…'` inline — y **reubicar-master YA lo hace 13
   veces** mientras el hook lo hace 0 [MEDIDO: `grep -c session-lib`]. El hook no lo hace porque su
   fast-path de `Stop` corre **en cada turno de cada sesión** y no puede pagar el arranque de node.
   ⇒ El requerimiento no es «lib bash nueva» *o* «CLI»: es **las dos, partidas por el hot path** (R-1/R-7).
5. **Hay una contradicción CONFIRMADA y ya MATERIALIZADA, más dos que el encargo no traía** (§3.2):
   la política del Drive vacío, el lock de export con dos caducidades, y el `target` de `masters.json`
   escrito con el cwd crudo. Las tres están en producción en esta máquina, medidas, hoy.

---

## 2 · El modelo unificado — la pipeline común y sus puntos de parametrización

Ocho fases. Cada consumidor recorre un subconjunto y **se detiene en un punto distinto**; la política
de falla es un **parámetro de la fase**, no una propiedad de la lib.

| Fase | Qué hace | 🔔 respaldo (hook) | 🗂️ checkpoint | 💡 mudanza (reubicar) |
|---|---|---|---|---|
| **P0** RESOLVER CONTEXTO | sid, transcript, cwd, título | lo **ENTREGA el harness** (stdin) | lo **ENTREGA el harness** | lo **BUSCA** (`find` sobre todos los slugs) y el nº de copias **es un gate** |
| **P1** RESOLVER DESTINO | la carpeta de sesiones | degrada en silencio + `mkdir -p` | **no aplica** | aborta si está vacía |
| **P2** ¿APLICA? | ¿es master? | sufijo `-master` o `masters.json` | **no filtra** (cualquier repo con `.claude/memory`) | lo nombra el humano + valida el sufijo |
| **P3** CONCURRENCIA | locks, debounce, quiescencia | debounce 20 min + lock 30 min | lock 10 min | G-SELF-MOVE · G-QUIESCE · G-LIVENESS · lock de export |
| **P4** RESPALDAR | gzip + meta | **aquí TERMINA** (detached) | **no respalda** | S3 export-first (síncrono, abortivo) |
| **P5** APLICAR | mover slug, reescribir cwd, depositar cerebro | **no existe** | extrae andamio (otro destino) | S4 + S4-2c + S5 |
| **P6** REGISTRAR | `masters.json` + alias | upsert parcial | **no registra** | upsert + alias + aserciones |
| **P7** VERIFICAR | postcondiciones | `gzip -t`, fail-open | nada | `_postcondiciones`, fail-closed |

**Puntos de parametrización (lo que la lib recibe, no lo que decide):**

- `MODO_FALLA` ∈ {`abierto`, `cerrado`} — **no se unifica, se parametriza.** Un hook que corre en cada
  turno *debe* ser fail-open; una mutación irreversible *debe* ser fail-closed. [INFER] Querer una sola
  política aquí sería el error.
- `RUIDO` ∈ {`silencioso`, `verboso`} — ortogonal a lo anterior.
- `CADUCIDAD_LOCK` (segundos) — **un solo mecanismo, un valor por llamador** (R-4).
- `EXIGENCIA_DESTINO` ∈ {`requerido`} — **aquí SÍ se unifica**, y es el corazón de D-1 (§5).

### 2.1 · Dónde la analogía se ROMPE (y por qué importa)

- **P0 es asimétrico e irreducible.** El hook recibe `transcript_path`; la mudanza debe encontrarlo.
  [INFER] Forzar al hook a pasar por `findSession` lo haría más lento **y podría elegir un archivo
  distinto del que el harness acaba de escribir**. ⇒ `findSession` se queda en JS y el contrato
  compartido es «*una ruta de transcript*», no «*una forma de encontrarla*».
- **P1 no existe para checkpoint** y **P5 no existe para el respaldo.** La tesis de unjordi describe
  exactamente esa segunda ausencia, y es correcta.
- **El fail-open del hook no es «la versión relajada» del fail-closed de la mudanza.** Son respuestas a
  preguntas distintas. La ÚNICA divergencia que es un **bug** y no una política es P1, porque ahí las
  dos respuestas no difieren en *cuánto se quejan* sino en **DÓNDE van los bytes** — y un fail-open que
  escribe en otro sitio no es una degradación, es **otra operación** [INFER, apoyado en la evidencia de §3.2.1].

---

## 3 · La evidencia medida

### 3.1 · Los conteos (verificados hoy; corrijo dos cifras del encargo)

| concepto | `exportar-sesion-master.sh` | `reubicar-master.sh` | `checkpoint-mecanico.sh` |
|---|---|---|---|
| `masters.json` | 10 | 23 | **0** |
| `customTitle` | 2 | 2 | 0 |
| `transcript` | 8 | 24 | 7 |
| `.jsonl` | 2 | **29** | **0** |
| `CLAUDE_SESSIONS_DRIVE` | 4 | 6 | **0** |
| `slug` | **0** | **46** | **0** |
| `session-lib` | **0** | **13** | 0 |
| **líneas** | 191 | **1331** | 88 |

**Correcciones al encargo:** `reubicar-master.sh` mide **1331 líneas / 90,912 bytes**, no 1035 líneas /
70 KB; `.jsonl` en reubicar son 29, no 28. El resto de las cifras del encargo se confirma.

**Las dos filas que más dicen** [INFER]: `slug` 0-vs-46 y `session-lib` 0-vs-13. El hook **nunca deriva
un slug** (no lo necesita: el harness le da la ruta) y **nunca toca la lib**. La mudanza hace las dos
cosas constantemente. Es la medida exacta de dónde la analogía se rompe (§2.1) y de dónde ya existe el
puente bash↔JS que hay que formalizar.

### 3.2 · Las contradicciones, medidas en esta máquina

#### 3.2.1 · La política del Drive vacío — **ya OCURRIÓ, no es hipotética**

- hook: `DRIVE="${CLAUDE_SESSIONS_DRIVE:-$HOME/.claude-sessions}"` + `mkdir -p` [MEDIDO:
  `brain/hooks/exportar-sesion-master.sh:59-60`] ⇒ **degrada en silencio y CREA el destino alterno**.
- `seed.sh`: mismo default pero **aborta** si no existe [MEDIDO: `brain/sesiones-master/seed.sh:27-29`].
- `reubicar-master`: **sin default**, aborta [MEDIDO: `reubicar-master.sh:491` y `:621-627`], con la razón
  textual «*un default que apunta a la ruta de OTRA máquina no ayuda, miente*».

⇒ **Son TRES políticas, no dos.** Y el propio `reubicar-master` documenta la causa raíz: la variable
vive en el bloque `env` de `~/.claude/settings.json` [MEDIDO, verificado: `jq '.env' ~/.claude/settings.json`
→ `"CLAUDE_SESSIONS_DRIVE": "/Users/unjordi/Mi unidad/claude-sessions"`], así que **en un shell plano está
vacía** — el operador y el mecanismo pueden apuntar a sitios distintos sin que nada lo note.

**PRUEBA DE QUE PASÓ** [MEDIDO]: `~/.claude-sessions/` existe y contiene **un respaldo real**:

```
761c82d9-….jsonl.gz   21,668,971 bytes   2026-08-05
   meta: exportedAt 2026-08-05T17:53:40Z · host "MacBook-Pro-de-unjordi.local" · 15,791 líneas
vs. la copia del Drive del MISMO id:
   meta: exportedAt 2026-09-09T20:38:15Z · host "Mac"           · 38,677 líneas
```

El respaldo de `claude-brain-master` (el master que el plan de mudanza va a mover) **se bifurcó**: una
rama quedó en una carpeta oculta que `seed.sh`, tal como está hoy, **nunca lee**. En ESTE caso no hubo
pérdida porque la copia del Drive es un superconjunto posterior — pero el modo de falla está confirmado
en producción, y fue **mudo durante seis semanas**.

#### 3.2.2 · El lock de export tiene DOS caducidades — y hay un fantasma bloqueando HOY

- hook: un `.export-<sid>.lock` de **más de 30 min se recicla** (se ignora y se sigue) [MEDIDO:
  `brain/hooks/exportar-sesion-master.sh:128-135`].
- mudanza: `[ -f "$DRIVE/.export-$ID.lock" ] && _abort "BLOQUEO G-LIVENESS: auto-export detached en
  vuelo"` — **sin mirar la edad** [MEDIDO: `reubicar-master.sh`, bloque G-LIVENESS del handoff].

**EVIDENCIA VIVA** [MEDIDO, `ls -la "$CLAUDE_SESSIONS_DRIVE"`]:
`.export-c6330bed-28ff-4c57-b23a-8bc36035ebab.lock`, **0 bytes, 2026-09-13** — tres días de antigüedad.
Ese id es `databases-master`. ⇒ **Hoy mismo, una mudanza de `databases-master` está bloqueada
permanentemente por un lock que el hook ya considera basura.** El gate falla cerrado sobre un fantasma.

#### 3.2.3 · El `target` de `masters.json` se escribe con el cwd CRUDO

El hook hace `target="${cwd#"$HOME"/}"` sin validar que sea un repo [MEDIDO:
`brain/hooks/exportar-sesion-master.sh:161`]. Resultado en el `masters.json` real [MEDIDO]:

| id | name | target escrito |
|---|---|---|
| `fc94c4e1` | claudio-master | `code/plantilladotnet/.claude/memory` ← **subdirectorio** |
| `9cfeed6b` | games-master | `…/Juegos/.claude/memory` ← **subdirectorio** |
| `19590b44` | reverse-engineering-master | `code/potenciaDatabases/.claude/worktrees/integracion-ronda1` ← **worktree efímero** |
| `2622f45e` | rig-master | `rig-master` ← **ni siquiera es una ruta** |

`seed.sh` consume `target` como ruta relativa a `$HOME` para derivar el slug local ⇒ esos cuatro
masters se sembrarían a un cwd que nadie va a tener [INFER, derivado de `seed.sh::resolve_target`].
Esto es la arista **[ALTO] #3** del backlog, pero **peor de lo catalogado**: la arista decía que un
master movido *conserva el target viejo*; la medición muestra que además **escribe targets nuevos que
son inválidos por construcción**.

#### 3.2.4 · La regla «¿es master?» está documentada en un lado e implementada en dos

`reubicar-master.sh:611-618` dice textualmente «*El hook exportar-sesion-master.sh decide si una sesión
es master leyendo el customTitle del transcript y EXIGE el sufijo `-master`*» — y a renglón seguido
**vuelve a implementar la comprobación** [MEDIDO]. Acoplamiento documentado con implementación duplicada:
**cero líneas compartidas** entre los dos.

#### 3.2.5 · Doc que miente (cuatro hallazgos, todos medidos)

1. **Las copias del Drive divergieron.** `exportar-sesion-master.sh`, `install-hook.sh` y `seed.sh`
   viven también en `$CLAUDE_SESSIONS_DRIVE`, fechados **2026-07-26**, y **los tres difieren** de los del
   repo [MEDIDO: `diff` de los tres]. El del Drive aún se autodescribe «*hook PERSONAL de unjordi (NO va
   en el claude-brain público)*»; el `install-hook.sh` del Drive aún trae el `--uninstall` **retirado**;
   el `seed.sh` del Drive aún busca `~/.claude-brain` (nombre viejo) y se autolocaliza con `$(dirname $0)`.
2. **`masters.json` declara canónica la copia equivocada.** Su campo `note` dice: «*hook PERSONAL
   'exportar-sesion-master.sh' (canónico en esta carpeta de Drive, no en el brain público)*» [MEDIDO].
   Falso desde que el hook es tier `global` del MANIFEST [MEDIDO: `brain/hooks/MANIFEST:80`].
3. **`checkpoint-mecanico` está declarado y AUSENTE.** MANIFEST tier `global`
   [MEDIDO: `brain/hooks/MANIFEST:81`], el árbol del README lo lista como GLOBAL (se ve en la leyenda de
   los cuatro diagramas) — y en esta máquina **no está cableado** (`grep -c checkpoint-mecanico
   ~/.claude/settings.json` → **0**) ni existe `~/.claude/hooks/checkpoint-mecanico.sh` [MEDIDO].
   El único hook de `PreCompact` cableado es el de export. ⇒ **nunca ha corrido aquí.**
4. **Cero man-pages para la capa bash.** `docs/man/` tiene 35 páginas y cubre **toda** la capa JS
   (`session-export`, `session-import`, `session-move`, `claude-session`, `checkpoint-mecanico`) y
   **ninguna** de la capa bash: no hay `exportar-sesion-master.md`, ni `seed.md`, ni
   `reubicar-master.md` [MEDIDO: `ls docs/man/`]. [INFER] Es el mismo patrón que la duplicación: la capa
   JS es el sustrato cuidado y documentado; la bash es el territorio sin mapa.

#### 3.2.6 · Estado del registro compartido

`masters.json` tiene **18 entradas** con **5 nombres repetidos** (`claude-brain-master` ×2,
`claude-brain-cachy-master` ×2, `games-master` ×3, `databases-master` ×2, `claudio-master` ×2) [MEDIDO].
El propio skill ya lo trata como un hecho de diseño («*el nombre NO identifica*», gate `G-ID`), así que
**no es un bug** — pero es el contexto que hace R-13 una decisión y no una limpieza obvia.

---

## 4 · Requerimientos

> Cada uno: enunciado · **por qué** (evidencia con `archivo:línea`) · **criterio de aceptación
> verificable** · prioridad. Un requerimiento sin criterio de aceptación no es un requerimiento.
> Los criterios están redactados para cumplir la norma dura del repo: **miden el EFECTO, no el andamio**,
> y **cada test nuevo debe FALLAR contra el código de hoy** (§7).

### R-1 · UNA sola resolución de la carpeta de sesiones — `lib-sesiones.sh :: sesiones_dir` · **ALTA**

**Enunciado.** Se crea `brain/hooks/lib-sesiones.sh` con la función `sesiones_dir`, y los **cuatro**
consumidores (`exportar-sesion-master.sh`, `seed.sh`, `reubicar-master.sh` y su preludio) la llaman en
vez de resolverla cada uno. La política concreta la decide unjordi en **D-1**; el requerimiento es que
haya **una sola implementación**, sea cual sea la política.

**Por qué.** Tres políticas incompatibles hoy [MEDIDO: hook `:59-60` · seed `:27-29` · reubicar `:491,:621-627`],
y la degradación silenciosa **ya ocurrió** (§3.2.1: respaldo bifurcado desde 2026-08-05, mudo 6 semanas).

**Aceptación.**
1. `grep -c 'CLAUDE_SESSIONS_DRIVE' ` sobre los tres consumidores devuelve **0 en los tres**: la variable
   solo se nombra dentro de `lib-sesiones.sh`.
2. Test **T-1** (§7): en un `HOME` de laboratorio sin la variable, el hook y `reubicar-master --dry`
   **toman la misma decisión** sobre la misma carpeta. Hoy divergen ⇒ el test es rojo contra el código actual.
3. Test **T-1b** (dirección positiva): con la variable apuntando a una carpeta válida, el hook **sí**
   exporta ahí. (Sin esta mitad, R-1 se podría «aprobar» con una función que siempre rehúsa.)

### R-2 · `masters.json` tiene UN solo escritor: `bin/session-registry.js` · **ALTA**

**Enunciado.** Se crea `bin/session-registry.js` (ejecutable, con shebang, con man-page) que expone
`masters get|upsert|list`, `slug <cwd>`, `alias get|set`, `title <transcript>`. Toma el lock, hace
read-modify-write atómico y **re-lee para aseverar**. El hook y `reubicar-master` lo invocan; ninguno de
los dos vuelve a escribir el archivo por su cuenta.

**Por qué.** Hoy hay dos implementaciones del mismo upsert: el `node -e` embebido del hook
[MEDIDO: `exportar-sesion-master.sh:174-187`] y el `jq` del handoff [MEDIDO: `reubicar-master.sh`, «S4 paso 3»],
con dos disciplinas de lock escritas por separado (aunque coincidan en el reciclado a 5 min).
`masters.json` es un archivo **en un Drive compartido entre máquinas**: dos escritores es dos veces la
superficie de un lost-update.

**Aceptación.**
1. `grep -c 'masters' ` en el hook y en reubicar solo encuentra **llamadas al CLI**, cero `jq`/`node -e`
   que escriban el archivo.
2. Test **T-2**: dos upserts concurrentes sobre ids distintos → ambos presentes al final (no lost-update).
3. Test **T-2b** (fail-open del hook): con el lock tomado por otro proceso, el hook **no espera y sale 0**;
   el upsert se salta. El CLI reporta `{ok:false}` y el hook lo ignora.

### R-3 · El `target` se NORMALIZA a la raíz del repo, o no se escribe · **ALTA**

**Enunciado.** `session-registry masters upsert` normaliza el cwd recibido a la raíz del repo
(`git rev-parse --show-toplevel`) antes de escribir `target`. Si el cwd no resuelve a un repo, o resuelve
a un worktree efímero, **conserva el target anterior** y lo anota; **nunca** escribe un target que
`seed.sh` no podría sembrar.

**Por qué.** [MEDIDO, §3.2.3] cuatro entradas inválidas en el `masters.json` real de esta máquina, dos de
ellas apuntando a `.claude/memory` y una a un worktree. Cubre y **amplía** la arista [ALTO] #3 del backlog.

**Aceptación.**
1. Test **T-3** (rojo hoy): se dispara el hook con `cwd = <repo>/.claude/memory` sobre un master
   registrado → `target` queda en `<repo>`. Hoy queda en `<repo>/.claude/memory`.
2. Test **T-3b** (dirección positiva, obligatoria): `cwd = <repo>` → `target` **es** `<repo>`. Sin esta
   mitad nace el falso positivo de una normalización que rechaza todo.
3. Test **T-3c**: `cwd` fuera de todo repo → el `target` previo **sobrevive intacto** (no se pisa con basura
   ni se borra).

### R-4 · UNA caducidad de lock, y la mudanza la respeta · **ALTA**

**Enunciado.** `lib-sesiones.sh` expone `sesiones_lock_tomar` / `sesiones_lock_vigente` /
`sesiones_lock_soltar` con la caducidad como parámetro. `reubicar-master` sustituye su
`[ -f "$DRIVE/.export-$ID.lock" ] && _abort` por `sesiones_lock_vigente` ⇒ un lock caduco deja de bloquear.

**Por qué.** [MEDIDO, §3.2.2] el hook recicla a 30 min, la mudanza bloquea a cualquier edad — y **hay un
lock huérfano de 3 días en el Drive ahora mismo** bloqueando de facto la mudanza de `databases-master`.

**Aceptación.**
1. Test **T-4** (rojo hoy): con un `.export-<id>.lock` de mtime 2 h, `reubicar-master.sh --dry` **no
   bloquea**. Hoy bloquea.
2. Test **T-4b** (dirección positiva): con un lock de mtime 1 min, **sigue bloqueando**. El gate no se
   desarma, se afina.
3. El lock huérfano vivo (`.export-c6330bed-….lock`) se retira como parte del despliegue, y queda anotado.

### R-5 · La regla «¿es master?» vive en un solo lugar · **MEDIA**

**Enunciado.** `lib-sesiones.sh :: sesiones_es_master <transcript> <masters.json> <sid>` concentra la
regla (sufijo `-master` en el `customTitle` vigente + presencia en `masters.json`). El preludio de
`reubicar-master` la **llama** en vez de re-implementarla, y su comentario pasa de describir a otro
componente a describir la lib que ambos usan.

**Por qué.** [MEDIDO, §3.2.4] `reubicar-master.sh:611-618` documenta el comportamiento del hook y lo
duplica. Un cambio de convención (p. ej. aceptar otro sufijo) hoy exige acordarse de dos sitios, y uno de
ellos es un texto que se cree actualizado.

**Aceptación.**
1. Test **T-5** (las dos direcciones, contra la MISMA función, llamada desde un caller con forma de hook
   y otro con forma de mudanza): `foo-master` → elegible; `foo-masterx`, `foo`, `master-foo` → **no**
   elegibles; sid ya presente en `masters.json` con título vacío → elegible.
2. `grep -c 'master)' ` en el preludio de reubicar → 0 comprobaciones propias del sufijo.

### R-6 · El envoltorio de hook se extrae a `lib-hook.sh` — y NO se mezcla con el de sesiones · **MEDIA**

**Enunciado.** `brain/hooks/lib-hook.sh` concentra `hook_leer_stdin` (jq con el fallback `sed` que el hook
ya trae), `hook_brain_dir` (el `resolve_brain_dir` que hoy ambos copian), `hook_lock_sid` (con reciclado) y
`hook_detached` (el `nohup … &` con centinela anti-recursión). La consumen `exportar-sesion-master.sh` y
`checkpoint-mecanico.sh`. **Es una lib DISTINTA de `lib-sesiones.sh`.**

**Por qué.** [MEDIDO] los bloques `:34-51` y `:128-152` del hook de export y `:36-45` y `:62-86` del
checkpoint son el mismo patrón, y el segundo lo declara copiado en su cabecera. Que sean dos libs y no una
es lo que impide re-cometer el error de tratar a checkpoint como parte del subsistema de sesiones
(§1.2, conteos de §3.1).

**Aceptación.**
1. Los dos hooks quedan por debajo de **60 líneas propias** cada uno (hoy 191 y 88); el resto es la lib.
2. Test **T-6** (invariante del hot path, §7): con un sid **no** registrado y evento `Stop`, el hook
   **no arranca ni un proceso `node`** (medido con un shim de `node` en el `PATH` que registra invocaciones).
   Hoy es cierto por construcción; el test existe para que la refactorización no lo rompa.
3. `lib-hook.sh` no menciona `masters.json` ni `CLAUDE_SESSIONS_DRIVE` (0 ocurrencias): la separación es
   verificable, no una intención.

### R-7 · La frontera bash↔JS se cruza SOLO por un CLI con contrato · **ALTA**

**Enunciado.** `session-lib.js` gana un front ejecutable (`session-registry.js`, R-2). Los **13** `node -e`
inline de `reubicar-master` se sustituyen por llamadas a él. Se prohíbe el `node -e` inline en hooks y
skills del cerebro; la prohibición se verifica en `test-brain.sh`.

**Por qué.** [MEDIDO] `session-lib.js` es `-rw-r--r--`, sin shebang, solo `module.exports` ⇒ desde bash solo
se alcanza por `node -e`. Un `node -e` inline **no tiene man-page, no tiene test propio y no falla con un
contrato**; y en este skill en particular el candado del handoff **lo embebe TEXTUALMENTE**
[MEDIDO: `reubicar-master.sh:157-167`], así que cada `node -e` se **congela con sus bugs** dentro de cada
handoff generado.

**Aceptación.**
1. `bin/session-registry.js` es ejecutable, tiene shebang, y `docs/man/session-registry.md` existe.
2. `grep -c "node -e" brain/skills/reubicar-master/reubicar-master.sh` → **0**.
3. Test **T-7**: cada subcomando del CLI devuelve JSON por stdout y `{ok:false,error}` + exit≠0 ante
   entrada inválida — el mismo contrato que `session-export/move/import` ya cumplen.

### R-8 · El respaldo se verifica por CONTENIDO en los dos consumidores · **MEDIA**

**Enunciado.** La verificación del `.gz` es **una sola función** y comprueba **las dos cosas**: `gzip -t`
(integridad) **y** renglones ≥ los del origen (cobertura).

**Por qué.** [MEDIDO] el hook solo hace `gzip -t` (`:146`); la mudanza solo cuenta renglones («S3»,
`_lgz >= _lsrc`). Cada uno caza **una mitad** de la clase: un `.gz` íntegro pero de una sesión más corta
pasa el test del hook; un `.gz` que cubre las líneas pero está truncado en el último bloque pasa el de S3.

**Aceptación.** Test **T-8**, cuatro casos, cada uno rojo contra al menos uno de los dos consumidores de
hoy: gz válido y completo → acepta · gz válido pero corto → rechaza · gz corrupto → rechaza · gz ausente →
rechaza. Y en el hook, «rechaza» significa **conservar el respaldo anterior**, no borrarlo.

### R-9 · Las copias del Drive se retiran o se declaran derivadas · **ALTA**

**Enunciado.** Se resuelve el estado de `exportar-sesion-master.sh`, `install-hook.sh` y `seed.sh` dentro
de `$CLAUDE_SESSIONS_DRIVE` (opción en **D-4**), y el campo `note` de `masters.json` se corrige para dejar
de declarar canónica la copia del Drive.

**Por qué.** [MEDIDO, §3.2.5] las tres copias son del 2026-07-26 y **difieren** de las del repo; una trae
un `--uninstall` retirado y otra busca `~/.claude-brain`. El `note` de `masters.json` afirma que el hook es
«canónico en esta carpeta de Drive». Es doc que miente en el artefacto que **sincroniza entre máquinas**:
la máquina que instale desde ahí instalará el hook de julio.

**Aceptación.**
1. En el Drive no queda ningún `.sh` del cerebro, **o** cada uno lleva una cabecera de una línea que dice
   de qué commit del repo deriva y que no se edita ahí.
2. `masters.json.note` ya no dice «canónico en esta carpeta de Drive»; nombra al MANIFEST.
3. Test **T-9**: un script del repo compara las copias del Drive (si la opción elegida las conserva) con las
   del repo y falla si divergen. Sin este test, R-9 se re-abre solo en tres semanas.

### R-10 · `checkpoint-mecanico` se instala o se le pone lápida — hoy está declarado y ausente · **MEDIA**

**Enunciado.** Se resuelve la contradicción entre el MANIFEST (tier `global`), el árbol del README (lo
lista) y la realidad de la máquina (**no cableado, no instalado**). Decisión en **D-5**.

**Por qué.** [MEDIDO, §3.2.5 punto 3] `grep -c checkpoint-mecanico ~/.claude/settings.json` → **0**;
`~/.claude/hooks/checkpoint-mecanico.sh` no existe; el único `PreCompact` cableado es el de export.
[INFER] Esto es exactamente el hueco «`install-brain.sh` NO PODA» del backlog, pero **en la dirección
contraria**: no es un hook retirado que sobrevive, es un hook declarado que **nunca llegó**. Un mecanismo
que el cerebro anuncia y no corre es peor que no tenerlo: el skill `checkpoint` cuenta con su andamio.

**Aceptación.** Tras el despliegue, `grep -c checkpoint-mecanico ~/.claude/settings.json` ≥ 1 **y**
`~/.claude/hooks/checkpoint-mecanico.sh` existe — **o** el MANIFEST lo marca `retirado` con su lápida y el
árbol del README deja de listarlo. Las dos vías son aceptables; **el estado actual no lo es.**

### R-11 · Man-pages para la capa bash · **MEDIA**

**Enunciado.** Se crean `docs/man/exportar-sesion-master.md`, `docs/man/seed.md`,
`docs/man/reubicar-master.md` y `docs/man/lib-sesiones.md`, con la misma plantilla que las 35 existentes.

**Por qué.** [MEDIDO, §3.2.5 punto 4] 35 man-pages, cobertura **completa** de la capa JS y **cero** de la
bash. [INFER] La asimetría de documentación es la misma que la de duplicación, y probablemente su causa:
lo que no tiene contrato escrito se re-implementa.

**Aceptación.** `ls docs/man/ | wc -l` ≥ 39, y cada página nueva declara: flags, variables de entorno,
código de salida, y **la política de falla** (abierto/cerrado) — que es justo lo que hoy nadie puede
consultar sin leer el código.

### R-12 · `brain/sesiones-master/README.md` deja de ser el doc personal de unjordi · **MEDIA**

**Enunciado.** Ese README se reescribe como doc del **mecanismo**; las rutas concretas de Drive, la tabla
de masters y los nombres de las máquinas salen a memoria personal per-máquina.

**Por qué.** [MEDIDO] su primera línea es «*claude-sessions — sesiones master de unjordi (sincronizadas por
Google Drive)*», y trae hardcodeadas `~/Mi unidad/claude-sessions` y
`/run/media/unjordi/SteamAndFiles/GoogleDrive/claude-sessions`, más una tabla de masters con nombres ya
obsoletos (`claude-brain-master` en vez de `cortex-master`). Contradice frontalmente el contrato que
`diseno-sync-sesiones.md` declara: «*el CANAL de transporte … es una preferencia PERSONAL de cada dev → NO
vive en el brain compartido*». Y `cortex` es un repo **PÚBLICO**.

**Aceptación.** `grep -cE 'Mi unidad|SteamAndFiles|unjordi' brain/sesiones-master/README.md` → **0**, y el
doc sigue explicando cómo configurar TU canal.

### R-13 · Sanear `masters.json` — **requiere decisión (D-6)** · **MEDIA**

**Enunciado.** Se corrigen los cuatro `target` inválidos de §3.2.3 y se resuelve qué hacer con las entradas
duplicadas por nombre.

**Por qué.** R-3 impide **nuevos** targets inválidos; no arregla los cuatro que ya están escritos, y
`seed.sh` los leería en la próxima máquina.

**Aceptación.** Todo `target` de `masters.json` resuelve a un directorio existente **o** está marcado
explícitamente como «máquina ajena». ⚠️ **Es una edición DESTRUCTIVA de un registro compartido entre
máquinas: no se ejecuta sin D-6.**

### R-14 · El handoff viejo del Drive se invalida o se declara · **MEDIA**

**Enunciado.** Se resuelve `handoff-761c82d9-….sh` (46,805 bytes, 2026-09-10) que está en el Drive, y se
endurece el sello `LIB_SHA_HORNEADO` para que un cambio **mayor** de la lib falle cerrado en vez de solo avisar.

**Por qué.** [MEDIDO] ese handoff **embebe textualmente el preludio viejo** (el candado lo exige así) e
invoca `$BIN/session-lib.js` **en tiempo de ejecución**. Tras la unificación, correrlo ejecutaría el guion
de ayer contra la lib de mañana; el sello detecta el cambio pero **solo AVISA, no bloquea**
[MEDIDO: `reubicar-master.sh`, bloque `LIB_SHA_AHORA != LIB_SHA_HORNEADO`]. Y es justamente el handoff del
master que el plan de mudanza va a mover.

**Aceptación.** El handoff viejo se borra o se renombra a `.obsoleto`, **y** existe un test que genera un
handoff, altera `session-lib.js`, y comprueba que el guion **rehúsa mutar** (hoy solo imprime un ⚠).

---

## 5 · Decisiones de POLÍTICA que exigen que unjordi elija

> Yo recomiendo; **él decide**. Ninguna de estas se ejecuta sin su respuesta.

### D-1 · `CLAUDE_SESSIONS_DRIVE` vacía: ¿degradar o abortar? *(la primera, por encargo)*

| opción | qué implica | costo |
|---|---|---|
| **(a)** los tres degradan a `~/.claude-sessions` | uniforme, nunca se pierde un respaldo | `masters.json` puede existir en dos sitios; `reubicar-master` operaría sobre una carpeta que en la otra máquina significa otra cosa — exactamente lo que su comentario dice que quiere evitar |
| **(b)** los tres abortan | honesto, cero ambigüedad | una máquina sin canal configurado queda **sin ningún respaldo**, y se pierde el beneficio declarado del default: «*sobrevive el cleanup de 30 días de Claude Code sin depender de ninguna nube*» |
| **(c) RECOMENDADA — una sola ubicación, resuelta al INSTALAR y escrita a disco** | el bootstrap resuelve la carpeta una vez y la deja en un archivo (p. ej. `~/.claude/sesiones-dir`). Todo la lee de ahí. Si falta, cada herramienta aplica su contrato: el hook **no exporta y deja una miga de pan**; la mudanza **aborta** | hay que tocar el bootstrap |

**Por qué (c)** [INFER]: la raíz medida no es «qué default poner», es que **la config vive donde solo el CLI
la lee** (bloque `env` de `settings.json`) ⇒ el shell plano y el hook ven cosas distintas. (c) mata la clase:
con una sola respuesta en disco, dos procesos **no pueden** discrepar. Y conserva lo bueno de (b) —nunca se
inventa una segunda ubicación en runtime— sin renunciar a respaldar en una máquina sin nube, porque ahí el
instalador **elige** `~/.claude-sessions` y lo deja escrito, que es distinto de adivinarlo cada turno.
Nota: (c) respeta la restricción #3 del encargo — el **canal** sigue siendo config personal por máquina;
lo que se unifica es **dónde se lee esa config**, no cuál es.

### D-2 · ¿La unificación puede tocar el hot path de `Stop`?

- (a) sí, todo por el CLI (más simple, una sola vía).
- **(b) RECOMENDADA:** no. El fast-path (`¿el sid está en `masters.json`?`) se queda en **bash puro**; node
  solo arranca cuando ya se decidió que hay trabajo.

**Por qué** [INFER]: ese `grep` a ~3 KB corre en **cada turno de cada sesión de la máquina**. Meterle un
arranque de node es un impuesto permanente sobre todo el trabajo, para ahorrar ~15 líneas de bash. R-6/T-6
convierte esto en un test para que la decisión no se erosione sola.

### D-3 · `target` de una sesión parada en un worktree o en un subdirectorio

- (a) guardar el cwd literal (hoy).
- **(b) RECOMENDADA:** normalizar a la raíz del repo; si no resuelve, **conservar el target anterior** y anotar.
- (c) refrescar el target **solo** en `SessionEnd`, nunca en `Stop`.

**Por qué (b)** [INFER]: `target` existe para que `seed.sh` sepa dónde sembrar en OTRA máquina. Un worktree
efímero o un `.claude/memory` no existen allá. (c) reduce la frecuencia del error pero no lo elimina.

### D-4 · Las tres copias del cerebro que viven en el Drive

- (a) borrarlas (el MANIFEST es la fuente).
- **(b) RECOMENDADA:** borrarlas **y** dejar en su lugar un `LEEME.txt` de tres líneas que diga dónde está
  la fuente y cómo instalar (`bootstrap.sh`).
- (c) conservarlas sincronizadas por un script + el test T-9.

**Por qué (b)** [INFER]: el valor de tenerlas ahí era arrancar una máquina nueva desde el Drive; un puntero
cumple lo mismo sin poder driftear. (c) mantiene vivo un mecanismo de sincronía que hay que mantener.
⚠️ **(a) y (b) borran archivos del Drive: son destructivas y no se ejecutan sin tu OK.**

### D-5 · `checkpoint-mecanico`: ¿instalar o lápida?

- **(a) RECOMENDADA:** instalarlo. El skill `checkpoint` ya cuenta con su andamio y el chart 05 del cerebro
  lo dibuja como parte del flujo de continuidad.
- (b) lápida (`retirado` en el MANIFEST + sale del README).

**Por qué (a)** [INFER]: está construido, probado y documentado con man-page; lo único que falta es el
cableado. Pero **es tu llamada**, porque instalarlo añade un hook que corre en cada `PreCompact` de cada
sesión — el mismo perfil de riesgo del hook de export.

### D-6 · Sanear `masters.json` (R-13)

- (a) no tocar; R-3 evita los nuevos y los viejos se corrigen cuando toque.
- **(b) RECOMENDADA:** corregir **solo** los cuatro `target` inválidos, **sin** tocar las entradas duplicadas.
- (c) además deduplicar por nombre.

**Por qué (b)** [INFER]: los targets inválidos son un defecto objetivo con un valor correcto identificable.
Las duplicaciones por nombre **no son un bug** — el skill ya asume que el nombre no identifica (gate `G-ID`),
y varias entradas son de la otra máquina. (c) es destructivo sobre un registro compartido y podría borrar la
única referencia a un master de Cachy.

### D-7 · Ritmo del despliegue

- (a) todo en un MR.
- **(b) RECOMENDADA:** dos tandas. **Tanda 1 (no toca el hot path):** R-4, R-3, R-9, R-10, R-11, R-12, R-14.
  **Tanda 2 (toca el hook):** R-1, R-2, R-5, R-6, R-7, R-8, y luego R-13.

**Por qué (b)** [INFER]: la tanda 1 arregla tres defectos medidos y en producción (el lock fantasma, los
targets inválidos, las copias stale) **sin tocar el código que corre en cada turno**. La tanda 2 es la
refactorización de verdad y merece su propio riesgo. Además respeta el orden 5→6 que ya acordaste: las dos
tandas caben antes de mudar el cortex-master.

---

## 6 · Riesgos de la migración

1. **🔴 El hook corre en CADA turno de CADA sesión. Un bug ahí es silencioso y global.** No hay salida por
   stderr que alguien vea, y el contrato es `exit 0` pase lo que pase. Un `source` de una lib inexistente,
   una función renombrada o un `set -u` mordiendo en un camino raro **rompen el respaldo de todos los
   masters sin que nadie se entere**. Mitigación: T-7 (el hook nunca falla ruidoso, en las dos direcciones)
   + T-6 (el hot path no arranca node) + la tanda 2 de D-7 en solitario + verificación **por artefacto** (que
   aparezca un `.gz` nuevo), no por «el script no se quejó».
2. **🔴 El candado de `reubicar-master` RECHAZARÁ los handoffs si el refactor toca el preludio sin actualizar
   sus listas.** `_SIMBOLOS_PRELUDIO` y `_MARCADORES` son listas explícitas
   [MEDIDO: `reubicar-master.sh:101-115`], y el propio script lo advierte: «*si un paso se retira A PROPÓSITO,
   su marcador sale de aquí en el MISMO commit*». Esto **no es un riesgo a evitar sino un gate a respetar**:
   cualquier símbolo que la lib absorba debe salir de `_SIMBOLOS_PRELUDIO` en el mismo commit.
3. **🟡 Un handoff viejo + una lib nueva.** §R-14: hay uno en el Drive ahora mismo; el sello solo avisa.
4. **🟡 El `masters.json` vive en un Drive sincronizado y la OTRA máquina no se actualiza a la vez.** Cachy
   correrá el hook viejo contra un `masters.json` que la Mac ya escribe con el formato nuevo. Mitigación:
   **el formato del archivo no cambia** en ningún requerimiento de este documento (solo cambian los valores
   que se escriben en `target`), y R-3 solo escribe targets *más* válidos. Verificarlo explícitamente antes
   de desplegar es parte del plan (§7, T-10).
5. **🟡 El lock de alias tiene un escritor que no pasa por la lib:** el widget de Plasma escribe
   `sesiones-alias.json` desde QML sin lock [MEDIDO: documentado en `reubicar-master.sh`, G-QUIESCE, §10 del
   skill]. R-7 no lo cubre; la aserción de «ningún alias ajeno se perdió» de `_postcondiciones` sigue siendo
   la única red. **No lo resuelvo aquí; lo dejo dicho** para que no se dé por cerrado con la unificación.
6. **🟠 Regresión de rendimiento invisible.** Si R-7 se aplica con celo y el fast-path acaba llamando al CLI,
   cada `Stop` de cada sesión paga un arranque de node. Es el riesgo que D-2 y T-6 existen para atajar.

---

## 7 · Plan de verificación

> Norma dura del repo, aplicada: **los tests miden si el código hace lo que DEBE hacer, no si su tooling está
> bien programado**, y **todo test nuevo debe FALLAR contra el código viejo**. Debajo, cada test dice contra
> qué es rojo hoy y qué efecto observable mide.

**Banco de pruebas.** `HOME` de laboratorio vía `CLAUDE_CONFIG_DIR` (la técnica que
`diseno-sync-sesiones.md` ya usa para verificar el motor), con un `masters.json` sembrado, un transcript
sintético y slugs falsos. Los tests viven en `brain/test-brain.sh`.

| test | mide (EFECTO) | rojo hoy contra | dirección inversa |
|---|---|---|---|
| **T-1** | con la carpeta sin resolver, hook y mudanza toman la **misma** decisión | hook degrada / mudanza aborta (§3.2.1) | **T-1b**: con carpeta válida, el `.gz` **aparece** ahí |
| **T-2** | dos upserts concurrentes → ambas entradas presentes | dos escritores independientes (R-2) | **T-2b**: con el lock tomado, el hook **sale 0** y se salta el registro |
| **T-3** | `cwd=<repo>/.claude/memory` → `target=<repo>` | hoy escribe el subdir (§3.2.3) | **T-3b**: `cwd=<repo>` → `target=<repo>` · **T-3c**: sin repo → target previo intacto |
| **T-4** | lock de 2 h **no** bloquea la mudanza | hoy bloquea a cualquier edad (§3.2.2) | **T-4b**: lock de 1 min **sí** bloquea |
| **T-5** | `foo-master` elegible; `foo-masterx`/`foo`/`master-foo` no | la regla está duplicada (§3.2.4) | incluida: las dos direcciones en el mismo test |
| **T-6** | `Stop` + sid no registrado → **0 procesos node** (shim en `PATH` que cuenta invocaciones) | verde hoy — **test de no-regresión**, se declara como tal | **T-6b**: sid registrado y debounce vencido → **sí** arranca node |
| **T-7** | el hook **nunca** sale ≠0: sin node, sin jq, `masters.json` corrupto, carpeta de solo lectura, transcript de 0 bytes | parcialmente verde — se declara qué casos son nuevos | **T-7b**: con todo bien, **sí** publica `.gz` + `.meta.json` |
| **T-8** | gz corto / corrupto / ausente → rechaza **conservando el anterior**; gz bueno → publica | cada consumidor caza media clase (R-8) | incluida |
| **T-9** | las copias del Drive (si D-4 las conserva) no divergen del repo | rojo hoy: las tres divergen (§3.2.5) | — |
| **T-10** | el `masters.json` que escribe el CLI nuevo lo **lee sin error** el `seed.sh`/hook **viejos** | compatibilidad hacia atrás con Cachy (riesgo 4) | — |

**Higiene obligatoria de cada test** (norma del repo, y el modo de falla más caro):
- **el setup se COMPRUEBA antes de aseverar.** Todo test que dependa de «hay un master registrado» verifica
  primero que lo hay. Un fixture que falla en silencio deja el aserto probando el caso vacío y **pasa siempre**.
- **cada test se corre contra el código VIEJO y debe salir ROJO** antes de aceptarse. La tabla dice cuáles
  son de no-regresión (T-6, parte de T-7): esos se declaran como tales y **no** se presentan como cobertura nueva.

**Verificación FUNCIONAL, no solo de suite** (lo que cierra el gate, no lo abre):
1. Tras desplegar, abrir una sesión master real, cerrar un turno y comprobar que **aparece un `.gz` nuevo y
   más grande** en la carpeta de sesiones, y que su `.meta.json` tiene el `exportedAt` de hoy.
2. Correr `reubicar-master.sh --dry` sobre `cortex-master` (761c82d9) y comprobar que el plan sale **sin
   avisos** — es el estreno real del tooling unificado, y es justo la mudanza que viene después.
3. **Nada de esto es LISTO** sin el QA de unjordi (norma dura del repo). Verde técnico ≠ LISTO.

---

## 8 · Los diagramas

En `docs/req-sesiones/` (fuera de `docs/flowcharts/` a propósito: ese árbol lo está editando otro agente, y
además su `.gitignore` es un catch-all que se traga los archivos nuevos). Cada uno incrusta la leyenda
canónica generada con `docs/flowcharts/gen-leyenda-arbol.sh --inject` desde el árbol del README
(CONVENCIONES §3/§7), y respeta la valencia de color de §2 (🔴 = DENY/bloqueo, 🚧 gris punteado = hueco).
Los cuatro compilan (`dot -Tsvg … -o /dev/null`, graphviz 15.0.0) y se versionan con su `.svg` (§8).

| archivo | qué muestra | etiqueta |
|---|---|---|
| `00-hoy-divergencia-medida.dot` | los 5 conceptos duplicados, con su `archivo:línea` y las 3 contradicciones medidas | **HOY** |
| `01-interaccion-propuesta.dot` | quién invoca a quién, la frontera bash↔JS, las dos libs nuevas y el CLI, qué toca cada artefacto y bajo qué lock | **PROPUESTO** |
| `02-logica-hook-export-propuesta.dot` | lógica interna del respaldo: fases P0–P7, las 6 salidas fail-open, el hot path | **PROPUESTO** |
| `03-logica-reubicar-propuesta.dot` | lógica interna de la mudanza: gates fail-closed, punto de no retorno, S7, el riesgo del candado | **PROPUESTO** |

**Trazabilidad R-n ↔ nodo** (si cambia uno, cambia el otro):
R-1 → `01::LSES`, `02::P1`, `03::P1` · R-2/R-3 → `01::CLI`, `02::P6`, `03::P6` · R-4 → `02::P3`, `03::P3` ·
R-5 → `02::P2`, `03::P2` · R-6 → `01::LHOOK` · R-7 → `01::CLI`, `03::P6` · R-8 → `02::V4`, `03::P4` ·
R-14 → `03::CAND`. La tesis y su límite viven en `02::NOTA` y `03::P5`.

---

## 9 · Límites y fuera de alcance

1. **El hueco `reubicar-master` ↔ `checkpoint`** (la mudanza co-ubica el hilo como
   `hilo-mental-actual.<nombre>.md` y el checkpoint nunca busca hermanos). **Fuera de alcance por decisión de
   unjordi**, citada en el encargo: «*no hemos implementado el mecanismo para que dos Claude compartan
   cerebro/repo, así que no es para este slice*». Queda anotado como límite conocido.
2. **El release a `main` está retenido a propósito.** Nada aquí propone liberar.
3. **El canal de transporte (Google Drive) es config personal por máquina** y ningún requerimiento lo mueve
   al brain. R-1/D-1 unifican **dónde se lee la config**, no cuál es; R-12 saca del brain público las rutas
   que hoy sí están hardcodeadas ahí, que es la dirección contraria.
4. **El widget de Plasma escribiendo `sesiones-alias.json` sin lock** (riesgo 5) queda **abierto y dicho**,
   no resuelto: tocar el widget es otro stack (QML) y otro ciclo de despliegue.
5. **Las otras tres aristas del backlog** ([ALTO] #2 freshness en `seed.sh --force`, [MEDIO] #1 tie-break en
   `findSession`, [BAJO] #4 poda de `session-move-backups`) **no se reabren aquí**: ya tienen ficha y rama
   (`fix/session-infra-aristas`). Este documento **solo** amplía la #3 (ver R-3, que mide más daño del
   catalogado).
6. **No decido QUÉ se hace.** Todo lo que me pareció que podía no valer la pena está en §5 como
   recomendación razonada con su alternativa — ninguna de esas decisiones es mía.

---

## 10 · Lo que este documento AGREGA al backlog vivo

Hallazgos que salieron de esta auditoría y **no estaban** catalogados. Van al backlog con severidad, no
quedan narrados aquí (norma: ningún hallazgo se queda solo en el documento):

| # | hallazgo | severidad | requerimiento |
|---|---|---|---|
| A | lock de export huérfano de 3 días bloqueando la mudanza de `databases-master` | **ALTO** | R-4 |
| B | `target` inválido en 4 entradas de `masters.json` (2 subdirs, 1 worktree, 1 no-ruta) | **ALTO** | R-3 / R-13 |
| C | las 3 copias del cerebro en el Drive divergieron (2026-07-26) y `masters.json.note` las declara canónicas | **ALTO** | R-9 |
| D | respaldo bifurcado en `~/.claude-sessions` desde 2026-08-05, mudo 6 semanas | **ALTO** | R-1 |
| E | `checkpoint-mecanico` declarado tier `global` y **ausente** de la máquina | **MEDIO** | R-10 |
| F | 0 man-pages para toda la capa bash del subsistema | **MEDIO** | R-11 |
| G | `brain/sesiones-master/README.md` es doc personal con rutas hardcodeadas en un repo público | **MEDIO** | R-12 |
| H | handoff de 2026-09-10 en el Drive con el preludio viejo embebido; el sello solo avisa | **MEDIO** | R-14 |
| I | `session-lib.js` no es ejecutable ni tiene shebang ⇒ la frontera bash↔JS solo se cruza por `node -e` | **MEDIO** | R-7 |

---

# 5-bis · LAS DECISIONES TOMADAS — unjordi, 2026-09-16

> Esta sección **gobierna** sobre las recomendaciones de §5. Donde una decisión contradice la
> recomendación, manda la decisión. Cada una lleva la cita textual que la origina.

## D-1 — RESUELTA POR ARRIBA: no se elige entre degradar y abortar; se construye una GUI de configuración

> *"Ya es hora de que le pongamos una pestaña de configuración al widget o que despliegue una interfaz
> nativa para que no quede tan apretado todo ahí, tú decide, pero ya tenemos muchas cosas que me gustaría
> ver ahí […] todo lo parametrizable por CLI que tú usas para operarlo deberían ser operable también por GUI."*

La recomendación (c) —resolver la ubicación al instalar y escribirla a disco— **sigue siendo el mecanismo
correcto** y se conserva como R-1. Lo que cambia es dónde vive la decisión de configuración: deja de ser
una variable de entorno que solo el CLI lee y pasa a ser **config editable por el usuario en una GUI**.

**Lo que unjordi quiere ver ahí** (su lista, verbatim en orden):
1. `CLAUDE_SESSIONS_DRIVE`
2. el token OAuth activo
3. un botón de `install-brain` para invocarlo desde ahí
4. el % de ventana de contexto global
5. ejecutar el respaldo de las sesiones master **a voluntad**
6. refrescar `masters.json`
7. **seleccionar qué sesiones master queremos** — *"luego el claude-cli las duplica por torpe y no queremos eso"*

**El principio que lo gobierna, y que es más grande que esta lista:** *todo lo parametrizable por CLI
debe ser operable por GUI.*

**Decisión de forma (delegada a Claude, tomada con medición):** **ventana de Preferencias propia y nativa
por plataforma**, invocada desde el popover — NO una pestaña dentro del popover. Las tres razones:
- El popover/popup es **efímero** (se cierra al perder el foco). Un formulario que se cierra a media
  edición, y operaciones largas como un respaldo o un `install-brain`, no caben ahí. Es exactamente el
  *"no quede tan apretado"* llevado a su causa.
- **Ya hay precedente** en el código: `windows/src/Cortex/RenameDialog.cs` es una ventana secundaria.
- En KDE, un plasmoide tiene su **mecanismo estándar de configuración** propio; forzar una pestaña dentro
  del popover pelearía con la plataforma en vez de usarla.

**Decisión de arquitectura (la que evita triplicar el trabajo):** las tres GUIs hoy son implementaciones
PARALELAS —`main.qml` 3493 líneas · `PopoverView.swift` 1662 · `PopupForm.cs` 2239 [MEDIDO]—. La GUI de
configuración **no reimplementa lógica: invoca los mismos comandos del CLI**. Así cada plataforma aporta
solo el formulario, y el principio de unjordi se cumple por construcción en vez de por disciplina. Es la
misma frontera que R-7 ya pide para bash↔JS.

**Qué NO decide esto:** el canal sigue siendo config personal por máquina (restricción #3 del encargo).
La GUI hace que esa config sea **visible y editable**, no la vuelve compartida.

## D-2 — SIN DECIDIR (la pregunta estaba mal formulada)

> *"no tengo idea de a qué te refieres con «hot path de Stop», así que no puedo decidir."*

Pendiente de re-plantear en lenguaje llano. **No se toma por default**: hasta que la decisión sea suya,
R-6/T-6 se implementan conservando el comportamiento actual.

## D-3 — ANULADA: la pregunta no dijo de qué hablaba, y se contestó sobre otra cosa

> *"SOBRE D-3: estamos hablando de mudanza/checkpoint o de los guards? porque yo entendí/asumí que
> hablábamos de los guards y respondí en función de eso!"*

**La pregunta era sobre el campo `target` de `masters.json`** — una RUTA DE DIRECTORIO que le dice a
`seed.sh` dónde sembrar la sesión en otra máquina. No tiene nada que ver con ramas ni con los guards.
La respuesta se dio creyendo que el tema eran los guards, así que **NO es una decisión sobre D-3** y se
retira como tal. D-3 queda **SIN DECIDIR**, pendiente de re-plantearse con su contexto explícito.

Culpa del planteamiento: la pregunta llegó en una lista de siete junto a decisiones de otros subsistemas,
sin decir de cuál era cada una.

### Pero lo que respondió es un CRITERIO VÁLIDO, y su lugar son los guards

> *"si la sesión es un agente parado en un worktree, el default es su upstream inmediato: la rama de la
> que lo forkearon, que IDEALMENTE nunca debe ser main, pero puede ser una minidevelop y si el default es
> main SIN MEDIR, entonces va a estar arrojando falsos positivos por doquier"*

Esto se guarda como criterio de diseño **de los guards de git**, donde aplica literalmente y donde hay un
hallazgo abierto que lo encarna: el auditor semántico midió que el piso determinista de `main` se apaga
cuando el LLM escribe `DESTINO_INFERIDO: develop`, **sin re-verificación determinista** — es decir, un
destino ASUMIDO SIN MEDIR gobernando un candado. La regla de unjordi lo cubre de frente: **el default se
mide o se conserva el anterior; jamás se inventa**, y `main` nunca es default.

## D-4 — PENDIENTE DE SU RESPUESTA (la pregunta no daba los datos)

> *"cuáles?! de qué copias hablas?"*

Los datos que faltaban, medidos hoy en `/Users/unjordi/Mi unidad/claude-sessions/`. **Las cuatro copias
divergen de la fuente, y todas están congeladas el 2026-07-26** (~7 semanas):

| copia en el Drive | fuente en el repo | Drive | repo |
|---|---|---|---|
| `exportar-sesion-master.sh` | `brain/hooks/exportar-sesion-master.sh` | 130 líneas | **191** |
| `install-hook.sh` | `brain/sesiones-master/install-hook.sh` | 51 | 36 |
| `seed.sh` | `brain/sesiones-master/seed.sh` | 62 | **71** |
| `README.md` | `brain/README.md` | 62 | **219** |

El hook del Drive tiene **61 líneas menos** que el vivo: le faltan el gatillo `Stop` con debounce y el
fast-path, entre otras cosas. Quien arranque una máquina nueva desde el Drive instalaría el mecanismo de
julio. La decisión (borrar dejando un puntero) sigue pendiente de su OK **por ser destructiva sobre el Drive**.

## D-5 — DECIDIDA: instalar `checkpoint-mecanico`, **con el release**

> *"con el release."*

No se cablea en una tanda suelta: entra cuando se libere a `main`, que es la misma liberación que hoy está
retenida a propósito. Consecuencia operativa mientras tanto: **el andamio mecánico no existe en esta
máquina**, así que el hilo escrito a mano sigue siendo la única red contra el compact.

## D-6 — DECIDIDA: sanear `masters.json` **desde la GUI de configuración**

> *"lo hacemos desde la GUI de configuración."*

Deja de ser un saneo manual de una vez y pasa a ser **una capacidad del producto** (ítems 6 y 7 de D-1:
refrescar `masters.json` y elegir qué sesiones son master). R-13 se reformula: no es "corregir 4 targets",
es "que el usuario pueda ver y corregir el registro". Los 4 targets inválidos son el primer caso de uso.

## D-7 — DECIDIDA: las tandas las agrupa Claude, **por TEMA**

> *"las tandas que consideres. el punto del squash es no spamear de commits el árbol a largo plazo, pero
> también deberíamos siempre agrupar los squashes por tema."*

El criterio de corte **no es el tamaño ni el riesgo: es la COHERENCIA TEMÁTICA**. Un squash debe poder
contarse en una frase. Esto es una norma de proceso más allá de este slice: *agrupar siempre los squashes
por tema*.
