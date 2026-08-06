---
name: to-do
description: El skill de to-dos/backlog. Invócalo con /to-do para CARGAR la interfaz de tareas del harness poblada AL VUELO desde el backlog durable (estado-proyecto.md) — sin pedirla a mano cada vez — y para redactar/curar tareas con higiene durable: título = el QUÉ, estatus en su CAMPO (no incrustado en el texto), fechas ABSOLUTAS (nunca "hoy"). Recuerda la separación dura: la task-list del harness es SCRATCH de sesión; la fuente de verdad es estado-proyecto.md. Úsalo al arrancar/retomar para ver tu backlog vivo, o al escribir cualquier tarea/pendiente.
---

# to-do — carga la interfaz de tareas + higiene del backlog

## Al invocarte (`/to-do`): CARGA la interfaz, NO esperes a que la pidan
El punto del skill es que el usuario **no tenga que pedir "muéstrame el to-do" caaada vez.** Al invocarte:
1. **Lee el backlog durable** → `.claude/memory/estado-proyecto.md` (el hub vivo: pendientes autocontenidos + prioridad + los que "esperan tu decisión"). Si hay hilo vivo, ojea `hilo-mental-actual.md`.
2. **Puebla/refresca la interfaz de tareas del harness** (`TaskCreate`/`TaskUpdate`/`TaskList`; o `TodoWrite` si tu harness la expone) con los ítems VIVOS del backlog — ya redactados con la higiene de abajo y con su **estatus real**. Queda renderizada de una.
3. Si la interfaz **ya trae tareas**, **reconcília** contra `estado-proyecto.md` (no dupliques): sube lo que falte, corrige estatus, cierra lo hecho.

Eso es lo que el usuario espera ver al escribir `/to-do` a secas: su backlog cargado como interfaz viva, sin fricción.

## Regla 1 — DOS planos, no los confundas
- **La task-list / `TodoWrite` del harness = SCRATCH de sesión.** Efímera (se pierde al cerrar/compactar). Es una **VISTA**.
- **El backlog DURABLE = `.claude/memory/estado-proyecto.md`.** La **FUENTE DE VERDAD** ("aquí empiezas siempre").
- La interfaz **espeja** el backlog durable, no lo reemplaza. Al **cerrar** una tarea, el cambio se **ASIENTA en `estado-proyecto.md`** (lo hace `cerrar-slice §2`), no solo en la task-list. **Si divergen, manda `estado-proyecto.md`.**

## Regla 2 — Redacción DURABLE (anti-stale)
Un ítem se redacta para que **NO envejezca mal**:
- **El TÍTULO dice el QUÉ durable** (+ el PORQUÉ si ayuda), y nada más.
- **El estatus va en su CAMPO** (`pending`/`in_progress`/`parked`/`done`), **NUNCA incrustado** como prefijo en el texto (`[PARQUEADO] …`): un prefijo de estatus **pudre** y **DUPLICA** el campo.
- **Fechas ABSOLUTAS** (`2026-08-06`), **jamás relativas** ("hoy / ahora / anoche / esta semana") — se quedan stale en 3 patadas.
- **Cero estado transitorio en el título** ("(nadie lo necesita hoy)"). Si importa, va como **nota DATADA** o como **prioridad**, no cocido en el nombre.

**Antes → después** (caso real):
❌ `[PARQUEADO] Re-scopear casalianza a 7 guards (nadie lo necesita hoy)`
✅ título `Re-scopear casalianza a 7 guards` · estatus `parked` · nota `parqueado 2026-08-06, sin consumidor urgente`

## Por qué existe / origen
La regla "TodoWrite = scratch / backlog durable = `estado-proyecto.md`" vivía **enterrada** en `orquestar-fanout` (un skill de fan-out) → invisible en sesiones SIN agentes. Se **extrajo aquí**, a su home propio, y se le sumó la **higiene de redacción**. Origen: 2026-08-06 — unjordi señaló que `[PARQUEADO]…(hoy)` "se queda stale en 3 patadas" y pidió un skill de to-dos que además **cargue la interfaz** al invocarse.

## Relación
- **`cerrar-slice §2`** — asienta el cierre en `estado-proyecto.md` (donde el ESPEJO se vuelve durable).
- **`orquestar-fanout`** — modelo de estado de dos archivos para el fan-out (deja un puntero acá).
- **`checkpoint`** — vuelca el hilo vivo (`hilo-mental-actual.md`); los pendientes durables ya viven en `estado-proyecto.md`.
