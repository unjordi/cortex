# Banco del corpus de FPs + revisión directa — WIP (rama fix/corpus-fp-bench, desde 52d2d8c)

## ⚡ MANDATOS VIVOS (2026-10-19, unjordi vía claudio)
- **GITLEAKS (nuevo, supersede secret-scan):** desechar secret-scan+detectar-secretos del cerebro (OK explícito de unjordi para quitar el control) → gitleaks. (1) retirar de hooks/MANIFEST/instalador(desinstala de máquinas que lo tienen)/settings/README+árbol×5/tests/bench; (2) norma CLAUDE.md global: gitleaks en CI + local pre-push; (3) `cerrar-slice.sh` corre `gitleaks git --log-opts=<base>..HEAD` pre-push, para si halla, excepciones solo en `.gitleaksignore`/`.gitleaks.toml`; (4) workflow gitleaks en CI de cortex (regla solo-gate: `on: push:[develop,main]+workflow_dispatch`). Tests 2 direcciones. **H6 queda moot** (el hook se borra); **mata el bootstrap-FP**. secret-scan SALE de la cuenta corpus (histórico, no se borra).
- **CORPUS CERO-FP:** cada vivo arreglado en su guard con test (falla vs 52d2d8c); los no-repro se reproducen con fixtures transcript+mock (o se demuestra corriendo que ya no aplican); H1–H7 cuentan; ningún caso se borra; tabla final por guard (total/arreglados/con-test).
- **SIMPLIFICAR merge-develop-guard (nuevo):** que haga SOLO (a) squash obligatorio a develop (chequeo DETERMINISTA del flag; releases a main sin squash) + (b) OK del usuario BIEN HECHO — un OK explícito de LISTA ("mergea a develop !15, !1…") pasa SIEMPRE (fix H4), SIN depender de un voto de Haiku ni de que Claude lo cite en el comando; destino resuelto con git/CLI en el dir REAL (fix L167/H2). FUERA: prohibición de `--auto`, regex de estilo del mensaje (traza/Rama:/MR:), frenos por `--repo $VAR`/`cd &&`. El mensaje de squash lo redacta quien mergea; NO hay revisión automática — merge-develop-guard muestra un RECORDATORIO (no freno, regla dura) al mergear a develop: redactar el mensaje a mano con el cambio neto + su porqué + las líneas `Rama:`/`MR:`. La misma frase va a la norma de git y a cerrar-slice. Cada cambio con test; banco merge-develop-guard verde. CONSOLIDA los FP de merge-develop-guard (L51/L167/H4/H5) + Fase 2 ítem (merge-guard parsea `--repo $VAR`/`cd &&`).

## TABLA FINAL POR GUARD (tras la tanda de vivos 2026-10-21, fix/corpus-fp-bench — todo LOCAL)
> Cada fix nace con su test que FALLA vs 52d2d8c (o se DEMUESTRA corriendo que el guard ya era correcto y el
> FIXTURE estaba mal). "con-test" = banco del corpus verde + (si tocó código) suite 1420·0.
| guard | vivos previos | arreglados / con-test | pendientes | commit(s) |
|---|---|---|---|---|
| git-branch-guard | 0 ✓ | – | – | 00df422 (H1/L145/H2/H3, previo) |
| entorno-maquina-guard | 0 ✓ | – | – | – |
| secret-scan | (se RETIRA por gitleaks) | – | migración gitleaks (slice aparte) | – |
| proteger-arbol | L11 + H7 | 2/2 ✓ (37 FP · 8/8 ctrl+) | – | H7 2b2cf40 · L11 b38d319 + hueco-datos df81f7e |
| no-bypass-deploy | L66 L105 + subshell | 3/3 ✓ (10 FP · 6/6 ctrl+) | – | d4b24c3 (L66/L105) · 0f54707 (subshell) |
| merge-develop-guard | L51 L167 + H4 H5 | L51 ✓ (fixture; guard ya correcto) · L167 ✓ (en B) · H4 H5 ✓ (prompt/awk, valida LIVE) | – | L51 bcd7b36 · H4/H5 [juez] |
| dod-verificar | L71 H8 H9 | H8 ✓ (b3-qc H8 dientes) · L71 H9 ✓ (prompt juez, valida LIVE) | – | H8 e0f81ac · L71/H9 [juez] |
| misc | aviso-drift L127/L171 · barrer-ramas L164 | 2/2 ✓ (5 FP · 5/5 ctrl+) | – | aviso-drift 083695f (fixture) · L164 05a8483 |

**GRUPO JUEZ/LLM RESUELTO (decisión de claudio 2026-10-21, "no confío nada en lo determinista"):** H4 (prompt del juez
de merge: una lista de ids en forma `!15`/`#15`/`MR 15` autoriza cada id; pre-filtro determinista de HALLAZGOS:6/53
DESCARTADO) · H5 (sync multilínea: awk reconstruye el bloque de mensaje USUARIO, no afloja entre mensajes) · L71 (juez
de dod: re-citar un QA previo → VISUAL=no) · H9 (juez de dod: cerrar una etapa/paso ≠ entregable LISTO → CIERRE=no).
Cada uno con caso en la batería LIVE (`jlive`/`djlive`), marcado "valida LIVE" — la clasificación real del LLM se mide
en la prueba-viva con unjordi (gate del bloque). CORPUS CERO-FP: todos los runners del corpus verdes.

## ENTRADAS NUEVAS L186-190 (claudio, 2026-10-21, en el checkout PRINCIPAL del corpus doc) — triage
Las 5 entradas viven en `docs/guards-falsos-positivos.md` develop-side (claudio); mi rama solo suma los BANCOS:
- **L186 proteger-arbol** — `gh pr merge 237 … ; … ; git branch -D feat/kitty-mac`: POR DISEÑO. El aviso se calcula
  en PreToolUse ANTES de que corra el merge del mismo compound, y el `;` NO garantiza la integración (gh-pr-merge
  tampoco es el patrón `git merge X &&` de H7) → avisar sobre una rama aún-no-integrada es correcto. **Control+** en
  `correr-proteger-arbol.sh`.
- **L187 barrer-ramas** — `gh pr merge 238 --repo unjordi/PowerScripts` desde cwd plantilladotnet barría el CWD:
  BUG REAL arreglado — el repo del merge se resuelve por el `--repo <slug>` (su clon local), igual que mdg B; con
  destino incierto (--repo $VAR / cd $VAR / --repo literal sin clon) NO barre a ciegas (skip, es un DELETE). Test
  `L187` + 2 controles en `correr-misc.sh`. Dientes vs 52d2d8c (usaba solo `acg_target_dir`).
- **L188 merge-develop-guard** — `cd ~/code/PowerScripts && … && gh pr merge … --repo unjordi/PowerScripts`: lo CUBRE
  B (el `--repo` LITERAL resuelve el clon del slug, no el cwd del cd) → el grant del slug se ve. Caso `L188` en el banco.
- **L189 git-branch-guard** — retirado (2976bbc): POR DISEÑO, no aplica. **L190 clasificador-auto-mode** — es del
  clasificador de Claude Code, NO un guard del cerebro: fuera de alcance.


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
- ✅ **H6** (`detectar-secretos.sh` `ds_safe_re`): marcadores-palabra (PRUEBA/no-real/de-prueba/dummy/fake/placeholder/redacted/CHANGE-ME) solo filtran si son el VALOR COMPLETO (anclado), no subcadena → una contraseña real que CONTIENE "Prueba"/"Dummy" como subcadena vuelve a BLOQUEAR (cierra el fail-open de credenciales, vivo en Mac+cachy). `test-brain.sh` b2-ph reescrito a esta semántica (ambas direcciones). [SUPERSEDIDO: secret-scan se retira por gitleaks.]

## FP VIVOS pendientes de fix (P1)
- **H7** (proteger-arbol, revisión-4): regla (c) `merge X && branch -D X` ignora el separador → con `;`/`||` calla aunque el merge choque y `-D` borre commits sin integrar (pérdida de datos). Fix: aplicar (c) SOLO con `&&` (sin `;`/`||`/`&`). Test con las 3 filas de la tabla.
- Nuevos FP-vivos del agente a decidir/arreglar: proteger-arbol L11, no-bypass-deploy L66/L105, merge-develop-guard L51/L167, dod-verificar L71, aviso-drift L127/L171, barrer-ramas L164.
- **H8** (dod-verificar, revisión-5): el OK a media vuelta CON imagen (`.attachment.prompt` como ARRAY) aborta el jq → vacía el texto de usuario del turno. El fix ya vive en `acg_recent_intercalado` (merge-guard); PORTARLO al lector de dod (`_juez_dod`/el extractor de usertext B3).
- **H9** (dod-verificar, revisión-5, BAJO): "cerré una etapa" sin ENTREGABLE se lee como cierre → FP. Ajustar el criterio del prompt (cerrar un paso/etapa ≠ declarar un entregable LISTO).
- **H1 VERIFICADO arreglado** (claudio, 8 casos cd, 2 direcciones) en 00df422.

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
