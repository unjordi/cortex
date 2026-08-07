---
name: to-do
description: El skill de to-dos/backlog. Invócalo con /to-do para CARGAR la interfaz de tareas del harness poblada AL VUELO desde el backlog durable (estado-proyecto.md) — sin pedirla a mano cada vez — y para redactar/curar tareas con higiene durable: título = el QUÉ, estatus en su CAMPO (no incrustado en el texto), fechas ABSOLUTAS (nunca "hoy"). Recuerda la separación dura: la task-list del harness es SCRATCH de sesión; la fuente de verdad es estado-proyecto.md. Úsalo al arrancar/retomar para ver tu backlog vivo, o al escribir cualquier tarea/pendiente.
---

# to-do — carga la interfaz de tareas + higiene del backlog

## Al invocarte (`/to-do`): CARGA la interfaz, NO esperes a que la pidan
El punto del skill es que el usuario **no tenga que pedir "muéstrame el to-do" caaada vez.** Al invocarte:
1. **Lee el backlog durable** → `.claude/memory/estado-proyecto.md` (el hub vivo: pendientes autocontenidos + prioridad + los que "esperan tu decisión"). Si el repo usa otro nombre (p. ej. `backlog-desarrollo.md`), es ese el que manda. Si hay hilo vivo, ojea `hilo-mental-actual.md`.
2. **Produce la vista agrupada por estatus** (ver formato abajo) a partir de ese backlog — es una vista DERIVADA al vuelo, no un archivo nuevo que mantener.
3. **Puebla/refresca la interfaz de tareas del harness** (`TaskCreate`/`TaskUpdate`/`TaskList`; o `TodoWrite` si tu harness la expone) con los ítems VIVOS (grupos 🟢/🟡 de la vista) — ya redactados con la higiene de abajo y con su **estatus real**. Queda renderizada de una.
4. Si la interfaz **ya trae tareas**, **reconcília** contra el backlog durable (no dupliques): sube lo que falte, corrige estatus, cierra lo hecho.

Eso es lo que el usuario espera ver al escribir `/to-do` a secas: su backlog cargado como interfaz viva, sin fricción.

## Formato de salida: BACKLOG UNIFICADO agrupado por estatus
Al invocarte, la respuesta NO es una lista plana: es un **listado único agrupado por STATUS**, en
este orden fijo (mismos emoji-headers, aunque un grupo esté vacío se omite, no se fuerza).
**Lo VIVO arriba, lo CERRADO al final, las lápidas de cierre** — para que lo accionable se lea primero
y el histórico no estorbe:

1. **🟢 Abierto y ATACABLE** — se puede trabajar YA (sin bloqueo externo, o solo espera tu "go"; un
   ítem cuya recomendación ya está hecha y solo falta tu sí es ATACABLE, no un limbo aparte).
2. **🟡 Abierto pero NO atacable** — bloqueado de verdad: por un gate, una DECISIÓN de diseño que aún
   no tomas, o una máquina/persona externa. Dilo explícito: **por qué** está bloqueado y qué lo desbloquea.
3. **✅ Cerrado ESTA sesión** — tabla de 2 columnas `PR / decisión → cierra el to-do`: qué se cerró
   y qué ítem del backlog resuelve. Solo aparece si algo se cerró en la sesión activa.
4. **⚪ Cerrado (antes de esta sesión)** — histórico, no exige acción; solo contexto.
5. **🪦 Deprecated / eliminado** — por decisión explícita, **NO re-proponer**. Va al final del todo.

Cada ítem **ABIERTO** (grupos 🟢/🟡) lleva su etiqueta de madurez del plan, al inicio de la línea:
- **`📘`** — el plan del CÓMO ya está escrito en durable (referencia dónde).
- **`📝`** — falta plan; todavía no está escrito.
- **`➖`** — mecánico/obvio, no necesita plan.

La vista se **deriva** del backlog durable cada vez que invocas — no la persistas como archivo
paralelo (eso duplicaría la fuente de verdad, ver Regla 1). Al espejar a la interfaz del harness,
solo los grupos 🟢/🟡 son tareas ACTIVAS (`pending`/`in_progress`/`parked`); ✅/🪦/⚪ son contexto
histórico, no se cargan como tareas del harness.

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

## Regla 3 — antes de marcar algo "pendiente de decisión del usuario"
Dos chequeos OBLIGATORIOS, en orden:
1. **¿YA se decidió?** Rastrea el hilo hacia atrás: si el usuario ya dispuso de esto —aunque haya sido
   varios mensajes antes, o en el enunciado inicial de la tarea— **NO lo reabras como pendiente**.
   Re-preguntar algo ya resuelto (o peor, INSISTIR en ello) es el desgaste #1.
2. **Si de verdad está pendiente, CÍTALO — nunca lo enuncies vacío.** Frases como "espera tu decisión",
   "pendiente de tu OK" o "lo dejo a tu criterio" **NUNCA** van solas: siempre CITA ahí mismo, inline,
   **las opciones concretas + tu recomendación** — answer-first, para que el usuario decida sin ir a
   buscar contexto. Si no puedes citar la decisión en una línea, todavía no está madura para "esperar
   decisión" (sigue investigando o acótala primero).

   **Antes → después** (mismo hábito que la Regla 2, aplicado a decisiones):
   ❌ "Queda pendiente tu decisión sobre el nombre del hook."
   ✅ "Pendiente tu decisión sobre el nombre del hook: `aviso-drift` (corto, ya usado en otro lado) vs
   `drift-guard` (más descriptivo, sin choque de nombres). Recomiendo `drift-guard` — evita la
   ambigüedad con `aviso-drift-cerebro`."
3. **Disposición delegada ≠ gate tuyo.** Si el usuario mandó algo a OTRO ejecutor ("que lo haga el
   Claude de ese repo", "eso lo ve fulano"), deja de rastrearlo como pendiente TUYO — no es tu backlog.

## Relación
- **`cerrar-slice §2`** — asienta el cierre en `estado-proyecto.md` (donde el ESPEJO se vuelve durable).
- **`orquestar-fanout`** — modelo de estado de dos archivos para el fan-out.
- **`checkpoint`** — vuelca el hilo vivo (`hilo-mental-actual.md`); los pendientes durables ya viven en `estado-proyecto.md`.
