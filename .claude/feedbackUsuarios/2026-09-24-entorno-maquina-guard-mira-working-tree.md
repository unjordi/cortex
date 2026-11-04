# Feedback: `entorno-maquina-guard` escanea el WORKING TREE, no lo que ENTRA al commit

**Fecha:** 2026-09-24 · **De dónde salió:** sesión `claudio-master` (plantilladotnet), varios commits de esta tanda.
**A quién le toca:** cortex-master (hook `entorno-maquina-guard`).

> ⚠️ Esto es mi diagnóstico **DE CONTEXTO** (lo que vi disparar en esta y sesiones previas), **NO verificado contra el código del hook** — no lo abrí. Trátalo como hipótesis a confirmar, no como hecho.

## Síntoma (4 ocurrencias idénticas, registradas)
El guard dispara "contenido machine-specific (Rosetta sin condicional) en `.claude/memory/estado-proyecto.md`" en commits que **NO tocan ese archivo**. Hoy disparó en un commit que solo **borraba 3 líneas** de otra sección de ese archivo; antes (2026-09-16, 2026-09-17 ×2) en commits que tocaban solo `scripts/` o `wg-megaflux.md`. El archivo con "Rosetta" está en el working tree pero **no entra al commit**.

## Diagnóstico (mi hipótesis, sin abrir el código)
Mira el **WORKING TREE completo** (o todos los archivos presentes) en vez de **solo lo que ENTRA al commit** (lo *staged*: `git diff --cached`) o al push (vs upstream/merge-base). Es el mismo defecto de clase que aqueja a la familia de guards: razonar sobre el **AMBIENTE** en vez del **SCOPE AUTORITATIVO** de la acción — hermano del `acg_target_dir` de `merge-develop-guard` (que resuelve el repo del *cwd*, no del `--repo`).

## Dirección del fix (de contexto)
Alinearlo con **`secret-scan`**, que según el `CLAUDE.md` global ya lo hace bien: *"Escanea solo lo AGREGADO (staging en commit; vs upstream/merge-base en push)"*. `entorno-maquina-guard` debería escanear el mismo conjunto (lo agregado), no el working tree.

## Referencia (para no escarbar)
Las 4 ocurrencias con su comando citado y por qué cada una fue falso positivo están en el corpus:
**`/Users/unjordi/code/cortex/docs/guards-falsos-positivos.md`** (busca `entorno-maquina-guard`). Ya en el umbral de ~5 → candidato a una pasada de tuning de precisión (cada fix nace con su test).
