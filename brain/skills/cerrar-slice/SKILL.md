---
name: cerrar-slice
description: Ejecuta el ritual de CIERRE de un slice — verifica (build/tests/lint según tu stack), actualiza la memoria, confirma con el usuario, lo lleva por el flujo de git (ramita→MR/PR→develop) y cosecha los aprendizajes genéricos a skills/cerebro global. Úsala cuando creas que terminaste un slice, para no declarar "listo" sin evidencia ni saltarte el flujo.
---

# Cerrar un slice (definición de terminado + flujo)

Encapsula la **"definición de terminado" con evidencia** y el **flujo de git**. Lo refuerzan los hooks
**Stop** (`dod-verificar`, bloquea "listo" sin evidencia), **git-branch-guard** (bloquea push a
develop/main), **merge-develop-guard** (candado ÚNICO del punto de merge: exige `--squash` + un mensaje con
sustancia y tu OK expreso antes de integrar — consolida los antiguos `merge-squash-guard` +
`confirmar-merge-develop`). El dashboard + doc=realidad (Paso 2 de aquí) NO tiene hook que lo recuerde
(`recordar-dashboard` se retiró, overhaul hooks 2026-09-18, puramente advisory) — es self-check tuyo antes
de pushear. Sigue el orden — no te saltes pasos. Versión **genérica** (agnóstica de stack): sirve para
cualquier proyecto que use este cerebro.

**La maquinaria del merge vive en el script `cerrar-slice.sh` (junto a este SKILL.md).** Este documento se
queda con el JUICIO (¿está LISTO? ¿el mensaje cuenta el cambio neto?); el script arma el comando correcto
(squash, INMEDIATO, sin `--auto`, con rastro, borrando la rama). Ver Paso 4.

## 1. Verifica (evidencia real, no tu memoria del chat)
- Corre la **verificación técnica que aplique a tu stack** y **CITA la salida real** (0 errores):
  build + tests + lint. Ejemplos: `npm run build && npm test`, `dotnet build && dotnet test`,
  `cargo build && cargo test`, `go build ./... && go test ./...`, `pytest`, `make`.
- Revisa el **contrato de arquitectura** (`AGENTS.md` si el repo lo tiene) si tocaste capas/estructura.
  Si es **MIGRACIÓN**: revisa el inventario de paridad **Y** el módulo real de la app legada; marca el
  ítem como migrado solo si pasó la verificación.
- **Runtime-safe, no solo compila:** para cambios de **API / DTO / repos / SQL**, corre un **smoke E2E**
  (en Docker si aplica) que golpee el endpoint/flujo tocado — build+unit NO ven bugs de runtime (una
  firma que rompe la materialización Dapper → 500; `Ok(string)` text/plain que cuelga un diálogo; SQL
  dinámico mal armado → 0 filas; todos pasaron build+tests y reventaron en vivo, incluso llegaron a producción).
- **Cambio DESTRUCTIVO = pausa + OK.** Si el diff ELIMINA funcionalidad/entidades/tablas o mucho código,
  es destructivo y **NO transitivo** aunque un doc lo respalde: preséntalo al usuario como PÉRDIDA explícita
  ("esto borra X que costó Y") y pide su OK ANTES de ejecutarlo/cerrarlo. (En un caso real se aplanó un esquema de
  permisos jerárquico de meses amparado en `AGENTS.md`, sin avisar que era una pérdida.)
- **QA de NO-REGRESIÓN visual.** Tras tocar un layout/estilo COMPARTIDO, re-verifica los 2-3 ajustes
  previos del mismo componente: un fix de layout puede romper otro que ya estaba bien.
- Recuerda: **verde técnico ≠ LISTO.** Es *verificado técnicamente*: peldaño necesario, insuficiente
  para declarar LISTO (falta (1) confirmación funcional del usuario o (2) su autorización expresa).

## 2. Actualiza la memoria Y la doc (en la misma tanda — doc = realidad)
Este paso ES el "volcado" del skill `checkpoint`: **cerrar-slice = ese volcado + verificar + git + cosecha.**
Modelo de estado (tres archivos, un dato en UN lugar — ver skill `orquestar-fanout`): **`estado-proyecto.md`
= hub vivo** (dónde estamos + backlog + prioridad); **`bitacora.md` = log append-only** (qué pasó);
**`hilo-mental-actual.md` = el hilo de trabajo vivo** (de qué va ESTO ahora — lo sobrescribe `checkpoint`, lo
rehidrata el hook `rehidratar-hilo` al retomar/compactar). Al cerrar, **refresca (o vacía) `hilo-mental-actual.md`**
para que no quede apuntando a un tema ya terminado.
- `.claude/memory/estado-proyecto.md`: mueve el ítem a **HECHO** (commit+fecha al mergear); registra
  **DECISIONES**; lo descartado a propósito va en **FUERA POR DECISIÓN** (no en pendiente). **Estado
  BIDIRECCIONAL:** ni dejes "pendiente" algo que YA está hecho, ni marques "hecho" algo sin verificar —
  la doc miente en ambos sentidos y cuesta auditorías (en un caso real el usuario forzó 3 por esto).
- **Backlog COMPLETO, no solo lo elegido:** si este slice viene de una lista de hallazgos/opciones que
  TÚ generaste (una auditoría, una revisión, un diagnóstico) y el usuario solo actuó sobre un
  subconjunto, **los ítems restantes se escriben AHORA a PENDIENTE** con su severidad y origen — nunca
  se quedan solo narrados en el chat. Y esa elección del usuario **NO es "el alcance que él acordó"**:
  el corte lo pusiste tú al redactar las opciones; no lo cites como instrucción suya para justificar no
  tocar el resto (ver norma "Ningún hallazgo tuyo se queda solo narrado en el chat").
- **Lo DELEGADO a un artefacto TAMBIÉN va al backlog (con severidad):** si al cerrar empujaste ítems
  FUERA de alcance y los dejaste en el TEXTO de un entregable (sección "Pendientes/Delegados/§ fuera de
  alcance" de un skill, un dictamen, un README), eso **NO los resuelve**: es log disfrazado de backlog.
  **Bárrelos a `estado-proyecto.md` con severidad y origen ANTES de cerrar** y **CALIFÍCALOS** (un bug
  destructivo diferido NO es un "pendiente menor"). La pregunta de 2º orden: *¿lo que empujé fuera del
  muro tiene casa, dueño y severidad, o se evapora?* — un artefacto tidy con su sección numeradita SE
  SIENTE como cierre y no lo es. Un hook no puede juzgar si tu lista de delegados quedó completa → paso
  EXPLÍCITO de esta skill. Origen: `reubicar-master §9`, 2026-08-08 — delegó 4 aristas del sync de
  sesiones al texto del skill, una DESTRUCTIVA, hasta que se cacharon a mano.
- **Appendea UNA línea al FINAL** de `.claude/memory/bitacora.md` (`- fecha · rama · quién · qué`)
  con `>>` (`printf '%s\n' '- …' >> bitacora.md`), **no** con un Edit que reescriba: el append-al-final
  es lo que deja que varias sesiones/agentes escriban la misma bitácora sin pisarse (dos `>>` no chocan;
  un Edit tropieza con "File modified since read").
- Si la feature creció, deja su nota `.claude/memory/<feature>.md` y enlázala en `MEMORY.md`.
- **doc = realidad (NO se pregunta):** si cambiaste comportamiento, config, rutas, una interfaz o un
  hook/skill, actualiza la doc que lo **DESCRIBE** en ESTA misma tanda — README (p. ej. el árbol del
  cerebro + el conteo de checks de `test-brain.sh`), `docs/`, comentarios. **Rastrea las copias** (un
  `grep` del nombre/valor viejo): una doc desincronizada YA es una doc que miente. **RELEE el
  ENCABEZADO/resumen de apertura del doc, no solo la línea que tocaste** — el "arriba" es lo primero que
  se lee; un encabezado stale ("Dos hitos cerrados") mientras el cuerpo ya avanzó es la trampa más común
  (pasó en un caso real varias veces). Y si dos números/valores describen lo mismo (una badge y la prosa), que
  coincidan — desincronizados YA mienten.
- **Dashboard GLOBAL** (`dashboard_cerebro.md`, memoria de ESTA máquina): **appendea** una línea al FINAL
  de su Bitácora con `>>` (no con un Edit) — así no chocas con las otras sesiones de Claude que tocan ese
  archivo a la vez. Ajusta Mapa/Infra/Cabos (secciones curadas, con Edit) solo si cambió el layout de
  repos/memoria/proyectos.
- **(fan-out)** limpia los worktrees zombies con `limpiar.sh worktrees` (deja anotado el pendiente de
  los que sigan vivos).

## 3. Confirma CON EL USUARIO antes del MR/PR
Commit y push a la **ramita** van libres, sin pedir permiso. Pero **antes de integrar a develop,
PREGÚNTALE al usuario si el slice queda cerrado.** El merge a develop no se hace sin esa confirmación
(un release a main, tampoco — eso lo decide el humano deliberadamente).
- **Al INVITAR a QA, el entorno desplegado debe contener TODO lo que le pides revisar.** Antes de
  decir "revísalo", verifica que el commit/rama que está desplegado (p. ej. `:9582`) INCLUYE cada ítem
  de tu lista: si algún fix vive en OTRA rama, recóncilialo (cherry-pick/merge) + **redespliega PRIMERO**.
  Si por lo que sea no puedes dejar el entorno completo, avísalo por ADELANTADO y explícito ("estos N
  ítems NO están en este entorno todavía, sáltalos") — **nunca** a media QA. Reconciliar la divergencia
  de ramas es del ORQUESTADOR, no de quien hace el QA. (Lección real: se pidió QA en un entorno que corría
  una rama sin los fixes → clicks gastados revisando algo que ahí no estaba resuelto.)

## 4. Flujo de git (tras el OK del usuario) — **integra con SQUASH, merge INMEDIATO (sin MWPS)**
La ramita se colapsa a **UN commit limpio** en develop (lo exige `merge-develop-guard`). El merge a
develop es **DELIBERADO e INMEDIATO**: espera a que el pipeline esté verde y mergea YA — nunca lo dejes
ARMADO para que se dispare solo (ver el porqué abajo).

**El comando de merge lo arma el script `cerrar-slice.sh`** (junto a este SKILL.md) — es la fuente única de
la receta, para que no driftee copiada en el markdown y en los mensajes del guard. Tú te encargas del
JUICIO (curar el `resumen.md`); el script hace cumplir squash + sin-`--auto` + rastro + borrar la rama, y
mapea glab↔gh:

```bash
git push -u origin feat/<tema>
# glab: glab mr create --source-branch feat/<tema> --target-branch develop --squash-before-merge --remove-source-branch --title "…" --description "…" --yes
# gh:   gh pr create --base develop --fill

# … arma el resumen curado en resumen.md (ver abajo) …
bash <ruta>/cerrar-slice.sh --id <id> --message-file resumen.md --wait-ci   # espera CI verde y mergea YA
#   (autodetecta glab/gh; --repo <slug LITERAL> si es multi-repo; --dry-run para revisar el comando primero)

git checkout develop && git pull --ff-only
bash ~/.claude/hooks/limpiar.sh ramas              # barre la ramita local (y su remota si quedó)
```

`<ruta>` = `brain/skills/cerrar-slice/cerrar-slice.sh` en el repo cortex, o `~/.claude/skills/cerrar-slice/cerrar-slice.sh`
una vez instalado. Corre `cerrar-slice.sh --help` para las opciones.

**Las dos recetas (glab/gh) son GEMELAS: `--delete-branch` de `gh` es `--remove-source-branch` de `glab`** —
el script las mapea solo. Sin ese flag la rama queda colgando en el remoto tras el squash y nadie la vuelve
a mirar — de ahí sale la acumulación de ramas viejas en `origin`. Lo exige `merge-develop-guard`.

**Para borrar la ramita LOCAL usa `limpiar.sh ramas`, NO `git branch -d`.** En un flujo que integra con
SQUASH, `git branch -d` **rehúsa** ("not fully merged"): el squash crea un commit NUEVO, así que la rama
original no queda de ancestro. Es el método que el mecanismo existe para suplir — ver la regla de abajo.

### Por qué SIN `--auto-merge` / `--auto` (no es "GitHub auto-merge del PR")
`--auto-merge` en `glab` arma **Merge When Pipeline Succeeds (MWPS)**: el merge **NO** ocurre al correr
el comando, queda **ENCOLADO** para dispararse solo, sin testigo, cuando el pipeline termine — minutos
después, en otro momento. `merge-develop-guard` exige tu OK **del instante del merge** (y `cerrar-slice.sh`
RECHAZA `--auto`/`--auto-merge` de plano); encolarlo rompe esa garantía (el guard autoriza el comando, pero
no controla el evento futuro que arma). Por eso
la integración coordinada a develop/main **espera el pipeline verde primero y mergea de inmediato**, sin
dejarlo armado — el "sin fricción de revisión" para 1–3 devs sigue aplicando (nadie más aprueba el MR),
lo que cambia es que el ACTO de mergear pasa ya, deliberado, no en diferido. (Visto al mergear el !112 de
cortex: quedó en MWPS pese al OK explícito.) El candado server-side definitivo sigue siendo proteger
las ramas + `squash_option=always` (GitLab).

### El mensaje-resumen (`--squash-message`) — redáctalo bien, es lo que queda en develop
Los N commits granulares de la ramita **desaparecen** del histórico de develop; solo queda este mensaje.
Escríbelo como un **resumen curado en prosa**: título Conventional en español + un cuerpo que cuenta el
**cambio neto y su porqué**. **NO** pegues la lista de commits ni el ruido de "quité el botón / lo regresé
/ hotfix del hotfix" — eso es exactamente lo que el squash borra. Termina con el `Co-Authored-By`.

**Incluye la TRAZABILIDAD rama→commit (2a).** El squash BORRA el merge-commit de la plataforma (que traía
el `#id` del MR/PR) → sin un rastro en el propio mensaje, un `git log develop` no dice de qué ramita salió
cada commit. Por eso el cuerpo **DEBE** incluir una línea `Rama: <nombre-rama>` y una `MR/PR: !<id>` (o
`#<id>`). `merge-develop-guard` (y `cerrar-slice.sh`) bloquean un `--squash-message` que no traiga ese rastro.

**Describe el CÓDIGO, no el PROCESO (sin editorializar).** El resumen dice *qué hace el código ahora* y
*por qué*, **no** cómo llegaste a él. Nada de "se decidió / tras analizar / el asistente notó que / se
identificó que / en esta sesión / se procedió a" — eso es memoria interna del proceso, no el cambio neto
(el hook lo bloquea). Y evita el **pegote de acciones** ("se cambió X. Se actualizó Y. Se corrigió Z."):
es la lista de commits que el squash debía RESUMIR, no un resumen.
- ❌ *"Se analizó el middleware y se decidió reemplazar la validación de tokens."* → habla del PROCESO.
- ✅ *"El middleware ahora valida el claim `exp` contra el reloj del servidor en lugar del cliente,
  eliminando la ventana de replay de 30 s. Rama: fix/token-exp · MR: !123"* → habla del CÓDIGO, con traza.

> Gotcha `glab`: si en algún caso SÍ necesitas encolar (excepción rara, no el default de aquí), la flag
> es `--auto-merge`, no `--auto`. (`merge-develop-guard` ya IGNORA una MENCIÓN citada de `glab mr merge`
> —dentro de un `printf`/`echo`/heredoc/`--body`— así que loguear el comando ya no dispara el candado.)
>
> Gotchas de commit (destilados de un caso real): el mensaje largo va por **heredoc** (`git commit -F -`) o un
> archivo ÚNICO en `/tmp` — **NUNCA dentro del repo** (se cuela al árbol) ni reutilizando uno viejo
> (commit con mensaje equivocado → `--amend`). Y **no encadenes `git commit`/`push` dentro de loops de
> espera en background** (`pgrep`/`pkill`): se truncan y dejan el commit a medias — separa "esperar a que
> algo esté listo" (foreground/Monitor) de las acciones git (atómicas).

## 5. Cosecha de aprendizaje Y de herramientas (¿es genérico? ¿sobrevive al reinicio?)
Antes de dar por cerrado el slice, pregúntate: **¿dejó una lección reutilizable** (un gotcha, una
convención, un patrón, o hasta una skill nueva)? No lo dejes en "ya me acordaré" — cosecharlo es parte
del cierre, no un extra. (Esto absorbe lo que antes era el skill separado `cosechar-sesion`, retirado
2026-09-17 — este §5 YA ES la cosecha; su maquinaria de append vive en el script `cosechar-aprendizaje.sh`,
junto a este SKILL.md.)

### 5a. Relee la sesión y separa el GRANO de la PAJA
Revisa tu propia sesión/transcript y busca los aprendizajes DURABLES — uno se cosecha SOLO si
sobreviviría a esta sesión y le serviría a otro dev / a un Claude futuro:
- **SÍ cosechar** (grano): **feedback del usuario** que corrige un comportamiento o fija una
  preferencia ("no hagas X", "siempre prefiero Y") — salvo que sea TRATO personal (ver 5b); **lecciones
  de proceso** (un enfoque que falló y por qué, un orden de pasos que resultó correcto); **gotchas
  técnicos no-obvios** (una trampa del stack/entorno que costó tiempo); una **decisión** con el usuario
  cuyo porqué conviene preservar (si no vive ya en su doc propio).
- **NO cosechar** (paja): pasos triviales ("corrí el build, pasó"), lo que ya está documentado, el
  detalle efímero de UNA tarea (eso va a la bitácora/estado, no aquí), reformulaciones de normas que ya
  existen, o "aprendizajes" genéricos sin caso real detrás. Si al releer no hay nada durable, **está bien
  no cosechar nada** — cosechar trivialidades ensucia el inbox y le quita señal a la curación. Calidad
  sobre cantidad: 1 aprendizaje real vale más que 5 de relleno.

### 5b. RUTEO — el TRATO personal del usuario NO va al inbox del proyecto: va al archivo GLOBAL
Antes de cosechar, clasifica cada grano por su NATURALEZA: **conocimiento de PROYECTO** (→ inbox del
repo, `aprendizajes.md`) vs **TRATO personal del usuario** (→ archivo GLOBAL, **NO** este inbox).
- **TRATO personal** = cómo le gusta a la PERSONA que le comuniques, decidas y trabajes ("no me
  espejees mi idea", "no me atribuyas tus hipótesis", "no me pidas permiso para avanzar", "arregla por
  el flujo completo"). Eso **NO va al inbox** del repo (**NO lo appendees** a `aprendizajes.md`, **NO
  este inbox**): vive en UN solo lugar, la memoria GLOBAL per-máquina
  `~/.claude/projects/-Users-<user>/memory/como-trabajar-con-<user>.md` — porque es sobre una PERSONA,
  no un proyecto (viajaría mal por git: mentiría al clonar en otra máquina, y expondría trato personal
  en un repo compartido). Escríbelo ahí answer-first / desinflado a 1-2 líneas, en su sección (🗣️
  Comunicación · ✅ Decisiones · 🛠️ Proceso · 🌿 Git · 🎯 Preferencias), **con procedencia** (lo que va
  entre comillas es cita LITERAL del usuario; lo tuyo va marcado `[INFER]`), y **sin duplicar** las
  normas UNIVERSALES del brain (doc=realidad, definición de LISTO, flujo de git…) que ya viven en
  `~/.claude/CLAUDE.md` — **REFERÉNCIALAS** con el sabor personal, no las copies.
- **Preferencia SOBRE OTRO dev** (`· sobre: <handle>`) SÍ sigue por el inbox del repo: así viaja a su
  máquina (no tienes su archivo global local para editarlo).
- **Conocimiento de PROYECTO** (una decisión de este repo con su porqué, un gotcha del stack, una
  lección de proceso genérica) → va al inbox de siempre, como cualquier otro aprendizaje.
- **Nunca re-crees un `feedback-*.md` suelto de TRATO** en `.claude/memory/` del repo — es exactamente
  el drift que esta regla mata (trato duplicado por cada repo, desincronizado entre sí).

### 5c. Appendea con el script (nunca reescribas el archivo a mano)
Por cada aprendizaje de PROYECTO, usa la maquinaria (garantiza formato + append-only, nunca pisa
bloques concurrentes de otra sesión/rama):
```bash
bash <ruta>/cosechar-aprendizaje.sh --handle <tu-handle> --tema "<tema corto>" \
     --texto "<prosa: qué se aprendió, el caso real, por qué importa, cómo aplicarlo>"
#   --sobre <handle>   si el aprendizaje es SOBRE otro dev (no sobre ti)
#   --archivo <ruta>   default: .claude/memory/aprendizajes.md
```
`<ruta>` = `brain/skills/cerrar-slice/cosechar-aprendizaje.sh` en cortex, o
`~/.claude/skills/cerrar-slice/cosechar-aprendizaje.sh` una vez instalado. El `<tu-handle>` sale de la
tabla de handles del proyecto (`_PROTOCOLO.md` si existe) o de preguntarle al usuario cuál usar. **NO
edites bloques viejos** del inbox ni reordenes — el script solo appendea.

### 5d. Genérico → al cerebro global; específico → ya quedó en el repo
- **Genérica** (no atada a este proyecto) → promuévela en la MISMA tanda a la **skill** que le toque
  y/o al **cerebro global** (`cortex` / los hooks y normas de `~/.claude`). Es el punto de
  curación manual: tú y el usuario deciden qué merece subir (no todo sube — evita ensuciar el global
  con ruido específico del proyecto).
- **Específica del proyecto** → ya quedó en la memoria del repo (Paso 2 + 5c); no la subas al global.
- **Solo REPORTA** cuántos aprendizajes appendaste y de qué tratan — no es un cierre aparte: es parte de
  este mismo paso del cierre del slice.

**Persiste las HERRAMIENTAS que construiste en scratch (no solo las lecciones).** Un script/tool
reusable que armaste durante el slice (un extractor, un `analyze.py`, un one-off que resultó útil)
vive en el **scratchpad de la sesión / `/tmp` / un worktree** — y eso **muere al reiniciar la app o
cerrar el worktree**. Si es semilla reusable (no scratch de exploración de un solo uso), **cópialo al
repo** en esta misma tanda (p. ej. `scripts/<tema>/`) y **commitéalo**. Y si un doc o el backlog ya
**referencia una ruta** de esas herramientas (`scripts/etl-ots/`…), **que esa ruta exista** — una
referencia a un archivo que no está es otra doc que miente. (Regla destilada de un catch real (2026-07):
la maquinaria ETL vivía solo en el scratchpad y la sesión nueva no la encontraba.)

Un hook puede *recordar* este paso, pero no *juzgar* si cosechaste bien (lección vs herramienta,
reusable vs scratch) — por eso vive aquí.
