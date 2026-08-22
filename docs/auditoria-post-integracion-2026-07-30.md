# Re-auditoría POST-INTEGRACIÓN — develop @ 4f660e7 (2026-07-30)

> FMEA read-only de 3 auditores (con zapatos: árbol del README + flowcharts + CONVENCIONES + normas) sobre
> TODO lo integrado hoy a develop (rango `5b84e4d..4f660e7`: A #209/#212/#213/#214 · B #207 · #210 · #208).
> Base técnica: **374 PASS · 0 FAIL**. Dictámenes fuente (efímeros): scratchpad/auditoria-post-integracion-2026-07-30/{AUDITOR-A,B,C}.md.
> Convención: CONFIRMADO = leído/ejecutado y falla · PLAUSIBLE = sospecha razonada sin cierre.

## Veredicto: 0 CRÍTICO · 3 ALTO · 4 MEDIO · ~11 BAJO. Los fixes del FMEA previo SÍ cerraron.
Verificado por ejecución que A1 (`-a/-am/--all`), A2 (`+develop`/refspecs con `:`) quedaron cerrados; C2
anti-regresión, `commit -o` acotado, proteger-fuente fail-open, `ev_de()` completo, paridad de rutas de los
3 updaters, y el parser del generador → **SANOS**. Lo que queda son huecos NUEVOS (no regresiones):

---
## ALTO — evasiones de git-branch-guard (todas CONFIRMADAS, Auditor A)
> Backstop real = ramas protegidas server-side (GitLab). Son huecos de defensa-en-profundidad + del
> "redirige/educa"; el guard ANUNCIA cubrir refspecs/force y estos son de esa familia. TOCAN MIS PROPIOS
> CANDADOS → cambiarlos exige OK explícito de unjordi por control (norma de integridad de guardrails; el
> cambio sería de PRECISIÓN/endurecimiento, dirección permitida).

- **A-01 · destino ENTRECOMILLADO** — `analizar-comando-git.sh:9,50-58`. `git push origin "develop"` (o `'develop'`): el despojador de comillas (que ignora menciones en `-m`) borra el destino → push "pelón"; en rama no-base el fallback tampoco dispara → **NO bloquea**. Fix: despojar comillas SOLO en el tramo del mensaje, no en los posicionales del push.
- **A-02 · `git push --all` / `--mirror`** — `analizar-comando-git.sh:25-45`. Empujan develop/main sin nombrarlas → `destino_base=no` → en feature no dispara pero actualiza las bases remotas. Fix: tratar `--all`/`--mirror` como "toca base" incondicional.
- **A-03 · prefijo `git -c k=v …` (y `git -C dir`)** — `analizar-comando-git.sh:19` + `secret-scan.sh:63`. Rompe la adyacencia `git+push`/`git+commit` → **evade git-branch-guard Y deja ciego a secret-scan** (`git -c … commit`). Fix: normalizar el prefijo `git ([-cC] …)*` antes de exigir adyacencia.

## MEDIO
- **B1 · árbol del README RAÍZ drifteado vs MANIFEST (CONFIRMADO)** — afecta #208 recién mergeado. `gen-leyenda-arbol.sh` parsea el README **raíz**, pero e6c solo vigila `brain/README.md`. El árbol raíz YA le faltan **4 hooks** (`proteger-fuente-cerebro`, `barrer-ramas`, `recordar-cosechar`, `recordar-unificar-cerebro`) → **la leyenda "árbol completo" de los flowcharts salió incompleta (faltan esos 4)**. Fix: e6c corre TAMBIÉN contra el README raíz (o genera ese árbol del MANIFEST) + agregar los 4 ya.
- **C1 · `install-brain.ps1` (Win) no exporta `CLAUDE_BRAIN_DIR` (CONFIRMADO)** — solo `bootstrap.ps1` lo hace. Instalar a mano en Windows (`pwsh -File brain\install-brain.ps1` tras clon manual) → hooks caen a `~/.cortex` inexistente → auto-sync falla MUDO. e4 no cubre este camino. Fix: install-brain.ps1 exporta CLAUDE_BRAIN_DIR (derivado del RepoRoot) como bootstrap.ps1.
- **A-04 · confirmar-merge-develop, A4 anulado con id tras flag (CONFIRMADO)** — `glab mr merge --yes 9`: `cur_mrid` sale vacío → un OK ligado a OTRO MR autoriza éste. Fix: extraer el id tolerando flags intermedios.
- **A-05 · confirmar-merge-develop, A3 residual (CONFIRMADO)** — negaciones fuera de `no/sin/nunca/jamás` ("ni se te ocurra mergear el 5", "para nada", "de ninguna manera") pasan como OK. Fix: ampliar `NEG_RE`.
- **A-06 · dod-verificar + confirmar dependen de que el contexto inyectado NO sea role=user (PLAUSIBLE)** — si el harness reinyecta CLAUDE.md (lleno de "autorizó/release/mergea") como role=user, ambos gates se auto-satisfacen. Fix: excluir contenido con marca de inyección (`<system-reminder>`/isMeta/additionalContext) al construir el texto-usuario.

## BAJO (resumen)
- **B2** sA3 `Develop[A-Z]*` es locale-dependiente (collation UTF-8 puede casar minúsculas → `Developer` recibiría auto-push). Fix: `[[:upper:]]` o `LC_ALL=C`. (PLAUSIBLE)
- **C3** Updater.cs ruta-descarga escribe `date=''` → el gate "solo si más nuevo por fecha" degrada a SHA-only. (CONFIRMADO)
- **C4** gen-leyenda: el tracking de fences es frágil → un ``` desbalanceado arriba del README → leyenda VACÍA sin error. Fix: anclar a `/^🔒 Hooks Forzosos/`. (PLAUSIBLE)
- **C5** gen-leyenda-arbol.sh **sin NINGÚN test** → sus fragilidades rompen la leyenda en silencio. Fix: test que afirme 4 familias + ≥1 fila c/u. (CONFIRMADO)
- **C6** valencia cross-chart: aviso-drift sale 🟢 en 01 pero ⚠ penwidth=3 en 02 (02 correcto). (PLAUSIBLE)
- **C7** citas de línea stale en 01 (`:127-132`→`:158`/`:110`) y CONVENCIONES §6 (`:90-97`→`:110`). (CONFIRMADO)
- **C8** 01 arista `wiring hardcode` contradice a GWIRE (ya deriva del MANIFEST). (CONFIRMADO)
- **A-07** aliases de git (`git ci`) evaden el gate literal. (BAJO, condicional a config)
- **A-08** dod-verificar B2 solo reconoce chrome-MCP/`computer` → falso bloqueo con playwright/puppeteer/Read-de-screenshot. (CONFIRMADO)
- **A-09** merge-squash B3: fuerza squash en merge a rama personal si la red cae (fail-safe DELIBERADO, no bug). 
- **B3** e2/e6b no cazan `ev_de()` mal mapeado para hooks NO-Bash. (PLAUSIBLE)
- **B4** verificar-cerebro no verifica las libs instaladas. (PLAUSIBLE)
- **C9 (latente, ya en el chart 02)** carrera SessionStart aviso-drift (commit/push) vs barrer-ramas (`branch -d` detached) sobre el mismo `.git`. (CONFIRMADO riesgo latente)

## Notas de calibración
- Ninguno es CRÍTICO ni regresión de lo integrado; el release a main no está en riesgo funcional inmediato.
- **B1 y C6/C7/C8 tocan #208 que YA está en develop** → son doc=realidad de trabajo recién mergeado (la leyenda incompleta es lo más sustantivo).
- Los ALTO + A-04/A-05/A-06 tocan **candados de supervisión de Claude** → no se cambian sin OK explícito por control.

---
## LOOP fix→re-auditar (wave4 = rama fix/wave4-auditoria)
- **Wave4 r1** (commit 470a71f, 389 PASS): atendió el dictamen r1 completo (guards A-01..A-06/A-08, B1/B2, C1, C4-C8) + diferidos documentados (C3 Updater.cs date, B3/B4, A-07/A-09).
- **Ronda 2** (dictámenes scratchpad/auditoria-r2-2026-07-30/): B LIMPIO · C bajó a nits cosméticos (hex tema, DRIFT_INVERSO externo — diferidos) + C7 parcial · A dejó **N-01 (MEDIA)**: `git push origin "HEAD:develop"` (refspec entrecomillado base-a-la-derecha) evadía — residuo del raw-check de A-01.
- **Wave4 r2** (commit 1f8b30c, 392 PASS): cerró N-01 (acg_push_toca_base reescrito: es_push→desquota segmento→detección) + C7 (citas de línea volátiles fuera).
- **Ronda 3**: A → N-01 CERRADO (18/18 formas bloquean) pero destapó **A-R3-01 (MEDIA)**: mi reescrito de N-01 usaba `head -1` → solo miraba el PRIMER `git push …` → un push a base ENCADENADO (`git push feat/x ; git push develop`) se colaba por el 2º. C → **C7-r/C7-s** (2 citas volátiles más: 01.dot `(:26 MANIFEST)` y CONVENCIONES §3 `README.md líneas ~79-136`) + reconfirmó 2 nits cosméticos NO-bloqueantes (hex §2 tema-claro; DRIFT_INVERSO→repo externo). A-R3-02 (BAJA, pre-existente: `feat/develop` sobre-bloquea, tradeoff del `/`) = ACEPTADO.
- **Wave4 r3** (commit **c94ccb6**, 395 PASS): `acg_push_toca_base` recorre CADA subcomando (`awk gsub [;&|]→\n`), no `head -1` → el push a base encadenado ya bloquea; H13 preservado por-subcomando (+3 tests gbg A-R3-01). C7-r/C7-s → citas por ancla, no por nº de línea.
- **Ronda 4**: A → anti-regresión r3 + A-01/02/03/N-01 SIN regresión, pero destapó **A-R4-01 (CRÍTICO)** + **A-R4-02 (ALTO)** + **A-R4-03 (MEDIO)**. C → C7 al 100%, leyendas byte-idénticas al README, SVGs en sync; solo **C-H1 (MEDIO)**: árbol tecleado a mano en CONVENCIONES §3 drifteado. Raíz de A-R4-01/02: `acg_normaliza_git_prefijo` colapsaba SOLO `-c`/`-C`; git acepta MUCHAS más globales (`--no-pager`, `-p/-P`, `--work-tree`, `--git-dir`, `--namespace`, `--exec-path`, `--no-replace-objects`, `--literal-pathspecs`…) → cada una rompía la adyacencia git+push/git+commit y evadía git-branch-guard Y el escaneo de secretos. A-R4-03: confirmar-merge leía un DEFERIMIENTO ("espera para mergear el 5") como OK.
- **Wave4 r4** (commit **d975e50**, 411 PASS): generalizó `acg_normaliza_git_prefijo` a la CLASE (value-eaters por espacio/= + cualquier flag dash-led → una global nueva de git ya no reabre el hueco), cerrando A-R4-01 y A-R4-02 de un golpe (lib compartida); `DEFER_RE` en confirmar-merge (fail-safe: aplazamiento → re-pide OK) para A-R4-03; C-H1 → §3 apunta al árbol vivo (fuente única). +tests por cada hallazgo (verificados por ejecución contra los guards reales).
- **Ronda 5**: C → **LIMPIO** (0/0/0/0): C-H1 cerrado, leyendas byte-idénticas al README, SVGs en sync; nota informativa no-bloqueante (§6 lista manual de 8 pre-hooks, sin drift hoy, candidata futura). A → anti-regresión r4 cerrada (411 PASS) pero **reabrió la MISMA raíz por valor ENTRECOMILLADO**: **A-R5-01 (ALTO)** `git -C "/Users/unjordi/Mi unidad/repo" push develop` → SILENT (el `[^space]+` se corta en el espacio; realista por rutas de Google Drive) + **A-R5-02 (ALTO)** secret-scan ciego con comilla SIN espacio (despoje antes de normalizar) + **A-R5-03/04 (BAJO)** aplazamientos suaves y FP seguro "no esperes".
- **Wave4 r5** (commit **c6842d3**, 421 PASS): normalizador **QUOTE-AWARE** (`"..."`/`'...'` como unidad) + secret-scan **normaliza el RAW antes de despojar** → cierra A-R5-01 y A-R5-02; DEFER_RE amplía `déjame ver`→`déjame ver|probar|revisar|checar…` (A-R5-03 parcial). **A-R5-03 residuo** (luego/ahorita/primero: zona gris semántica) y **A-R5-04** ("no esperes, mergea"→deny: FP de dirección SEGURA, preexistente en NEG_RE) = **ACEPTADOS** — perseguirlos afloja en la dirección insegura; backstop = cita humana del OK.
- **Ronda 6**: A → anti-regresión r5 limpia (421 PASS) pero destapó **A-R6-01 (CRÍTICO)**: la comilla puede ir EN MEDIO del valor (`git -c user.name="a b" push develop` — shell-válido, cotidiano); r5 cubrió la comilla al INICIO (`-C "/ruta"`) pero el valor MIXTO `key="val con espacio"` volvía a cortarse en el espacio interno → evasión TOTAL de git-branch-guard Y secret-scan.
- **Wave4 r6** (commit **69c9560**, 427 PASS): el VALOR de un global se modela como **SECUENCIA** de (char-no-espacio-no-comilla | run `"…"` | run `'…'`): `([^[:space:]"']|"[^"]*"|'[^']*')+` → `user.name="a b"` casa entero. Aplicado a la lib y al fallback de secret-scan. +tests (comilla simple/doble en medio, valor con `-c` interno, H13, ramita sin FP).
- **Ronda 7**: A → anti-regresión r6 limpia (427 PASS) pero destapó **A-R7-01 (CRÍTICO)**: el espacio del valor puede ir ESCAPADO CON BACKSLASH (`git -c a=b\ c push develop`, el shell → `-c "a=b c"`); el `\` se trataba como char normal y la secuencia se cortaba en el espacio real. merge-squash/confirmar-merge NO llaman al normalizador → estructuralmente inmunes.
- **Wave4 r7** (commit **fe72558**, 432 PASS): se añade `\\.` (backslash+char) como alternativa de la secuencia de valor en la lib y el fallback de secret-scan → el par escapado se consume como parte del valor. +tests.
- **PATRÓN OBSERVADO (r5→r6→r7):** las 3 rondas destaparon la MISMA clase — el modelo regex del VALOR de una opción global de git no cubría alguna forma de quoting/escaping del shell (espacio entrecomillado → comilla en medio → espacio con backslash). Cada fix generalizó y hoy el valor modela bare + `"…"` + `'…'` + `\<char>` (≈ el word-splitting POSIX completo; faltarían exóticos bash `$'…'`/`$"…"`). Es whack-a-mole de regex-vs-tokenización-de-shell sobre un guard HEURÍSTICO cuyo backstop real son las ramas protegidas server-side. **Decisión de convergencia pendiente de unjordi** si r8 vuelve a destapar solo exotica de shell.
- **Ronda 8**: A declaró el **modelo de valor CONVERGIDO** (todas las formas realistas de quoting/escaping bloquean; anti-regresión r4–r7 firme; 432 PASS). **0 CRÍTICO · 0 ALTO · 1 MEDIO · 3 BAJO** — todos en EJES DISTINTOS al value-model:
  - **B4 (MEDIO)**: `git.exe push/commit` evade (el `.exe` rompe el `git`+espacio); realista en Windows/Git Bash (OS soportado).
  - **BAJO** (aceptados): A8 (valor con backslash FINAL, contrivísimo), B5/B6 (command-substitution `$(git push…)`), B7 (`eval "git push…"`, hueco conceptual de cualquier guard heurístico). Backstop = ramas protegidas server-side.
- **Wave4 r8** (commit **76c8286**, 439 PASS): B4 cerrado en el chokepoint — `acg_normaliza_git_prefijo` colapsa `git.exe`→`git` en posición de ejecutable (cubre push explícito/pelón/encadenado y commit; sin FP en ramita ni con git.exe en el mensaje/H13); paridad en el fallback de secret-scan. +tests. Los 3 BAJO quedan ACEPTADOS y documentados.

- **Ronda 9** (CONFIRMACIÓN, a pedido de unjordi): A verificó que el fix de B4 (`git.exe`→`git`) NO introdujo FP ni mangling (`git.exe` en mensajes/paths/`mygit.exe`/`legit.exe` no disparan) y que la anti-regresión global (A-01…A-R7-01, N-01) sigue firme (439 PASS). Un hallazgo nuevo: **H-R9-01 (MEDIO)** — `glab.exe mr merge`/`gh.exe pr merge` evaden `merge-squash-guard` Y `confirmar-merge-develop` (hermano de B4 en el eje merge; el fix r8 solo colapsó `git.exe`).
- **Wave4 r9** (commit **a75f4af**, 443 PASS): `(\.exe)?` en el reconocimiento de merge (`acg_es_merge_mr`), en la detección de herramienta (`acg_destino_de_mr`) y en el mensaje cosmético de merge-squash-guard → cierra H-R9-01 en ambos guards. +tests (squash + confirmar, con/sin OK, con/sin squash, sin FP).

## CIERRE TÉCNICO DEL LOOP (r1→r9) — wave4 @ a75f4af, 443 PASS · 0 FAIL
El loop convergió: el value-model de las opciones globales de git resiste todo quoting/escaping realista; el eje `.exe` quedó cerrado en AMBOS frentes (B4 `git.exe` en r8, H-R9-01 `glab.exe`/`gh.exe` en r9). Sin hallazgos CRÍTICO/ALTO/MEDIO abiertos. Residuos aceptados (BAJO/esotéricos, backstop server-side): A8, B5, B6, B7, más los de rondas previas (A-R5-04 "no esperes"→deny FP-seguro, residuo A-R5-03, A-R3-02, A-07, A-09, C3, B3/B4-cobertura, §6 lista manual).

**INTEGRADO a `develop` el 2026-07-31 (PR #216 MERGED con squash, commit `658c2aa`) con OK EXPLÍCITO de unjordi.** `main` SIN tocar — el release develop→main es una decisión deliberada aparte que unjordi pide explícitamente. QA de plataforma (Windows/KDE del widget) = POST-release. Backlog: construir el mecanismo/skill para invocar auditores general-purpose por-pedido (estreno pensado: games-master #210).
