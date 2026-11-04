# Guards: tres fallas de PRECISIÓN vistas el 2026-09-30 (no aflojar — afinar)

**Origen:** sesión master en plantilladotnet (cwd) operando axon y heimdall-net · **Reporta:** unjordi (pidió dejar todas las observaciones al cortex master). Corpus: `docs/guards-falsos-positivos.md`, entradas 2026-09-30.

## 1. merge-develop-guard busca el grant en el repo EQUIVOCADO con `--repo <slug>`
Merge del PR 355 con `--repo unjordi/axon` desde una sesión con cwd en plantilladotnet: `acg_target_dir` no mapea el slug a su carpeta local (~/code/axon) y cae al cwd → `TARGET_ROOT`=plantilladotnet → lee `plantilladotnet/.claude/memory/autorizaciones-vigentes.local.md`, no el de axon. Además el juez LLM no vio el OK textual "mergea el #355 a develop" dado en el turno inmediato anterior (sesión venida de un fork/rehidratado: probable que lea otro transcript o que no esté volcado).
Destrabe usado (legítimo, re-cita de OK real): grant temporal de 5 min en el archivo del cwd, borrado tras el merge.
Propuesta: resolver `--repo owner/name` a la carpeta local comparando `git remote get-url origin` de los repos conocidos (~/code/*); si no se puede, decirlo en el mensaje ("no pude ubicar el repo local de <slug>; busqué el grant en <ruta>") en vez de "el juez no encontró tu confirmación".

## 2. Menciones citadas tratadas como comandos
Un `printf`/heredoc que solo CITABA el comando de merge (para escribir este corpus y este mismo feedback) disparó el freno de squash — dos veces. La lib `analizar-comando-git.sh` dice ignorar menciones entrecomilladas; estos casos se le escapan (cita dentro de printf de varias cadenas y dentro de un heredoc `cat > archivo <<'EOF'`).

## 3. proteger-arbol evalúa compuestos antes de que corra su propio merge
`git merge X && … && git branch -D X` → AVISO "borraría commits no integrados" 4 veces; falso porque el merge del mismo comando integra X antes del -D. Propuesta: si el comando contiene un `git merge <misma rama>` previo al `branch -D`, no avisar (o avisar "se evaluó antes del merge del mismo comando").

Cada fix con su test: positivo (el caso real bloquea/avisa cuando debe) y negativo (estos casos ya no).
