# Banco del corpus de FPs + revisión directa — WIP (rama fix/corpus-fp-bench, desde 52d2d8c)

## ⚡ MANDATOS VIVOS (2026-10-19, unjordi vía claudio)
- **GITLEAKS (nuevo, supersede secret-scan):** desechar secret-scan+detectar-secretos del cerebro (OK explícito de unjordi para quitar el control) → gitleaks. (1) retirar de hooks/MANIFEST/instalador(desinstala de máquinas que lo tienen)/settings/README+árbol×5/tests/bench; (2) norma CLAUDE.md global: gitleaks en CI + local pre-push; (3) `cerrar-slice.sh` corre `gitleaks git --log-opts=<base>..HEAD` pre-push, para si halla, excepciones solo en `.gitleaksignore`/`.gitleaks.toml`; (4) workflow gitleaks en CI de cortex (regla solo-gate: `on: push:[develop,main]+workflow_dispatch`). Tests 2 direcciones. **H6 queda moot** (el hook se borra); **mata el bootstrap-FP**. secret-scan SALE de la cuenta corpus (histórico, no se borra).
- **CORPUS CERO-FP:** cada vivo arreglado en su guard con test (falla vs 52d2d8c); los no-repro se reproducen con fixtures transcript+mock (o se demuestra corriendo que ya no aplican); H1–H7 cuentan; ningún caso se borra; tabla final por guard (total/arreglados/con-test).

## TABLA DE VIVOS ACTUAL (contra código parchado, tras merge del agente 63a7a78)
| guard | vivos | no-repro | hallazgos |
|---|---|---|---|
| git-branch-guard | 0 ✓ | – | H1/L145/H2/H3 ✓ (commit 00df422) |
| entorno-maquina-guard | 0 ✓ | – | – |
| secret-scan | (se RETIRA por gitleaks) | – | H6 ✓ pero moot |
| proteger-arbol | 1 (L11 reset--hard alinea con squash) | – | H7 (regla c ignora separador) |
| no-bypass-deploy | 2 (L66 ls, L105 git diff de install.sh) | L101 | – |
| merge-develop-guard | 2 (L51 release entrecomillado, L167 compound -C \$M) | 12 | H4/H5 |
| dod-verificar | 1 (L71 QA visual turno anterior) | 11 | – |
| misc | 3 (aviso-drift L127/L171 tier-repo, limpiar-ramas L164 mini-tema) | – | – |


Encargo (unjordi vía claudio, 2026-10-19): (1) convertir el corpus COMPLETO de FPs (`docs/guards-falsos-positivos.md`, 164 casos) en un banco REPRODUCIBLE por caso (comando + contexto rama/cwd/cd + decisión esperada) que corra cada guard contra TODOS sus casos y quede de gate en `test-brain.sh`; FP que sigan frenando se REPORTAN, no se borran; un caso nuevo suma su fixture en la misma tanda. (2) Reportar conteo pasa/frena por guard ANTES de arreglar. (3) Luego P1 = fixes de git-branch-guard con test que falle contra 52d2d8c.

## Trampas del harness (medidas por claudio; obligatorias o sale verde falso)
- DEDUPE: cada guard cede con `exit 0` si corre fuera de `~/.claude/hooks/` y la global existe → se corre con HOME FALSO (sin `~/.claude/hooks/<g>`). Controles POSITIVOS por guard lo verifican.
- El propio git-branch-guard escanea el comando Bash → el banco va en SCRIPT corrido con `bash <archivo>`.

## Estado del banco
- ✅ Infra: `brain/tests/corpus-fp/lib-corpus-fp.sh` (fakehome, run_guard, caso, reporte).
- ✅ git-branch-guard: `correr-git-branch-guard.sh` — tras los fixes H1+L145: **23 PASA · 0 vivos · 4/4 controles+**.
- ✅ Resto de guards: construidos por el agente af2737b0 en worktree `worktree-agent-af2737b0f23af361c` (PENDIENTE verificar por muestra + merge): proteger-arbol 36/1·5+, no-bypass-deploy 8/2·4+ (L101 no-repro), entorno-maquina-guard 3/0·3+, secret-scan 3/0·4+ (⚠️ sus controles+ NO cubrían reales-con-subcadena = el hueco H6; AMPLIAR), merge-develop-guard(familia 43) 29/2·8+ (12 no-repro=criterio juez), dod-verificar 15/1·4+ (11 no-repro=criterio juez), misc 2/3·4+.
- Retirados (confirmar-merge-develop, merge-squash-guard) corren contra merge-develop-guard. Pesados (dod, familia merge) con fixtures de TRANSCRIPT + mock del juez (miden la capa determinista, no el LLM).

## FIXES P1 APLICADOS (lib + detectar-secretos, esta tanda)
- ✅ **H1** (`acg_push_toca_base` L375): `cd` tras keyword/agrupación (`do|then|else|elif|!|{|(`) se arrastra → `for…do cd && push` y `(cd && push)` ya PASAN.
- ✅ **L145** (`acg_es_push`): `git push` exige POSICIÓN DE COMANDO (inicio, o tras ejecutor `( $( { x= eval sudo env (ba)?sh -c …`); un `git push` como ARG de `pgrep`/`grep`/`echo` ya NO cuenta. Preserva M1/G3 (eval/bash -c/subshell SÍ frenan) — verificado.
- ✅ **H2** (`acg_clon_local_de_slug`): busca hermanos junto al repo PRINCIPAL (`git-common-dir`), no al worktree.
- ✅ **H3** (`acg_slug_de_dir`): normaliza `ssh://[user@]host[:puerto]/`.
- ✅ **H6** (`detectar-secretos.sh` `ds_safe_re`): marcadores-palabra (PRUEBA/no-real/de-prueba/dummy/fake/placeholder/redacted/CHANGE-ME) solo filtran si son el VALOR COMPLETO (anclado), no subcadena → `Password=Prueba2024!`/`DummyPass99` vuelven a BLOQUEAR (cierra el fail-open de credenciales, vivo en Mac+cachy). `test-brain.sh` b2-ph reescrito a esta semántica (ambas direcciones).

## FP VIVOS pendientes de fix (P1)
- **H7** (proteger-arbol, revisión-4): regla (c) `merge X && branch -D X` ignora el separador → con `;`/`||` calla aunque el merge choque y `-D` borre commits sin integrar (pérdida de datos). Fix: aplicar (c) SOLO con `&&` (sin `;`/`||`/`&`). Test con las 3 filas de la tabla.
- Nuevos FP-vivos del agente a decidir/arreglar: proteger-arbol L11, no-bypass-deploy L66/L105, merge-develop-guard L51/L167, dod-verificar L71, aviso-drift L127/L171, barrer-ramas L164.

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
