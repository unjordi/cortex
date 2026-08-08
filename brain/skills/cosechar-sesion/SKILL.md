---
name: cosechar-sesion
description: Ritual de COSECHA LOCAL — al cerrar el día (o cuando lo piden), revisa TU PROPIO transcript de la sesión y extrae los aprendizajes GENUINOS (feedback del usuario, lecciones de proceso, gotchas) que valga la pena preservar, y appendea cada uno como un bloque al FINAL de .claude/memory/aprendizajes.md con atribución. Alimenta el inbox de aprendizajes del equipo. Úsala antes de cerrar sesión si aprendiste algo durable; NO cierra slice ni hace git.
---

# Cosechar la sesión (cosecha LOCAL de aprendizajes)

Es la **capa LOCAL per-dev** del ritual semanal de cerebro. Cada Claude solo ve SU propio
transcript (no puede leer las sesiones de las otras máquinas), así que la forma de que un aprendizaje
tuyo llegue al equipo es **cosecharlo aquí, atribuido, al log compartido**. Este log
(`.claude/memory/aprendizajes.md`) es el **INBOX**: append-only, `merge=union` → los apéndices de los
3 devs se fusionan sin conflicto al integrar. La **curación** (trenzar solapes, graduar lo maduro) la
hace después la skill hermana `unificar-cerebro` — aquí **solo cosechas**, no curas.

> **Hermana de `cerrar-slice`, NO la reemplaza.** `cerrar-slice` cierra un slice de CÓDIGO (build/tests
> /memoria/MR). Ésta cosecha APRENDIZAJES (prosa) al inbox. Puedes correr ésta sin cerrar ningún slice
> (p. ej. al terminar el día). **NO hace git, NO cierra slice, NO integra a develop** — eso es de
> `cerrar-slice`/`unificar-cerebro`.

## Cuándo se dispara
- Al **cerrar el día** o una tanda larga de trabajo, antes de apagar.
- Cuando el usuario lo pide (`/cosechar-sesion`, "cosecha lo de hoy", "guarda lo que aprendiste").
- Cuando el hook `recordar-cosechar` te lo sugiere (trabajaste y no cosechaste) — no es obligatorio,
  pero si aprendiste algo durable, córrela.

## Paso 1 — Relee tu sesión y separa el GRANO de la PAJA
Revisa tu propio transcript / la conversación de esta sesión y busca los aprendizajes **DURABLES**.
Un aprendizaje se cosecha SOLO si sobreviviría a esta sesión y le serviría a otro dev / a un Claude
futuro. Distingue:

- **SÍ cosechar** (grano):
  - **Feedback del usuario** que corrige un comportamiento o fija una preferencia ("no hagas X",
    "siempre prefiero Y", "me molestó que Z"). **OJO:** si es de TRATO personal (cómo tratar a la
    PERSONA), NO va al inbox → va al archivo GLOBAL (ver el RUTEO abajo).
  - **Lecciones de proceso**: un enfoque que falló y por qué; un orden de pasos que resultó ser el
    correcto; una regla de flujo que se descubrió en el camino.
  - **Gotchas técnicos no-obvios**: una trampa del stack/entorno que costó tiempo y que no está ya
    documentada (un flag oculto, un supuesto que mordió, una interacción sorpresa).
  - Una **decisión** tomada con el usuario cuyo *porqué* conviene preservar (si no vive ya en su
    doc propio).

- **NO cosechar** (paja): pasos triviales ("corrí el build, pasó"), lo que ya está documentado, el
  detalle efímero de UNA tarea (eso va a la bitácora/estado, no aquí), reformulaciones de normas que
  ya existen, o "aprendizajes" genéricos sin caso real detrás.

Si al releer NO hay nada durable, **está bien no cosechar nada** — dilo y termina. Cosechar
trivialidades ensucia el inbox y le quita señal a la curación semanal. La calidad manda sobre la
cantidad: 1 aprendizaje real vale más que 5 de relleno.

### ⚠️ RUTEO — el TRATO personal del usuario NO va al inbox: va al archivo GLOBAL
Antes de appendear, clasifica cada grano por su NATURALEZA: **conocimiento de PROYECTO** (→ inbox de
aquí) vs **TRATO personal del usuario** (→ archivo GLOBAL, NO este inbox).
- **TRATO personal** = cómo le gusta a la PERSONA con la que trabajas que le **comuniques, decidas y
  trabajes** ("no me espejees mi idea", "no me atribuyas tus hipótesis", "no me rebotes el marginal si
  ya me diste el criterio", "no me pidas permiso para avanzar", "arregla por el flujo completo"). Eso
  NO es de un proyecto → **NO lo appendees a `aprendizajes.md`.** Vive en UN solo lugar: la memoria
  GLOBAL per-máquina **`~/.claude/projects/-Users-<user>/memory/como-trabajar-con-<user>.md`** —
  porque es sobre una PERSONA, no un proyecto → **viaja mal por git** (mentiría al clonar en otra
  máquina, y expondría trato personal en un repo compartido). Cómo escribirlo ahí:
  - **answer-first / positivado** ("ESTO SÍ" primero), **desinflado a 1-2 líneas** por nugget, en su
    sección (el molde tiene 5: 🗣️ Comunicación · ✅ Decisiones · 🛠️ Proceso · 🌿 Git · 🎯 Preferencias);
  - **con procedencia:** lo que va **entre comillas es cita literal** del usuario; lo tuyo va marcado
    **`[INFER]`** (norma `feedback-no-atribuir-mis-ideas-al-usuario`);
  - **NO dupliques normas UNIVERSALES del brain** (doc=realidad, definición de LISTO, flujo de git,
    probar-el-flujo-completo, autorización acotada…): esas ya viven en `~/.claude/CLAUDE.md` y aplican
    a cualquiera → **REFERÉNCIALAS con el sabor personal, no las copies.**
  - El archivo `como-trabajar-con-unjordi.md` (~116 líneas, esas 5 secciones) es el ejemplo canónico.
- **NUNCA re-crees un `feedback-*.md` suelto de TRATO** en el `.claude/memory/` del repo: ES exactamente
  el drift que esta regla mata (menciones de trato duplicadas por cada repo, que se desincronizan).
- **Preferencia SOBRE OTRO dev** (`· sobre: <handle>`, ver Paso 2) → esa SÍ sigue por el inbox: así
  viaja a su máquina (no tienes su archivo global local para editarlo).
- **Conocimiento de PROYECTO** (una decisión de ESTE repo con su porqué, un gotcha del stack, una
  lección de proceso genérica) → va al inbox de aquí, como siempre.

## Paso 2 — Appendea cada aprendizaje al FINAL de `aprendizajes.md`
Por cada aprendizaje del grano, **appendea un bloque al FINAL** de
`.claude/memory/aprendizajes.md` (nunca al principio, nunca en medio). Respeta EXACTO el formato que
declara el header de ese archivo:

```
## <AAAA-MM-DD> · aportó: <handle> · <tema corto>
<prosa en TU voz: qué se aprendió, el caso real que lo destiló, POR QUÉ importa y CÓMO aplicarlo.>
<LÍNEA EN BLANCO al final del bloque>
```

Reglas duras del append (las exige el `merge=union` + el lint):
- **NO edites bloques viejos** ni reordenes: solo appendeas.
- **NO metas aprendizajes en otros archivos** (`flujo-de-trabajo.md`, `MEMORY.md`, `_PROTOCOLO.md`,
  `estado-proyecto.md`…). El inbox es este archivo y solo este. (Graduarlos a su hogar es trabajo de
  `unificar-cerebro`, no tuyo aquí.)
- **Fecha** = la de hoy, formato `AAAA-MM-DD`.
- **`handle`** = de la **tabla de handles** de `_PROTOCOLO.md` (`unjordi` / `carlos` / `chun` — usa el
  que corresponda al dev de ESTA máquina). Si no estás seguro del handle, usa el del usuario de la sesión.
- **Co-autoría**: si el aprendizaje salió de un ida-y-vuelta entre dos, `aportó: unjordi, chun`.
- **`· sobre: <handle>`**: si el aprendizaje es SOBRE otra persona (p. ej. tú anotas una preferencia
  de chun), agrégalo: `## 2026-07-21 · aportó: unjordi · sobre: chun · <tema>`.
- **Cada bloque termina con una LÍNEA EN BLANCO** (separa entradas tras el merge — sin ella el union
  las pega).
- **Prosa, no bullet-dump**: escribe con TU voz, cita el caso real ("hoy pasó que…"), di el porqué y
  el cómo-aplicar. La VOZ y la atribución viven en el bloque → sobreviven al squash y al clon (no hay
  atribución git en un repo-plantilla).

Usa el mecanismo de append (p. ej. `>>` o un Edit que agregue al final) — nunca uno que reescriba el
archivo completo, para no pisar bloques concurrentes.

## Paso 3 — Reporta lo cosechado (y NADA más)
Di al usuario, en una o dos líneas, cuántos aprendizajes appendaste y de qué tratan. **No cierres
slice, no hagas commit, no integres nada.** Si el usuario quiere que esto llegue al equipo, eso es la
**reconciliación semanal** (`unificar-cerebro`) — menciónalo si viene al caso, pero no lo ejecutes tú.

> **Verde técnico ≠ LISTO.** Appendear al inbox NO declara nada "listo": es materia prima para la
> curación. El valor real lo confirma el equipo cuando se cura y se gradúa.
