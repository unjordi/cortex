---
name: plan-molde-estado-proyecto
description: Plan del EPIC "molde canónico de estado-proyecto.md" — esqueleto único para todos los cerebros (canónico en el brain, contenido local per-repo), con la sección 🧭 BACKLOG que encarna el formato pulido. 4 fases (A definir molde · B sembrar+amarrar skills · C canonizar claude-brain · D auditores). Léelo antes de tocar cualquier estado-proyecto.
metadata:
  type: project
---

# Plan — Molde canónico de `estado-proyecto.md`

> **Estado: 📝 EN PLANEACIÓN (no ejecutar aún).** El plan se cierra CON unjordi; hasta entonces las fases
> NO son atacables. Hermano de [[plan-molde-cerebros]] (ese es el molde de `CLAUDE.md`+`MEMORY.md`; ESTE es
> el molde de `estado-proyecto.md`). Ítem #8 de `## 📝 2` en `BACKLOG-UNIFICADO.md`.

## 🎯 Objetivo (el porqué)
El formato pulido del backlog deja de ser un "parche" de claude-brain y se vuelve **EL esqueleto canónico de
`estado-proyecto.md` para TODOS los cerebros**: esqueleto **canónico** (propiedad del brain global,
propagado por el rayo canonizador de cerebros) + **contenido local** per-repo. Misma filosofía que el molde
de `CLAUDE.md` firma-árbol / `MEMORY.md` por prefijos (tasks #71/#72/#73). Todo el ecosistema de continuidad
(to-do, HUD, checkpoint, cerrar-slice) queda **consolidado, congruente y consistente** alrededor de UN molde.

## 🧩 El molde (borrador v1 — se pule en Fase A)
Definido en `estado-proyecto.MOLDE.md`. Secciones:
- **Frontmatter** (`name`/`description`/`type:project`).
- **`## 📌 Dónde estamos`** — resumen vivo (se reescribe, no acumula).
- **`## 🧭 BACKLOG`** — la sección que ENCARNA el formato pulido:
  - `### 📬 PRs/MRs abiertos esperando OK`
  - `### 📘+➖ 1 — Abierto a la espera del GO, o de decisión puntual` (ATACABLE)
  - `### 📝 2 — Abierto pero necesita plan` (NO-atacable)
- **`## 🚫 Intocables / Congelados`** — OPCIONAL (constraints activos con puntero; p. ej. cps, fluxcore).
- **`## 🪦 Deprecated / Fuera por decisión`** — lo muerto + lo descartado a propósito ("no reabrir").
- **`## 🧠 Decisiones de arquitectura`** — Why → Decisión.
- **Opcional por-repo:** `## 📮 Buzón` (append-only; hoy solo claude-brain).
- **El "espejo del TaskList" NO es sección aparte:** ES el grupo `### 📘+➖ 1` (atacable = HUD = espejo). El hook `recordar-cosechar` lo escribe desde el TaskList; el skill `to-do` lo lee al HUD. **Por eso el backlog es DATOS machine-readable** (máquina de escribir).
- **A donde corresponden (NO viven aquí):** ✅ Cerrado → `bitacora.md` · 🛡️ Reglas de mtto → el **skill** (una vez).

## 🚦 Las 4 fases (con el CÓMO)

### Fase A — DEFINIR el molde (drafts + pulir juntos) · EN CURSO
Hacer `estado-proyecto-canonizado.md` de los 4 repos, reshapeando su **backlog vivo** al esqueleto (los 3
grupos); el HECHO/journal se MARCA "→ bitácora" (no se cura en esta fase — eso sería churn). Pulir CON unjordi
hasta que la ESTRUCTURA quede lockeada. Hacer 4 a la vez es a propósito: stress-test del molde contra variedad
real (disciplina DOMINIO-vs-genérico).
- **Hecho:** `estado-proyecto.MOLDE.md` (esqueleto) + drafts de **plantilla** y **fluxcore**.
- **Falta:** drafts de **cps** (volumen extremo) y **claude-brain** (nota: su draft de Fase A reshapea SOLO su
  `estado-proyecto.md` de 12k; la fusión de sus 3 archivos es la Fase C, no ésta) + pulir los 4 hasta lock.

### Fase B — SEMBRAR el molde al brain + AMARRAR los skills
- Destilar el esqueleto lockeado a **`estado-proyecto.example.md`** canónico en el brain (hermano de
  `MEMORY.example-barebones.md`, task #73).
- **Amarrar** to-do + HUD + checkpoint + cerrar-slice para que sean consistentes con el molde: las **reglas de
  mantenimiento del backlog viven UNA vez, en el mecanismo** (skill), no copiadas en cada `estado-proyecto.md`.
  Decidir en cuál(es) skill viven y cómo se referencian entre sí.

### Fase C — CANONIZAR claude-brain con el rayo canonizador
Fundir los **3 backlogs de claude-brain** (`estado-proyecto.md` 12k + `backlog-desarrollo.md` 60k +
`BACKLOG-UNIFICADO.md` 8k) en **UN** `estado-proyecto.md` con el esqueleto, aplicándolo por el **rayo
canonizador** (`canonizar-cerebro` / `verificar-firma-canonica`), que debe saber sembrar esta estructura en
todo brain que canonice. **La más riesgosa: DESTRUCTIVA** → fundir los ítems vivos de los 60k SIN perder nada
+ retirar los redundantes → **OK explícito de unjordi + lista de qué se pierde** antes de ejecutar.

### Fase D — ACTUALIZAR los auditores para MANTENER el molde
`auditar-coherencia-cerebro` / `verificar-firma-canonica` / `auditor-semantico` consistentes con el molde:
detectar drift de estructura, secciones fuera de lugar, HECHO acumulado que debió ir a bitácora, Reglas de mtto
duplicadas en un repo. Que ayuden a mantenerlo, no solo a instalarlo.

## 🔗 Dependencias
`A (lock) → B → C`. `D` después de B (o en paralelo tardío). **C es destructiva y va al final**, con OK
explícito (atacarla antes = churn ciego: reestructurar contenido que el molde aún no define).

## ✅ Decisiones RESUELTAS (2026-08-09, con unjordi)
- **Espejo:** el `🔄 Espejo del TaskList` NO es sección aparte — ES el grupo `### 📘+➖ 1` (atacable = HUD = espejo; los `📝` no entran al HUD).
- **KEY de markers: INLINE** en el doc (leyenda tipo mapa: vive en el mapa). No se saca al skill.
- **Secciones "no reabrir": `🪦 Deprecated / Fuera por decisión` = UNA sola.** `🚫 Intocables/Congelados` queda OPCIONAL aparte (constraints ACTIVOS con puntero ≠ cosas muertas). `📮 Buzón` opcional (hoy solo claude-brain).
- **Reglas de mantenimiento — dónde viven EXACTO → lo decide el AUDITOR DE PROCESOS Y ALGORITMOS** (se resuelve en Fase D; falta pinear cuál auditor es / si hay que crearlo).
- **Rayo canonizador gana un check de `estado-proyecto` (SÍ):** `verificar-firma-canonica` valida que exista `## 🧭 BACKLOG` con los 3 grupos, sin HECHO acumulado, KEY presente, etc. (Fase D).

## ✅ Decisión #6 — RESUELTA (delegada a Claude por unjordi 2026-08-09: "decide tú y me quejo luego" → PROVISIONAL, revisable)
**Contrato de línea del grupo atacable (`### 📘+➖ 1`) — machine-parseable + human-curable:**

    - <marker> [<estatus>] `#<id>` — <título> · <contexto curado opcional>

- **`<marker>`** (curación HUMANA): `📘` tiene plan · `➖` mecánico.
- **`[<estatus>]`** (lo reescribe LA MÁQUINA, en sitio): `[pending]` · `[in_progress]` · `[blocked]`. Un `[done]` NO se queda → al cerrar slice la línea se MUEVE a `bitacora.md`.
- **`` `#<id>` ``** = JOIN KEY con el TaskList (backtick-wrapped, greppable) — el id de la tarea del harness.
- **`<título>`** (curación humana; = subject del TaskList) · **`<contexto>`** (curación humana, opcional).

**Regla de oro del round-trip (resuelve quién es dueño de qué):** el hook `recordar-cosechar` SOLO reescribe el
token `[<estatus>]` (localiza la línea por su `` `#<id>` ``); NUNCA toca marker/título/contexto (son curación
humana). El skill `to-do` LEE estas líneas para sembrar/reconciliar el HUD por `#<id>`. Así el doc es dueño del
TEXTO y la máquina dueña solo del ESTATUS → no se pisan. Se implementa en Fase B; el auditor de procesos
(decisión de "dónde viven las Reglas de mtto") valida el formato.

## 📌 Nota de proceso (por qué existe este doc)
unjordi (2026-08-09): metí "canonizar claude-brain" como paso atacable citando "el epic del molde" — pero el
epic NO estaba en el backlog, y de estarlo se habría visto que **su plan no está establecido → 📝, no
atacable**. Lección: un paso de un epic **no puede ser atacable si el plan del epic no está lockeado**; el
auto-chequeo es "¿está el epic entero en el backlog, con su plan?". Por eso PRIMERO el plan (este doc), luego
ejecutar.
