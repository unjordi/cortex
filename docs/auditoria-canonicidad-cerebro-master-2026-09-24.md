# Auditoría de canonicidad del cerebro de `cortex-master` — 2026-09-24

> Auditor READ-ONLY (no mutó nada). Objeto: `~/code/cortex/CLAUDE.md` + `.claude/memory/` (MEMORY.md + 23 memorias + 3 `.local.md` + 3 subdirs) + `.claude/skills/` (4). Contexto: tras la mudanza del master de `plantilladotnet` a `cortex` (skill `reubicar-master`) + la consolidación #453/#455/#456. Vara: skill `canonizar-cerebro` (firma canónica) y `auditar-coherencia-cerebro` (método). Referencia de forma: `cps`.

## Veredicto (una línea)
**Canónico en lo esencial — SÍ, con reservas: el sistema RESISTE (0 CRÍTICO), pero quedan 2 ALTO + 2 MEDIO que impiden declararlo "bonito y canónico" del todo.** Conteo: **0 CRÍTICO · 2 ALTO · 2 MEDIO · 3 LOW/aceptados.**

Nota de encuadre importante: **`cortex` es el META-repo**, no un cerebro instanciado. Su firma vive en el `README.md` + un `CLAUDE.md`-firma; su `.claude/memory/` **NO usa prefijos** `dom-/dev-/ux-/qa-`; y su check canónico NO es `verificar-firma-canonica.sh` (que auto-detecta el meta-repo y devuelve `n/a` — verificado en runtime) sino `docs/flowcharts/verificar-arbol-sync.sh`. Por eso NO se le aplica la vara de `cps` al pie de la letra: la comparación de forma con `cps` es orientativa, no normativa. Consecuencia clave del encuadre: **el meta-repo NO tiene un mecanismo que haga cumplir el invariante 1:1 MEMORY↔archivos ni la ausencia de hooks retirados en la prosa** (esos los verifica `verificar-firma-canonica.sh`, que aquí se salta) → esos dos huecos se acumulan en silencio. Ambos ALTO de abajo caen justo ahí.

---

## Hallazgos priorizados

### ALTO-1 · La firma (`CLAUDE.md`) nombra DOS hooks RETIRADOS como si estuvieran vivos
- **Qué:** `CLAUDE.md:60` (Reglas duras → Flujo de git) dice: *"Lo hacen cumplir git-branch-guard + **merge-squash-guard** + **confirmar-merge-develop**."* Esos dos hooks fueron **CONSOLIDADOS en `merge-develop-guard` el 2026-09-17** y ya no existen como archivos.
- **Prueba (CONFIRMADO):**
  - `brain/hooks/MANIFEST:93` → `merge-squash-guard  retirado  ... CONSOLIDADO en merge-develop-guard`
  - `brain/hooks/MANIFEST:94` → `confirmar-merge-develop  retirado  ... CONSOLIDADO en merge-develop-guard`
  - `brain/hooks/MANIFEST:54` → `merge-develop-guard  both  hook` (el vivo)
  - `brain/hooks/` solo contiene `merge-develop-guard.sh` (los dos retirados no tienen archivo).
  - `MEMORY.md` sí usa el nombre correcto (`merge-develop-guard`, líneas 88/146/152) y explica la fusión — **es solo el `CLAUDE.md` el que quedó stale.**
- **Por qué importa:** `CLAUDE.md` es LA firma / entry-point atemporal; nombrar hooks retirados es exactamente el "doc que miente" que `canonizar-cerebro §4` promete matar por construcción. No lo cazó ningún mecanismo porque el check del meta-repo (`verificar-arbol-sync.sh`) valida la paridad del ÁRBOL (README↔MEMORY↔MANIFEST↔widgets) pero **no escanea la prosa de Reglas duras del `CLAUDE.md`**.
- **Recomendación:** en `CLAUDE.md:60`, sustituir `merge-squash-guard + confirmar-merge-develop` por `merge-develop-guard` (queda `git-branch-guard + merge-develop-guard`). Fix de una línea.

### ALTO-2 · `MEMORY.md` NO es 1:1 — 9 memorias INALCANZABLES (el criterio "sin memorias inalcanzables" del dueño)
- **Qué:** 9 memorias existen en `.claude/memory/` pero su nombre no aparece en ningún lado de `MEMORY.md` → nadie que lea el índice las encuentra. (El índice "📚 Conocimiento de desarrollo", `MEMORY.md:189-203`, solo cataloga ~12 memorias de desarrollo + el núcleo referenciado arriba.)
- **Prueba (CONFIRMADO, por presencia del nombre en `MEMORY.md`):** lista completa en la sección "Inalcanzables" abajo.
- **Por qué importa:** es el criterio TEXTUAL del dueño. En un cerebro instanciado esto lo cazaría `verificar-firma-canonica.sh`; en el meta-repo **no hay check que lo enforce**, así que crece solo. Matiz honesto: ~la mitad son artefactos históricos fechados (auditorías, subdirs de dogfood/jueces) o scratch transitorio (`hilo-mental-overflow`), defendibles de dejar o archivar; pero `bitacora.md` (memoria NÚCLEO — en `cps` sí se indexa), `handoff-dogfood-cerebro.md` (además STALE, ver MEDIO-1), `plan-molde-estado-proyecto.md` y `propuesta-aliases-cross-shell.md` son memorias vivas/de-referencia que deberían estar indexadas o archivadas con lápida.
- **Recomendación:** (a) indexar `bitacora.md` en el núcleo de `MEMORY.md` (como hace `cps`); (b) indexar `plan-molde-estado-proyecto.md` (es el plan de 4 fases citado por el EPIC `#85-#88` en `estado-proyecto.md:90`) y `propuesta-aliases-cross-shell.md`; (c) para las auditorías fechadas y los subdirs (`dogfood-coherencia-2026-08-07/`, `juez-veto-fix/`) decidir: indexarlas como "registro histórico" o moverlas a un `docs/archivo/`; (d) considerar añadir el 1:1 de memorias al `verificar-arbol-sync.sh` para que el meta-repo también enforce este invariante (norma nace con su mecanismo).

### MEDIO-1 · `handoff-dogfood-cerebro.md` está SUPERSEDED (describe una mudanza ya hecha) y encima es inalcanzable
- **Qué:** es el plan-handoff para MUDAR el master de `plantilladotnet` a su slug — la mudanza que YA se ejecutó. Su gemelo vigente y canónico es `plan-mudanza-cortex-master.md` (ese SÍ está indexado, `MEMORY.md:199`).
- **Prueba (CONFIRMADO):** `handoff-dogfood-cerebro.md:1` *"Handoff al gemelo — MUDAR la sesión claude-brain-master a su slug + REORGANIZAR"*; `:14` *"nació con cwd `~/code/plantilladotnet` y mantiene claude-brain DESDE ahí"* (ya no: corre desde `cortex`). No referenciado en `MEMORY.md`.
- **Recomendación:** archivar (cementerio con `🪦#` + ref, o `docs/archivo/`) o, si se conserva como registro, marcarlo `⚰️ SUPERSEDED por plan-mudanza-cortex-master.md` e indexarlo así. No dejarlo como memoria viva suelta.

### MEDIO-2 · `plan-molde-cerebros.md` afirma en presente algo que la mudanza volvió falso
- **Qué:** `plan-molde-cerebros.md:27` (sección "Repos OUT") dice *"**`plantilladotnet`** — es la plantilla .NET *y* la base donde corro. NO tocar."* Tras la mudanza, "la base donde corro" es `cortex`, no `plantilladotnet`. La misma sección lista *"Ya rehechos: … claude-brain"* con la identidad vieja.
- **Prueba (CONFIRMADO):** `plan-molde-cerebros.md:22-27`. Es un plan INDEXADO (`MEMORY.md:197`, "listo para aplicar … ejecutar cuando se pida") → una afirmación en presente falsa en una memoria viva.
- **Recomendación:** actualizar la línea 27 a reflejar que el master corre desde `cortex` (o marcar el plan como snapshot fechado 2026-08-03 si se congela). doc=realidad.

---

## Listas explícitas

### Memorias INALCANZABLES (existen, sin entrada en `MEMORY.md`)
1. `bitacora.md` — **núcleo**, journal append-only (en `cps` sí se indexa).
2. `handoff-dogfood-cerebro.md` — además STALE (MEDIO-1).
3. `hilo-mental-overflow.md` — overflow del hilo (scratch transitorio T2; defendible no-indexar).
4. `plan-molde-estado-proyecto.md` — plan de 4 fases citado por `estado-proyecto.md:90` (EPIC #85-#88).
5. `propuesta-aliases-cross-shell.md` — propuesta.
6. `auditoria-continuidad-hilo-2026-09-09.md` — auditoría fechada (artefacto histórico).
7. `auditoria-redundancias-cortex-2026-09-09.md` — auditoría fechada (artefacto histórico).
8. `dogfood-coherencia-2026-08-07/` (subdir: HALLAZGOS + 3 INFORME-*) — artefactos fechados.
9. `juez-veto-fix/` (subdir: CONTEXTO + 4 INFORME/PLAN/PREDIAGNOSTICO) — artefactos fechados.

### Memorias COLGANTES (entrada en el índice → archivo inexistente)
**NINGUNA.** Los 13 md-links de `MEMORY.md` resuelven a archivos reales.

### Links internos rotos
**NINGUNO.** Los `[[wikilinks]]` en `MEMORY.md`: no hay (solo un falso positivo `[[:upper:]]` de una clase de regex en prosa). Los md-links resuelven todos.

### Residuo de la mudanza
- **Sin fuga del PRODUCTO ajeno (.NET):** no hay memorias de la plantilla .NET en el cerebro de `cortex`. Todas las menciones a `plantilladotnet` son (a) narrativa FECHADA legítima en `bitacora.md`/subdirs de jueces (la Cerca la conserva), (b) el propio `plan-mudanza-cortex-master.md` (es SOBRE la mudanza), o (c) rutas de transcript histórico en `juez-empoderamiento.md`. Excepciones vivas ya cubiertas en MEDIO-1/MEDIO-2.
- **Las 4 memorias T1 que trajo la mudanza SÍ están y SÍ indexadas:** `diseno-unificar-cerebro` (`MEMORY.md:198`), `handoff-peer-claudes-conciso` (:196), `plan-molde-cerebros` (:197), `plan-mudanza-cortex-master` (:199). Migración limpia en este eje.

### Identidad T2 (el hueco del `CLAUDE.local.md`) — RESUELTO, no es hueco
- La ausencia de `CLAUDE.local.md` (raíz o `.claude/`) es **ESPERADA y documentada**: `reubicar-master:630-631` dice textual que *"`$T2_ROOT` puede NO existir en ninguno de los dos extremos (hoy, `CLAUDE.local.md` no existe ni en `plantilladotnet` ni en `cortex`)"* y todo el andamiaje T2 lo trata como opcional.
- La identidad T2 **vive legítimamente en otro canal:** `conocimiento-propio.local.md` (existe, actualizado 2026-09-22) — el "quién eres aquí" del master —, junto con `autorizaciones-vigentes.local.md`. Ambos son `.local.md` gitignored per-máquina y correctamente **NO indexados** en `MEMORY.md` (su propio frontmatter lo declara). El hook `aviso-drift-cerebro` los re-inyecta en cada SessionStart.
- **Seguridad verificada (cortex es PÚBLICO, `isPrivate=false`):** `git check-ignore` confirma los 3 `.local.md` ignorados y `git ls-files` los da como NO trackeados → sin fuga de identidad/autorizaciones.

---

## Qué SÍ quedó bien (el cerebro resiste)
- **`CLAUDE.md` = firma-árbol canónica:** secuencia obligatoria completa (🎯 Misión → 🧠 Antes de construir → 📁 Dónde va cada cosa → 🖋️ FIRMA dentro de bloque cercado → 🛡️ Reglas duras → `@import MEMORY.md`), atemporal, adaptada al meta-repo. Único defecto: ALTO-1.
- **Check del meta-repo VERDE:** `verificar-arbol-sync.sh` → `README ↔ MEMORY.md ↔ brain/skills/ ↔ brain/hooks/MANIFEST en paridad · árbol cercado y atemporal` (21 skills, 19 hooks vivos, cuadran en los 4 catálogos).
- **Consolidación #453/#455/#456 EXITOSA:** `estado-proyecto.md:18` confirma que los 3 backlogs (`estado-proyecto.md` + `backlog-desarrollo.md` + `BACKLOG-UNIFICADO.md`) se fundieron; los dos archivos absorbidos **ya no existen** en `.claude/memory/` → **cero backlog duplicado**.
- **0 memorias colgantes, 0 links rotos.**
- **Identidad T2 sana + gitignore a prueba de fuga** (ver arriba).
- **Sin residuo del producto .NET** en el cerebro (ver arriba).

## Fuera de alcance (ya en backlog, no es del cerebro-memoria)
- Los 3 widgets (`macos/`/`windows/`/`src/`) muestran 5 skills RETIRADOS como vivos (25 nombres vs 21 skills) — ya está capturado como pendiente en `estado-proyecto.md:135` (detectado por la DUPLA, 2026-09-18). Es del código de los widgets, no de la canonicidad del cerebro.

## Declaración de método
Individual→colectivo, todo verificado por lectura/ejecución (CONFIRMADO, no PLAUSIBLE). El sistema RESISTE: no se fabricó ningún CRÍTICO. Los 2 ALTO son huecos reales del criterio del dueño ("sin memorias inalcanzables" + doc=realidad en la firma), ambos de fix barato y localizado; ninguno bloquea revivir el master, pero atenderlos es lo que falta para "bonito y canónico" pleno.
