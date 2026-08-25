# INFORME de coherencia — GUARDS + LIB del cerebro (claude-brain)

Auditor READ-ONLY. Alcance: `~/code/claude-brain/brain/hooks/*.sh` + `analizar-comando-git.sh` + `MANIFEST` + `test-brain.sh`. Fecha: 2026-08-07. NO se tocó nada.

Resumen de conteo: **1 ALTO · 2 MEDIO · 4 BAJO**.

Lo que SÍ quedó coherente (verificado): el MANIFEST cuadra 1:1 con los `.sh` presentes (0 huérfanos, 0 faltantes); la cláusula de dedupe doble-cableado está en EXACTAMENTE los 6 hooks tier `both` (git-branch-guard, merge-squash-guard, confirmar-merge-develop, secret-scan, recordar-dashboard, entorno-maquina-guard) y en ninguno de tier `repo`/`global`; `precompact-volcar-estado` está retirado (RETIRED + ausente + test lo verifica); el drift-check e2 de test-brain deriva cableado/tiers del MANIFEST; los patrones de secret-scan y su exclusión de placeholders son coherentes.

---

## ALTO

### ALTO-1 · confirmar-merge-develop: el gate fail-safe-DENY FALLA ABIERTO en un clon sin bootstrap (timeout interno del juez > timeout del harness)
- **Archivos:** `brain/hooks/confirmar-merge-develop.sh:108` (`CLAUDE_MERGE_JUEZ_TIMEOUT:-25`), `plantilladotnet/.claude/settings.json` (confirmar-merge-develop → `"timeout": 15`), invariante documentado en `brain/hooks/analizar-comando-git.sh:168` ("TIMEOUT interno corto … < el timeout del hook en settings.json: 10s/15s … para que el proceso SIEMPRE termine y EMITA su decisión, en vez de que el CLI lo mate → evita el fail-open por MUERTE del proceso (H5)").
- **Qué pasa:** la llamada curl al juez-LLM usa timeout interno **25s** por default. El `settings.json` DEL REPO cablea el hook con harness `timeout: 15`. En un **clon SIN bootstrap** (sin copia global → la copia por-repo NO cede por dedupe y SÍ corre, que es justo su razón de ser: colegas sin brain), si el LLM tarda entre 15 y 25s el CLI **mata el hook a los 15s ANTES de que el juez emita** → no se imprime `deny` → el merge se **PERMITE** (fail-open). Peor aún: `acg_destino_de_mr` (6s) + `acg_lista_prs_abiertos` (6s) corren ANTES del juez, así que bajo red degradada el hook se mata incluso con un LLM rápido.
- **Por qué es incoherencia real:** es un gate de MÁXIMA consecuencia diseñado y DOCUMENTADO para fallar-CERRADO (UNAVAILABLE→DENY); aquí falla-ABIERTO en un despliegue soportado, y el juez (25s) **viola el invariante que la propia lib enuncia** (interno < harness 10s/15s). El ACG_MR_TIMEOUT=6 se calibró contra ese 15s, pero el timeout del juez quedó en 25.
- **Mitigación existente (por qué no es catastrófico):** en una máquina bootstrapeada corre la copia GLOBAL, cableada SIN timeout explícito → default 60s > 25s → ahí el gate funciona. El agujero es específico del clon-sin-brain + latencia LLM 15–25s. Aun así el escenario es exactamente el que la copia por-repo existe para cubrir.
- **Fix sugerido (para el humano, NO aplicado):** bajar `CLAUDE_MERGE_JUEZ_TIMEOUT` default a <15s (p. ej. 10–12s) para respetar el invariante, y/o subir el `timeout` del repo settings.json y homogeneizarlo con el global. Nace con test: aserción de que (destino+prlist+juez) ≤ harness del repo.

---

## MEDIO

### MEDIO-1 · Drift Windows `.exe`: acg_merge_menciona_base no reconoce `glab.exe`/`gh.exe` (evasión de git-branch-guard en Git Bash)
- **Archivo:** `brain/hooks/analizar-comando-git.sh:124-127` (`acg_merge_menciona_base`).
- **Qué pasa:** el endurecimiento Windows H-R9-01/B4 añadió `(\.exe)?` a `acg_es_merge_mr` (:140) y a `acg_destino_de_mr` (:179), PERO `acg_merge_menciona_base` quedó sin él. Verificado en vivo: `glab.exe mr merge 5 develop` → **no-match** (mientras `glab mr merge 5 develop` → match, y `acg_es_merge_mr "glab.exe mr merge 5"` → match). En Windows, el bloque de git-branch-guard que redirige un "merge que nombra develop/main" (git-branch-guard.sh:33) se evade.
- **Impacto/backstop:** el merge sí sigue gateado por confirmar-merge-develop (usa `acg_es_merge_mr`, que sí trae `.exe`), así que no es un pase libre a develop; lo que se pierde es la deny/redirección de git-branch-guard → hueco de defensa-en-profundidad + inconsistencia dentro de la MISMA lib.
- **Fix sugerido:** añadir `(\.exe)?` tras `glab`/`gh` en el regex de :126.

### MEDIO-2 · Doc drift en la nota "Tiers" del CLAUDE.md del repo: omite `entorno-maquina-guard` (tier both)
- **Archivos:** `plantilladotnet/CLAUDE.md` (bloque "> Tiers (fuente única = brain/hooks/MANIFEST)…") vs `brain/hooks/MANIFEST`.
- **Qué pasa:** la nota enumera tier `both` como {git-branch-guard, merge-squash-guard, confirmar-merge-develop, recordar-dashboard, secret-scan}, pero el MANIFEST también declara `entorno-maquina-guard both hook` (además de los libs `analizar-comando-git`/`detectar-secretos`). La doc subdeclara el set both → "doc que miente" leve respecto de la fuente única.
- **Fix sugerido:** agregar `entorno-maquina-guard` a la enumeración (o generar la lista desde el MANIFEST para que no vuelva a divergir).

---

## BAJO

### BAJO-1 · dod-verificar: timeout interno del juez (20s) > harness (15s) — inofensivo pero rompe el mismo invariante
- `brain/hooks/dod-verificar.sh:119` (`CLAUDE_DOD_JUEZ_TIMEOUT:-20`) vs settings.json Stop `timeout:15`. Como dod es **fail-OPEN por diseño** (nag, no seguridad), que el CLI lo mate = no-block = dirección CORRECTA → sin daño. Se anota por simetría con ALTO-1 y por prolijidad (alinear a <15s).

### BAJO-2 · confirmar-merge: el PISO DETERMINISTA de main solo aplica con `destino == "main"` literal; con destino VACÍO se salta
- `brain/hooks/confirmar-merge-develop.sh:141`. Si la consulta de destino falla (vacío) y el juez infiere main, el candado determinista de release (:141-147) NO corre (solo el fail-safe del LLM protege). Es **tradeoff documentado** (comentario :142 "Solo destino main CONFIRMADO; el vacío lo cubre el fail-seguro del LLM"), pero deja el caso de máxima consecuencia dependiendo solo del juicio del LLM. Informativo.

### BAJO-3 · acg_push_destino_base: FP potencial con ramas nombradas `feat/develop` o `x/main`
- `brain/hooks/analizar-comando-git.sh:71-73`. El regex `[[:space:]:/+](main|develop)([[:space:]]|$)` bloquearía un `git push origin feat/develop` (rama literal terminada en `/develop`). Raro en la práctica; documentado que evita `feat/develop-x` (sufijo), pero el nombre EXACTO `.../develop` sí matchea. Bajo.

### BAJO-4 · Ordenamiento de timeouts no cubierto por test
- `brain/test-brain.sh` prueba el hang con `ACG_MR_TIMEOUT=1` (:379) pero NO asserta que (interno del juez) < (harness del settings.json). Es la razón por la que ALTO-1 pasó inadvertido. Recomendado: test que derive el harness del settings.json y verifique el invariante.
