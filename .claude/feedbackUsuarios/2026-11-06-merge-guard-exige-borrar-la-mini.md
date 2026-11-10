# merge-develop-guard exige borrar la rama de origen aunque sea la mini-develop

**De:** claudio-master · **Pedido de unjordi (2026-11-06):** «eso ya debería estar corregido en el guard O tuvo regresión. revisa el historial de commits del guard».

## Diagnóstico (medido)
- `brain/hooks/merge-develop-guard.sh`, paso 3a (aprox. líneas 426-438): con destino = develop exige `--remove-source-branch` (glab) o `--delete-branch` (gh) **sin mirar la rama de origen**.
- **No es regresión.** Ninguna versión del guard tuvo una excepción por origen. Revisé #435, #438, #465, #470, `d1de05fa` y `2fe7463f`: siempre la exigen.
- Frecuencia: según unjordi, ha pasado muchas veces (la bitácora solo registró algunas). Casos en `docs/guards-falsos-positivos.md`:
  - 2026-10-14: arsenal, PR DevelopUnjordi → develop. Se rodeó cortando `release/…` desde la mini; no se abrió arreglo.
  - 2026-11-06: saeWebapi !13, origen DevelopUnjordi.
- Riesgo real: quien obedece al guard le pide al forge borrar su mini. GitLab no borra ramas protegidas, así que DevelopUnjordi sobrevivió en saeWebapi (verificado con `git ls-remote`). Pero en un repo donde la mini NO esté protegida (GitHub sin Pro, p. ej. PowerScripts), el flag sí la borraría.

## Arreglo de precisión que propongo
Exigir el borrado solo si la rama de origen **no** es una rama de integración personal:
- Origen = `Develop<Usuario>` (convención del modelo mini-develop), `integracion/*` o `epic/*` (las «minis de tema» del CLAUDE.md) → no se exige `--remove-source-branch`/`--delete-branch`. Mejor aún, **se frena** si viene puesto, con un mensaje que diga que esa rama no se borra.
- El origen sale de la misma consulta que ya resuelve el destino (`glab mr view --output json` → `source_branch`; `gh pr view --json headRefName`). Si el origen es irresoluble, se mantiene la exigencia actual (fail-safe).
- Actualizar el texto de `_rehaz_sugerido` y el mensaje del deny, que hoy dicen «a tus ramas personales no se te exige nada», cosa que solo es cierta cuando la rama personal es el DESTINO.

## Prueba que debe acompañarlo (falla contra el código actual)
1. MR DevelopUnjordi → develop **sin** `--remove-source-branch` → pasa el chequeo de squash (hoy: DENY).
2. MR DevelopUnjordi → develop **con** `--remove-source-branch` → DENY con «la mini no se borra».
3. MR `feat/x` → develop sin el flag → DENY como hoy. Es la otra dirección: la regla sigue viva para las ramitas.
4. Origen irresoluble (mock de glab vacío) → se exige el flag, como hoy.
