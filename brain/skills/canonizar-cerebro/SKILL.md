---
name: canonizar-cerebro
description: Lleva el cerebro de un proyecto INSTANCIADO (los que produce cortex — cps, fluxcore, plantilladotnet…) a la FIRMA-ÁRBOL canónica cuando drifteó: memorias sueltas sin prefijo, CLAUDE.md viejo con prosa de guards retirados, MEMORY.md plano. Reclasifica cada memoria a su prefijo (dom-/dev-/ux-/qa- + núcleo) con `git mv` (historia intacta), dedup con RESCATE de datos únicos, reescribe CLAUDE.md a firma-árbol y MEMORY.md a índice-por-prefijo, y VERIFICA el 1:1 con el detector `verificar-firma-canonica.sh`. Humano-en-el-loop, NO auto-mutador ciego. Úsalo cuando un cerebro instanciado no respeta la estructura canónica (córrele el detector y lo verás), o como el paso ESTRUCTURAL dentro de `consolidar-cerebro`.
---

# Canonizar un cerebro instanciado — llevarlo a la firma-árbol (humano-en-el-loop)

Un cerebro que cortex instancia (cps, fluxcore, plantilladotnet, los repos .NET del equipo)
DEBE respetar una **estructura canónica** — la misma en todos, para que un Claude que salta entre
repos aprenda **UN** modelo. Con el tiempo DRIFTEAN: memorias sueltas sin prefijo, un `CLAUDE.md`
viejo que nombra guards ya retirados, un `MEMORY.md` plano sin taxonomía. Este skill **destila el
prototipo manual** que se corrió sobre fluxcore (2026-08-07) y lo vuelve un procedimiento repetible.

> **NO es un auto-mutador ciego.** Reescribir cerebros automáticamente es destructivo. Este skill guía
> a un Claude paso a paso; **el humano revisa el diff** antes de integrar. El valor es la vía SEGURA
> (git mv preserva historia, dedup con rescate, no inventar, doc=realidad) + el **detector** que verifica.

## La firma canónica (el DESTINO — no la inventes, cópiala)
Definición-de-tipo-de-dato (LÉELAS antes de tocar): `CLAUDE.example-barebones.md`,
`MEMORY.example-barebones.md` y `como-trabajar-con-usuario.example-barebones.md` del cortex.
**Instancias canónicas de referencia:** `cps` y `fluxcore` (su `CLAUDE.md` +
`.claude/memory/MEMORY.md` ya cumplen — cópiales la FORMA, no el contenido).

- **`CLAUDE.md`** (raíz del repo) = **firma-árbol**, secuencia OBLIGATORIA:
  `🎯 Misión/identidad → 🧠 Antes de construir → 📁 Dónde va cada cosa → 🖋️ LA FIRMA (árbol de
  capacidades→artefactos, DENTRO de un bloque cercado ```) → 🛡️ Reglas duras → @import MEMORY.md`.
  ATEMPORAL (gradiente de estabilidad = como `main`): cero fechas, cero "RESUELTO/al día".
- **`MEMORY.md`** = **detalle 1:1** de la FIRMA + índice de memorias **agrupado POR PREFIJO**
  (`dom-` dominio · `dev-` desarrollo/infra · `ux-` diseño · `qa-` calidad · **núcleo** sin prefijo:
  `estado-proyecto` · `bitacora` · `aprendizajes` · `backlog-<tema>` · `hilo-mental-actual` ·
  `cementerio`). Answer-first: cada nota abre con su RESPUESTA y su ESTADO.
  **Ojo — `como-trabajar-con-<usuario>` NO es una memoria de repo:** es el manual de TRATO de una
  PERSONA → vive en la **memoria GLOBAL per-máquina** (`~/.claude/projects/<slug>/memory/`, la
  siembra `install-brain`), NUNCA en el `.claude/memory/` de un repo (viajaría por git y sería ruido
  para otro dev). No lo indexes en el `MEMORY.md` de un repo. Su barebones es
  `como-trabajar-con-usuario.example-barebones.md`.
- **Invariante 1:1:** cada memoria (salvo `*.local.md`) está indexada, y cada enlace del índice
  resuelve a un archivo real. Sección = prefijo = orden del folder → una sola taxonomía, cero drift.
- **`AGENTS.md`** (si existe) queda para la **ARQUITECTURA real** del proyecto — NO es la firma. Un cerebro
  SIN arquitectura pesada (hobby/meta) no necesita `AGENTS.md`. **Si el entry-point operativo REAL de hoy es
  OTRO archivo** (p. ej. games-master usa `AGENTS.md` como su "LEE ESTO ANTES DE HACER NADA"), canonizar lo
  MIGRA a la convención: su contenido OPERATIVO pasa a `MEMORY.md`, `CLAUDE.md` queda como su TOC, y `AGENTS.md`
  se reduce a la arquitectura real (o se retira). Migrar un cerebro **en uso** (un gold standard) es decisión
  deliberada del humano → se PARQUEA si está en uso.
- **GRADIENTE DE ESTABILIDAD (el PORQUÉ de que la firma sea atemporal):** `CLAUDE.md` = como `main` (solo
  estructural, muta casi nunca — solo si cambia la ESTRUCTURA) · `MEMORY.md` = como `develop` (el detalle;
  muta poco; tampoco fechas/estado *ni siquiera aquí*) · las memorias + `bitacora` + `estado-proyecto` = las
  ramitas (ahí vive TODO lo volátil: fechas, "RESUELTO 2026-…", historia, lápidas ⚰️). Así el `CLAUDE.md`
  **no se puede pudrir** → doc=realidad *por construcción*. En el **meta-repo** (cortex, cuya firma vive en el
  README y cuyo `.claude/memory/` no usa prefijos) el check NO es este detector sino
  `docs/flowcharts/verificar-arbol-sync.sh` (el bloque `ARBOL:START/END` cercado y sin fechas/RESUELTO/
  VERIFICADO); `verificar-firma-canonica.sh` auto-detecta el meta-repo y se salta (`n/a`).

## Cuándo usarlo
- Un cerebro instanciado no respeta la estructura: memorias sin prefijo, `CLAUDE.md` viejo, índice plano.
  **Córrele el detector primero** (`bash brain/verificar-firma-canonica.sh <ruta>`) — te lista el drift.
- Como el **paso ESTRUCTURAL (Fase 6 "la FIRMA")** dentro de [[consolidar-cerebro]]. Diferencia de roles:
  `consolidar-cerebro` es la campaña amplia (auditores + positivar + desinflar + converger); **este skill
  es solo la migración a la firma canónica**. Puede invocarse SOLO (drift puramente estructural) o como
  el cierre de aquella.
- Tras cambiar los guards/hooks del cerebro globalmente: la prosa del `CLAUDE.md` de los instanciados
  queda stale (nombra un hook retirado como `precompact-volcar-estado`) → canonizar la mata por construcción.

## LA CERCA (reglas duras — leer ANTES de tocar)
- **NO-DESTRUCTIVO por default.** Reprefijar/reescribir el índice/dedup-con-rescate SÍ. **Borrar
  conocimiento NO** — cualquier fusión rescata primero los datos únicos; lo que borraría información se
  **PARQUEA** con la pregunta redactada para unjordi.
- **`git mv`, nunca borrar-y-recrear.** Preserva la historia de cada memoria (blame/log siguen vivos).
- **Narrativa FECHADA intacta.** La `bitacora.md` y los "RESUELTO 2026-…" son historia legítima: se
  quedan. Se corrigen los punteros VIVOS (wikilinks/md-links a nombres viejos), no la historia.
- **FIDELIDAD — no inventes.** Sin pipelines/entornos/datos que el proyecto no tenga verificados
  (el barebones marca las secciones opcionales como "solo si el proyecto lo tiene DE VERDAD").
- **Aísla en worktree de feature** (o rama `chore/canonizar-cerebro`), commits granulares; el humano
  revisa el diff. Si el cerebro vive en folder no-git (Drive), snapshot `.bak` fuera del árbol sincronizado.
- **Doc=realidad:** el orden es SIEMPRE **leer el estado real → editar**, nunca al revés.

## Procedimiento (destilado del prototipo fluxcore)

### 0 · Inventario + foto del drift
- Enumera `.claude/memory/*.md` y `.claude/skills/`. Lee `CLAUDE.md`, `MEMORY.md`, `AGENTS.md` (si hay).
- **Corre el detector:** `bash brain/verificar-firma-canonica.sh <ruta-del-cerebro>` — te da la lista
  exacta de secciones ausentes, memorias sin prefijo, enlaces rotos y hooks retirados en la prosa.
- No canonices a ciegas: si el detector sale limpio (`0 fail · 0 warn`), **no re-trabajes** — declara sano.

### 1 · Clasifica cada memoria a un prefijo (o núcleo)
Por su **naturaleza dominante**: dominio/datos → `dom-`; correr-en-local/CI/deps/tooling/cerebro → `dev-`;
identidad/UI/componentes → `ux-`; hallazgos/planes de QA → `qa-`. Estado/backlog/bitácora/aprendizajes/
cómo-trabajar/hilo/cementerio → **núcleo** (sin prefijo). Si una cae en dos, gana la dominante.

### 2 · Reprefija con `git mv` (historia intacta)
`git mv .claude/memory/auth-y-tenancy.md .claude/memory/dom-auth-y-tenancy.md`. Renombra también al
**nombre canónico del núcleo** lo que esté con alias (p. ej. `estado-y-pendientes.md → estado-proyecto.md`).

### 3 · Dedup con RESCATE de datos únicos
Cuando dos memorias solapan, elige la CANÓNICA, **funde en ella los datos únicos de la otra** (rutas,
procedencias, valores irrepetibles), y `git rm` la fuente. Registra en el commit qué se rescató de dónde
(el prototipo: `proyecto-megaflux → dom-contexto-y-alcance` rescató ruta GitLab + procedencia del prefijo;
`recursos-marca → ux-identidad-de-marca` rescató Pantone + PDF + stock). Nunca `git rm` sin rescatar antes.

### 4 · Reescribe `CLAUDE.md` a la firma-árbol
Sigue la secuencia obligatoria. El **árbol va DENTRO de un bloque cercado** ``` (si no, colapsa a prosa
en todo render). En el árbol, **nombra los guards BREVE** (`git-branch-guard, merge-squash-guard, …`) —
esto **mata la prosa de guards stale por construcción** (el `CLAUDE.md` viejo describía `precompact-volcar-estado`
en prosa; el árbol no lo nombra → desaparece). ATEMPORAL: sin fechas ni estado. La arquitectura NO va
aquí: apunta a `AGENTS.md` si existe.

**Si NO hay `CLAUDE.md` aún — destilar el TOC de cero.** El caso común: `cps` y `cortex` no tienen `CLAUDE.md`;
su misión vive implícita/mezclada dentro del entry-point operativo. No lo inventes: **destílalo clasificando
cada línea del entry-point por su NATURALEZA DOMINANTE**, en TRES clases:
- **CAPACIDAD** — algo que Claude **hace/opera** (un skill, una rutina, un guard, una tarea) → al TOC.
- **NORMA de CRITERIO/CONDUCTA** — cómo se trabaja aquí (reglas de estilo, "cómo NO trabajar",
  `como-trabajar-<user>`) → también al TOC (es firma: gobierna la operación), como su propia sección.
- **CONOCIMIENTO / estado / historia / dominio** — una decisión, un dato, una lección → se QUEDA en el detalle.

Cuando una línea tiene de varias, gana la **DOMINANTE**; si su método vive en 2 lados (un skill + un doc-método),
el TOC lleva un **puntero COMPUESTO** (`capacidad → skill + doc`). El `CLAUDE.md` resultante es thin (~5-8
líneas + secciones); NO duplica: el TOC apunta, el detalle vive abajo una sola vez.
- **MAPA DE FUENTES (no todo vive en el entry-point).** Las tres clases se surten de lugares distintos, y en un
  cerebro **meta** el índice puede ser CONOCIMIENTO puro (índice de memorias sin router) → el TOC saldría vacío
  si solo miraras ahí. Surte cada clase de su fuente real: **CAPACIDAD ← `.claude/skills/`** (enumera los dirs,
  N=N) **+** rutinas/guards activos; **NORMA de CONDUCTA ← los docs de criterio/estilo**; **MISIÓN ←
  `README.md`/el producto** (en un repo-template, leído read-only); **CONOCIMIENTO ← las memorias** (se queda).
  El TOC es la UNIÓN de esas fuentes, no un filtro del índice.
- **Interacción firma ↔ `sesion-inicio`:** crear un `CLAUDE.md` nuevo puede solapar lo que el hook
  `sesion-inicio` ya reinyecta al arranque (rama, norma de git, orden de leer el índice) — que el `CLAUDE.md`
  NO lo duplique; si hay que reordenar el hook, se PARQUEA para el humano (es tocar un guard).
- **AGENTS pesado que MEZCLA** (cps: 3194 líneas con arquitectura + git-flow + workflow + scripts): lo que ahí
  sea **proceso/capacidad** (no arquitectura) se **enlaza HACIA la firma** (o se dedupea si ya vive en un skill),
  dejando en `AGENTS.md` solo la arquitectura real. Separa por CONTENIDO, no por sección.
- **Alinea el entry-point operativo** para que su índice tenga exactamente las capacidades que el TOC declara,
  en ese orden (si sobra una fuera del mapa: se enlaza o se añade al TOC). El doc de arquitectura, si existe
  aparte, se deja en su carril y no se fuerza a la forma de la firma.

### 5 · Reescribe `MEMORY.md` a índice-por-prefijo
Encabezado + `## 📍 Dónde estamos` (hilo + estado-proyecto) + una `##` por prefijo (🧭 núcleo · 🗄️ dom- ·
🛠️ dev- · 🎨 ux- · ✅ qa-), en el ORDEN del folder. Cada bullet: `[Título](archivo.md) — respuesta + ESTADO`.
Sin fechas/estado en la estructura (gradiente: MEMORY = como `develop`). Sin secciones inventadas.

### 6 · Arregla los punteros vivos
`grep` por TODO el cerebro los nombres viejos: wikilinks `[[nombre-viejo]]` y md-links `](nombre-viejo.md)`
→ actualízalos al nuevo nombre. Una sola copia desincronizada ya es doc que miente.

### 7 · VERIFICA el 1:1 (el gate)
`bash brain/verificar-firma-canonica.sh <ruta>` debe salir **`0 fail`** (usa `--strict` para exigir también
0 WARN). Confirma: MEMORY ↔ archivos 1:1, cero enlaces rotos, CLAUDE.md con todas las secciones y sin
hooks retirados en la prosa, `@import` resuelve. Ese detector ES el mecanismo que hace cumplir esta norma.

## El detector (mecanismo — la norma nace con él)
`brain/verificar-firma-canonica.sh [ruta] [--strict]` es el chequeo determinista que FLAGGEA el drift:
secciones de la firma ausentes en `CLAUDE.md`, memorias sin prefijo `dom-/dev-/ux-/qa-`/núcleo, el
invariante MEMORY↔archivos roto (huérfanas + enlaces rotos), y nombres de hook retirados en la prosa.
FAIL (estructural) = exit 1; WARN (drift menor) se reporta y `--strict` lo eleva a exit 1. **Alimenta el
GATE del auditor (#44):** el auditor de coherencia corre este detector como sub-check determinista y, en
modo gate, `--strict` bloquea un release si un cerebro instanciado drifteó. Tiene su batería en
`brain/test-brain.sh` (bloque `g5`: cerebro bueno/malo/no-indexado/local/strict/meta-repo).

## LISTO (no lo saltes)
Canonizar + detector en verde es **verificado técnicamente**, NO LISTO. El sello es el **QA/OK de
unjordi** (definición mutua de LISTO). Lo parqueado (fusiones que borrarían conocimiento, dudas de
clasificación) queda VISIBLE en `estado-proyecto.md` — ningún hallazgo se queda solo en el chat.

## Familia
- Es el paso ESTRUCTURAL de [[consolidar-cerebro]] (que además positiva/desinfla/converge). Distínguelo:
  consolidar = campaña amplia; canonizar = migración a la firma.
- Hermano de [[auditar-coherencia-cerebro]] (que puede correr el detector como sub-check) y de
  [[desinflar-memorias]]/[[positivar-doc]] (higiene de CONTENIDO, ortogonal a la ESTRUCTURA de este skill).
- El flujo de integración (ramita → MR → develop con `--squash`, OK explícito): [[cerrar-slice]].
