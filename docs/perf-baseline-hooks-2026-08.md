# Baseline de rendimiento de los hooks del cerebro (cortex) — 2026-08-21

> **Turno nocturno de optimización** (rama `optimizar-cortex`). Objetivo: agilizar los jueces / el
> modelo de capas / y todo lo posible **sin perder funcionalidad** ni debilitar guards. Este doc registra
> lo que se MIDIÓ (no se adivinó) y la conclusión honesta.

## TL;DR (medido, no supuesto)
1. **Los hooks del cortex NO son el cuello de botella del downtime.** El peaje TOTAL de los ~9 guards
   PreToolUse/Bash es **~16–28 ms por comando** (tras esta pasada, ~16 ms). Es **ruido** frente a la
   inferencia del modelo (cientos de ms–segundos por round-trip del loop agéntico).
2. **El juez de merge YA está bien optimizado.** Contra el supuesto de la síntesis ("los guards levantan
   un `claude` entero"), la realidad del código (`juez-comun.sh` + `confirmar-merge-develop.sh`):
   - **curl DIRECTO** a `api.anthropic.com/v1/messages` con token OAuth — NO spawnea un CLI. La
     "invocación directa a endpoints" que la síntesis proponía como la mayor ganancia **ya está hecha**.
   - **Modelo Haiku** (`claude-haiku-4-5`) — ya es el más rápido.
   - **Capas deterministas** ya presentes: piso barato (sin línea `USUARIO:` → DENY sin gastar el LLM),
     resolución determinista de destino/scope (repo-compartido, `acg_destino_de_mr` cacheado), fast-path
     de grant durable (turno-nocturno), piso de main, veto de cita determinista.
3. **Por eso NO se reescribió la lógica del juez** por el falso-negativo de esta noche: la norma es
   afinar guards **con corpus (~5 casos del mismo guard), no con la anécdota de una noche**. El FN quedó
   registrado en `~/.claude/memory/guards-falsos-positivos.md`.

## Metodología
Profiler (`scratchpad/prof-hooks.sh`): alimenta a cada guard un input sintético de PreToolUse/Bash
(`{"tool_name":"Bash","tool_input":{"command":"<cmd>"}, ...}`) y cronometra con `date +%s%N`, 5 corridas,
se toma el **mínimo** (descarta ruido del scheduler). Dos comandos: benigno (`ls -la`, camino común) y
`git push` (ejercita más lógica). Verificación de no-regresión: `brain/test-brain.sh` (696 tests).

## Datos — peaje por comando (camino común, `ls -la`, min de 5)
| Hook | antes (ms) | después (ms) | nota |
|---|---|---|---|
| git-branch-guard | 2 | 2 | ya mínimo |
| secret-scan | 2 | 2 | ya mínimo |
| merge-squash-guard | 1 | 1 | ya mínimo |
| confirmar-merge-develop | 2 | 2 | early-exit rápido en no-merge |
| **no-bypass-deploy** | **9** | **3** | ← pre-filtro barato añadido |
| **proteger-arbol** | **5** | **3–4** | ← pre-filtro barato añadido |
| proteger-fuente-cerebro | 3 | 3 | — |
| entorno-maquina-guard | 1 | 1 | ya mínimo |
| limite-gasto | 3 | 3 | — |
| **SUMA** | **~28** | **~16** | ~43% menos, funcionalidad intacta |

## Qué se cambió (seguro, mecánico, verificado)
El principio del **modelo de capas aplicado al nivel del hook**: un **filtro determinista barato PRIMERO**
(en-proceso, sin subprocesos) que hace early-exit en el camino común, ANTES de gastar sed/tr/grep.
- `no-bypass-deploy.sh`: `case "$cmd" in *install*|*deploy*|*publish*|*make*|*just*) ;; *) exit 0 ;; esac`
  (con `nocasematch`). Solo continúa si el comando menciona un gatillo posible. Conservador (filtra el
  cmd crudo = superset; nunca salta un caso real). 9→3 ms.
- `proteger-arbol.sh`: `case "$cmd" in *git*) ;; *) exit 0 ;; esac`. Todo lo que vigila contiene 'git'.
  5→3 ms.

Ambos son hooks **ADVISORY** (additionalContext, no bloquean) → riesgo mínimo, y `test-brain` (696)
sigue verde → conducta idéntica.

## El costo de fondo que NO se resuelve en cortex (→ axon)
El peaje restante (~16 ms) es dominado por **~9 procesos `bash` + `jq` arrancados de cero por CADA
comando** (cada hook parsea el mismo JSON independientemente). Reducir ESO exige un **despachador nativo
que parsee una vez y evalúe las reglas en-proceso** — es justamente el punto **"hooks híbridos nativos"**
del proyecto `axon` (harness), NO un cambio de cortex. Y aun así, ~16 ms es imperceptible frente a la
inferencia.

## Conclusión para el proyecto axon (harness)
La instrumentación de esta noche **corrige el supuesto** del roadmap: el downtime NO está en los hooks
del cortex ni en un juez que "spawnea un claude". Está donde la síntesis (05 §7) siempre apuntó pero por
otras razones: **generación de tokens + round-trips del loop agéntico + tamaño de contexto (prompt
processing)**. El paso #1 del roadmap de axon (**instrumentar EL LOOP**, no los hooks) es donde vive la
medición que importa. Los hooks ya están afilados.
