# INFORME — Auditoría de COHERENCIA (FLOWCHARTS + NORMAS + DOC)

> Auditor READ-ONLY. Repo real auditado: `/Users/unjordi/code/claude-brain` (rama
> `chore/skill-to-do-y-desinflador`, HEAD 3ef36b9, ~2026-08-06). El worktree stale
> `plantilladotnet/.claude/worktrees/agent-a6a3a4f873c31dd4e/cb` (feat/cerebro-multi-agente-grok,
> 27-jul) NO es la fuente viva → descartado.
> **Nada aquí es "listo"; es INSUMO para decisión + QA de unjordi. No toqué nada.**

## Conteo por severidad
- ALTO: 0
- MEDIO: 2
- BAJO: 3

---

## El estado REAL del set de flowcharts (corrige la premisa del encargo)

La premisa "solo 01/02 se reconciliaron en #208; los otros ~9 sin leyenda/fuente" está **OBSOLETA**.
Hoy hay **DOS series solapadas** en `docs/flowcharts/`:

**Serie CANÓNICA (git-tracked, .dot + leyenda, al día)** — 5 charts:
`01-instalacion`, `02-ciclo-de-vida`, `03-enforcement-git-guards`, `04-delegacion-orquestar-fanout`,
`05-continuidad`. Las 5 tienen `.dot` versionado + leyenda-árbol incrustada + citan hooks actuales
(`proteger-fuente-cerebro`, `exportar-sesion-master`). `03-enforcement.dot` nombra los 8 pre-hooks +
aviso-contexto = el fan-out de 9 de CONVENCIONES §6 (coherente con MANIFEST/install-brain).

**Serie VIEJA (los "9" del encargo) = HUÉRFANOS gitignored** — NO git-tracked, `git check-ignore`
confirma que las 9 están ignoradas (catch-all `docs/flowcharts/*` sin línea `!`). Son restos del
esquema de numeración anterior; NINGUNA tiene `.dot`. Chocan por número con la serie canónica
(hay DOS 03, DOS 04, DOS 05 con títulos distintos en el mismo folder).

### Los 9 flowcharts (leyenda / fuente .dot):
| # | chart | leyenda | .dot | git-tracked |
|---|---|---|---|---|
| 03 | integrar-rama-a-developmain | ❌ | ❌ | ❌ ignored |
| 04 | comando-git-en-bash-guards | ✅ | ❌ | ❌ ignored |
| 05 | al-hacer-push-nudges | ✅ | ❌ | ❌ ignored |
| 06 | declarar-listo-al-fin-de-turno | ❌ | ❌ | ❌ ignored |
| 07 | cerrar-un-slice-ritual | ❌ | ❌ | ❌ ignored |
| 08 | delegar-un-taskagente | ❌ | ❌ | ❌ ignored |
| 09 | orquestar-un-fan-out-sin-ninera | ✅ | ❌ | ❌ ignored |
| 10 | normas-el-cimiento | ✅ | ❌ | ❌ ignored |
| 11 | referencia-libskill-de-stack | ❌ | ❌ | ❌ ignored |

Resumen: **0/9 con fuente `.dot`; leyenda en 4/9 (04, 05, 09, 10), ausente en 5/9 (03, 06, 07, 08, 11).**

---

## Hallazgos

### [MEDIO] M1 · Serie VIEJA de 9 SVGs = huérfanos gitignored que colisionan con la canónica
`docs/flowcharts/{03-integrar-rama, 04-comando-git-en-bash-guards, 05-al-hacer-push-nudges,
06-declarar-listo, 07-cerrar-un-slice, 08-delegar-un-taskagente, 09-orquestar-un-fan-out,
10-normas-el-cimiento, 11-referencia-libskill}.svg`. Están en disco pero gitignorados (no viajan);
son la numeración VIEJA superada por la serie canónica de 5. Cualquiera que abra `docs/flowcharts/`
ve DOS 03 / DOS 04 / DOS 05 con títulos distintos → exactamente el "doc que confunde" que CONVENCIONES.md
quiso eliminar. Además 0/9 tienen `.dot` y 5/9 no tienen leyenda (violan la regla dura de `diagramar`).
Fix sugerido: BORRAR los 9 SVGs huérfanos del working tree (no ship, pero contaminan la vista local).

### [MEDIO] M2 · `docs/mapa-cerebro.md` §4 (tiers) OMITE 3 hooks `global` que sí están en el MANIFEST
`docs/mapa-cerebro.md:~187` (nodo `GLOBAL` del mermaid de tiers) lista solo proteger-arbol · rama-vieja ·
limite-gasto · rehidratar-hilo · aviso-contexto · aviso-drift-cerebro · delegacion-{gate,registrar,reporte}.
**Faltan** `proteger-fuente-cerebro` (hook nuevo, 06-ago), `exportar-sesion-master` y `barrer-ramas`
— los tres declarados `global hook` en `brain/hooks/MANIFEST`. El propio mapa dice "fuente única =
MANIFEST" y "si agregas/quitas un hook, ACTUALIZA este mapa" (`mapa-cerebro.md:~44-46`) → doc=realidad
violado por su propia regla. (Las 5 `.dot` canónicas SÍ citan proteger-fuente-cerebro/exportar-sesion-master;
solo el mapa mermaid quedó atrás.)

### [BAJO] B1 · README.md omite el skill nuevo `to-do` del árbol 💡 Skills
`README.md:115-135` lista 18 skills pero NO `to-do` (skill agregada en esta misma rama, 06-ago,
`brain/skills/to-do/`). El árbol de skills del README miente por omisión.

### [BAJO] B2 · `.claude/memory/MEMORY.md` no menciona el hook `exportar-sesion-master`
Único hook del MANIFEST ausente de MEMORY.md. Menor (MEMORY no es inventario exhaustivo de hooks),
pero es el mismo hook que también falta en el mapa (M2) → señal de que `exportar-sesion-master` quedó
sub-documentado en toda la capa doc.

### [BAJO] B3 · `proteger-fuente-cerebro` (hook nuevo) no aparece en `brain/norms/global-claude-md.md`
La norma "Integridad de los guardarraíles" (`global-claude-md.md:93-101`) dice que el backstop de
"no editar la fuente del cerebro" es "el clasificador auto-mode externo". Ya existe un hook in-repo
(`proteger-fuente-cerebro`, AVISA al editar la copia instalada) que cubre parte de eso; la norma no lo
cita. No es contradicción dura (el hook avisa, no bloquea), pero la norma quedó atrás del mecanismo.

---

## Coherencia norma ↔ guard (sin hallazgos duros)
Los guards citados por las normas (`dod-verificar`, `confirmar-merge-develop`, `merge-squash-guard`,
`git-branch-guard`, `proteger-arbol`, `entorno-maquina-guard`, `delegacion-gate`) TODOS existen en
`brain/hooks/`. No se hallaron contradicciones ENTRE normas ni normas describiendo reglas que el guard
ya no aplica (dentro de esta dimensión; la verificación fina de LÓGICA de cada guard es de la dimensión
GUARDS, no de ésta).

## Nota sobre docs de auditoría histórica
`docs/auditoria-flowcharts.md` (2026-07-14) audita el `docs/mapa-flujos.dot` YA RETIRADO (README:158,
retirado 2026-07-29). Es doc de record histórico; no pretende reflejar el estado actual (su header lo
fecha), así que no cuenta como "doc que miente", pero conviene marcarlo como ARCHIVO/histórico para que
un lector nuevo no lo tome por vigente.
