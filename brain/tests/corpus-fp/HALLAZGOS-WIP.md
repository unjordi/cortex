# Banco del corpus de FPs + revisión directa — WIP (rama fix/corpus-fp-bench, desde 52d2d8c)

Encargo (unjordi vía claudio, 2026-10-19): (1) convertir el corpus COMPLETO de FPs (`docs/guards-falsos-positivos.md`, 164 casos) en un banco REPRODUCIBLE por caso (comando + contexto rama/cwd/cd + decisión esperada) que corra cada guard contra TODOS sus casos y quede de gate en `test-brain.sh`; FP que sigan frenando se REPORTAN, no se borran; un caso nuevo suma su fixture en la misma tanda. (2) Reportar conteo pasa/frena por guard ANTES de arreglar. (3) Luego P1 = fixes de git-branch-guard con test que falle contra 52d2d8c.

## Trampas del harness (medidas por claudio; obligatorias o sale verde falso)
- DEDUPE: cada guard cede con `exit 0` si corre fuera de `~/.claude/hooks/` y la global existe → se corre con HOME FALSO (sin `~/.claude/hooks/<g>`). Controles POSITIVOS por guard lo verifican.
- El propio git-branch-guard escanea el comando Bash → el banco va en SCRIPT corrido con `bash <archivo>`.

## Estado del banco
- ✅ Infra: `brain/tests/corpus-fp/lib-corpus-fp.sh` (fakehome, run_guard, caso, reporte).
- ✅ git-branch-guard: `correr-git-branch-guard.sh` — **20 PASA · 3 FRENAN (FP vivos) · 4/4 controles+ OK**.
- ⏳ Faltan: proteger-arbol(32), dod-verificar(27), merge-develop-guard(familia: confirmar-merge-develop 25 + merge-squash-guard 16 + merge-develop-guard 3 = 44), no-bypass-deploy(9), secret-scan(4), entorno-maquina-guard(3), + varios de 1-2 (aviso-drift, limpiar-worktrees, isolation, barrer-ramas, aviso-contexto, auditor-coherencia, regla-sudo, aislamiento-worktree). Retirados (confirmar-merge-develop, merge-squash-guard) corren contra merge-develop-guard. Los pesados (dod, familia merge) necesitan fixtures de TRANSCRIPT + mock del juez.

## FP VIVOS medidos (git-branch-guard)
- L181 `for … do cd <wt> && push` — H1 (keyword `do ` antes del `cd`).
- `(cd <wt> && push)` subshell — clase H1 (prefijo `(`/`{`). ⚠️ la tabla de revisión-1 lo marca "pasa"; medido directo = FRENA. El fix H1 debe cubrir `do|then|else|elif|{|!|(`.
- L145 `pgrep -af 'git push|git fetch'` — FP de MENCIÓN citada (no hay push real), distinto de H1.

## Hallazgos de la revisión directa de claudio (van con P1)
### git-branch-guard + analizar-comando-git (sección 1)
- **H1 MEDIO** (= FP del día): `analizar-comando-git.sh:375` reconoce `cd` solo con `^[[:space:]]*(cd|pushd)`; tras `do|then|else|{` no lo arrastra → push pelón del segmento siguiente se resuelve contra el cwd de la sesión. Fix: aceptar prefijo de keyword (+`(`), o resolver la rama con git en el dir real (punto 5). Test con `for … do cd` que falle contra 52d2d8c.
- **H2 BAJO**: `acg_clon_local_de_slug` ciego desde un worktree (busca hermanos de `dirname(toplevel)`=worktree, no `~/code/*`). Fix: partir de `git rev-parse --git-common-dir`. (También afecta merge --repo desde worktree.)
- **H3 BAJO**: `acg_slug_de_dir` no entiende `ssh://git@host:puerto/org/repo.git`. Fix: normalizar `ssh://[user@]host[:puerto]/`.
### merge-develop-guard + juez-comun (sección 2)
- **H4 MEDIO** (FP del día, en corpus): el juez negó un OK explícito en LISTA ("mergea … !15, !1, !118, !76"); `glab mr merge 15 -R … --squash` → DENY. El prompt dice que una lista autoriza todos los ids. Hipótesis (sin medir): varianza de 1 voto de Haiku (VOTES=1) o la forma `repo !id`. Fix: reproducir con la conversación real como fixture; si es varianza, pre-filtro DETERMINISTA (última línea USUARIO nombra el id con verbo de merge → ALLOW sin juez).
- **H5 BAJO**: la exención de sync lee el OK POR LÍNEA (`--merge`/`sin squash` + id en la MISMA línea); OK multilínea no exime. Fail-safe pero FP posible.
- Cosmético: `juez-comun.sh` dejó cabeceras de caja rotas (`──── ──`) en 4 líneas.

## Fase 2 (DESPUÉS de P1)
1. `merge-develop-guard` parsea el string → `--repo $VAR` y `cd && … merge` dejan de frenar en falso; + norma CLAUDE.md global y `cerrar-slice`. Con test.
2. Regla de CI: `ci.yml` → `push:[develop,main]` + `workflow_dispatch` sin `pull_request`; `cerrar-slice.sh --wait-ci` dispara el gate (`gh workflow run`/`glab ci run`) y espera ESA corrida; norma global + `cerrar-slice §4` "gate a mano una vez"; plantilla CI si hay. Dato medido: push normal NO crea pipeline; gate manual sí; NUNCA `push -o ci.skip`.

## Decisión abierta
Escala del banco: (a) sigo yo guard por guard, o (b) delego la extracción del resto a UN agente secuencial con el harness/formato ya probado y yo verifico. Pendiente de unjordi.
