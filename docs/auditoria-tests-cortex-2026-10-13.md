# Auditoría de calidad de pruebas — `cortex` `brain/test-brain.sh`

Worktree auditado: `/Users/unjordi/code/cortex/.cortex-wt/A1-ci-shellcheck` (rama `fix/afinado-nucleo-2026-10`). Solo lectura. Todas las rutas `test-brain.sh:N` son de `brain/test-brain.sh` en ese worktree. Lo marcado [INFER] es inferencia mía.

> Aviso de método: este worktree YA incluye los fixes de los 3 bugs de hoy (a, b, c) y sus tests nuevos. Para decir "qué test faltaba" me apoyo en (1) los comentarios de esos mismos tests ("FALLA contra el código viejo"), (2) `git log`, (3) el corpus.

---

## 0. Veredicto corto

1. **La sospecha es cierta, pero localizada y no en la forma que se piensa.** La suite NO está dominada por tests de forma: los guards de git/merge/secret-scan son mayormente escenarios reales en las dos direcciones. Lo que deja pasar bugs a producción no es sobre todo el test "grep de texto", sino cuatro fallas más finas: (i) la DECISIÓN que importa está mockeada, (ii) el fixture es una versión idealizada del caso real, (iii) no hay test en el valor límite, (iv) no hay test de ningún tipo para ese caso.
2. **Peso real de plomería/forma/estructura (C+D): ~9-13 % de los asertos.** Ver §1. No es lo que explica el goteo de bugs; sí es ruido de mantenimiento y falsa sensación de cobertura en áreas donde no hay escenario (skills, widgets, instalador).
3. **Hay un grupo pequeño pero grave de asertos que cuentan PASS sin haber probado nada** (tipo E): baterías "LIVE" saltadas que suman `ok`, `UNAVAILABLE` aceptado como pasa, un `|| ok "esperado"` que no puede fallar. Y el CI no corría `test-brain` porque `shellcheck` fallaba antes (corpus 2026-10-09).

---

## 1. Taxonomía cuantificada

### Método
- Universo: **1314 sentencias `ok "…"`** extraídas del archivo (9054 líneas, 132 secciones `echo "== …"`), tras unir líneas de continuación (`\`, `&&`, `||`). El "~1379 PASS" de la corrida sale de que varios `ok` están en bucles (`bash -n` por archivo, drift por widget, `for nativo in …`) y se ejecutan más de una vez. No corrí la suite (trae baterías que llaman al LLM y bloques e2e; la regla dice "si dudas, no la corras").
- Clasificación en 3 pasadas: (1) heurística automática por sección y por forma de la sentencia (¿es un `grep`/`[ -f ]`/`bash -n` sobre un archivo del árbol `brain/`/skills/widgets, o ejecuta el hook y mide su salida/efecto?); (2) lectura manual de **las 121 sentencias que la heurística marcó como C/D** (todas, no muestra) y de las 49 marcadas "mensaje"; (3) lectura de ~120 sentencias de BEH tomadas por muestreo sistemático (1 de cada 11) para calibrar, más lectura dirigida de las secciones de guards.
- La separación A vs B (una vs dos direcciones) NO la puedo contar test a test sin leer los 1144; la doy **por sección** (¿la sección tiene al menos un aserto "frena/avisa" y uno "pasa/silencio" sobre el mismo hook?). Es una **cota superior de A**. Los números de A/B son estimación, no conteo exacto.

### Resultado (sobre 1314 sentencias estáticas)

| Cat. | Qué es | Conteo | % | Confianza |
|---|---|---|---|---|
| **A** | Caso de uso real, efecto observable, las DOS direcciones (sección con ambas) | ~840 (cota superior) → **estimo 55-62 %** | | media: conteo por sección |
| **B** | Caso de uso real, una sola dirección (sección solo "positiva" o solo "negativa") | ~300 → **estimo 20-23 %** | | media |
| **C** | Plomería/forma: grep sobre código fuente, existencia, texto del mensaje | **39 grep-de-fuente + 49 mensaje-como-único-aserto = 88** | **~6.7 %** | alta (leí las 121 + 49) |
| **D** | Estructura del repo: MANIFEST, README↔árbol, paridad de roster, `bash -n`/`jq empty`, "no hagas así" sobre prosa de SKILL.md | **82** | **~6.2 %** | alta |
| **E** | No pueden fallar / setup que falla en silencio / cuentan PASS sin probar | **~12 sentencias duras** + 27 asertos de setup `(teeth)/(setup)` legítimos | **~1 %** | alta para las duras |

A+B+C+D+E suman >100 % del 1314 en el texto porque A/B son rangos; la suma central cuadra a ~100 %.

Nota sobre C-mensaje: 49 asertos verifican que la salida contenga cierto texto ("el mensaje señala/explica/advierte/nombra…"). En hooks cuyo efecto ES un aviso (aviso-contexto, aviso-drift, rehidratar) el texto es parte del efecto; en un guard, el efecto es `deny/allow` y el texto es forma. Los conté como C por ser el único aserto de esa sentencia; es el rubro más discutible.

### Por hook / área (asertos estáticos por sección; dirección = estimación por sección)

| Área / hook | Asertos | Calidad dominante | Direcciones |
|---|---|---|---|
| `git-branch-guard` (b1d*, b3c) | ~169 | A (escenario real de comando) | ambas (≈ 74 frena / 46 pasa por regex) |
| `merge-develop-guard` (b1c*, b1e, b1f) | ~214 | A, con mock del juez LLM (ver §3) | ambas |
| `secret-scan` (b2*) | ~40 | A | ambas (25 frena / 11 pasa) |
| `proteger-arbol` (b3) | 14 | A pero fixture idealizado (§3) | casi solo "no avisa" + 1-2 "avisa" |
| `dod-verificar` (b4, b4z) | ~47 | **A con la decisión mockeada**; LIVE opt-in | ambas sobre el flujo, ninguna sobre la clasificación |
| `aviso-contexto` (b6) | ~34 | B (emite X; pocos "calla") | casi una dirección; modelos solo "listados" |
| `rehidratar-hilo` (b5, f1) | ~59 | B; umbral probado muy lejos del límite | una |
| `aviso-drift-cerebro` (b5b) | ~29 | B/C: stub del sync + archivos vacíos | sesgo a "avisa" |
| `limpiar-ramas/worktrees` (b3*) | ~120 | A (repos git reales en tmpdir) | ambas; la mejor sección de la suite |
| `install/sincronizar/uninstall` (c, e5-e8, g2) | ~150 | A sobre `$HOME` falso + parte D | ambas |
| `reubicar-master` (rm, e2e, r2, si, sm) | ~130 | mezcla: e2e A; ~16 greps al SKILL.md/session-move.js = C/D | |
| widgets (e9, e3*, e6.4/6.5) | ~40 | **C puro** (grep de identificadores en Swift/QML/C#) | ninguna |
| doc/manifest/árbol (e2*, e6*, f, g4, #83) | ~45 | D | n/a |
| control-gui (gui) | 13 | D/C (`bash -n`, "documenta el fallback") | n/a |

---

## 2. Ejemplos concretos por categoría

### A — escenario real, dos direcciones (lo bueno)
- `test-brain.sh:3625-3628` — `git push origin develop` → deny; `git push -u origin feat/x` → pasa; `git commit -m "doc: no hagas git push a develop"` → pasa; `grep -rn "git push origin develop"` → pasa. Un comando real por línea, efecto `deny/silencio`, ambas direcciones, y la mitad son falsos positivos del corpus.
- `test-brain.sh:3426-3446` (b3cs-ci) — ejecuta el `cerrar-slice.sh` REAL con un `glab` stub que (1) falla, (2) devuelve `{"pipeline":null}`, (3) devuelve `failed`; aserta rc y mensaje. Tres casos, dos direcciones, y el comentario dice "FALLA contra el código viejo".
- `test-brain.sh:3268` / `3313` — el worktree/remota con trabajo vivo SOBREVIVE al barrido (efecto sobre el repo git real, no sobre el texto). 
- `test-brain.sh:2471` — commit grande y limpio: silencio **y** ≤3 s (efecto + medida de cuelgue).

### B — una sola dirección
- `aviso-contexto` (b6): casi todo es "con este transcript y este modelo EMITE tal %" (`test-brain.sh:5125` "escalada: 🚨 …"); los casos "debe callar" existen solo para modelo desconocido (`5179`, `5170`).
- `rehidratar-hilo` faro: antes de hoy solo `test-brain.sh:4147-4157` (hilo de **500 líneas ≈ 40 KB**, muy por encima de CUALQUIER umbral) → "antepone faro"; no había el caso "justo bajo el umbral real del harness".
- `reubicar-master` e2e: ~50 asertos de la ruta feliz y pocas negativas (`8741` G-QUIESCE avisa; `8597` el candado rechaza handoff sin preludio).

### C — plomería / forma
- `test-brain.sh:5684-5693` — "el lanzador corre DETACHED (nohup)", "trae centinela anti-recursión", "SOURCEA la lib": `grep -qF 'nohup' "$SCRIPT_DIR/hooks/checkpoint-mecanico-comun.sh"`. Verifica que una palabra esté escrita en el código, no que el hook no bloquee con un transcript grande.
- `test-brain.sh:7237-7247` (e9) — `grep -q 'hoverHighlight' "$SW_PV"`, `grep -q '_hoverBottom' "$WPF"`, `grep -qE 'PC3\.ToolButton' "$QML9"`: nombres de identificador en Swift/C#/QML. Plomería pura; 17 asertos.
- `test-brain.sh:7306-7320` — `exportar-sesion-master`: default `~/.claude-sessions` "en el código", `nohup` + lock, `_master_base` cableado: greps del `.sh`.
- `test-brain.sh:8331-8346` (r2-4) — greps NEGATIVOS al SKILL.md: "el SKILL no describe a session-move.js con el writeFileSync…", "…describe writeAlias como es hoy". Un test de que la prosa de una doc dice o no dice algo.
- `test-brain.sh:2672-2678` — `proteger-fuente`: "sin rutas hardcodeadas", "deriva de $HOME", "declarado en el MANIFEST" — tres greps al propio hook.

### D — estructura del repo / "no lo hagas así"
- `test-brain.sh:6397-6490` (e2/e2-skills) — todo `*.sh` está en el MANIFEST y viceversa; SKILLS-MANIFEST completo. Es un generador-consistencia legítimo (ver §5).
- `test-brain.sh:7060-7126` (e6c) — todo hook del MANIFEST está en el README y en el árbol raíz; los .svg dibujan las piezas vivas.
- `test-brain.sh:8429-8454` (#83, 2b/3c) y `7811-7936` (rm g1…g12) — "el SKILL.md contiene la frase X": `grep -qiE 'MISMO bloque|uninterrumpido|at[oó]mic' "$SKILL"` (`7846`), `grep -qiE 'LISTO = QA|QA del humano' "$SKILL"` (`7936`). ~22 asertos de que una prosa tenga ciertas palabras. Son los más débiles de la suite: no hay forma de que protejan el comportamiento; solo congelan el texto.
- `test-brain.sh:49,54` — `bash -n` de cada `.sh`. (Ver el bug del CI abajo: `bash -n` verde, `shellcheck` rojo.)

### E — no pueden fallar / PASS sin probar
- `test-brain.sh:2097` y `3998` — `ok "cmd LIVE: batería juez-Haiku real SALTADA …"` y `ok "dod LIVE: batería juez-dod SALTADA …"`: **una batería saltada se contabiliza como PASS.** Es la única batería que ejercita la clasificación real del juez (ver §3-B3).
- `test-brain.sh:1979-1983` y `3876` — en la batería LIVE, si el juez devuelve `UNAVAILABLE` (red/token caído) el caso hace `ok "… (infra flaky)"`. Un LIVE-ALLOW y un LIVE-DENY pasan cuando el juez no contestó.
- `test-brain.sh:6718` — `… && ok … || ok "e5: (sin retirados pendientes tras el apply — esperado)"`: las dos ramas son `ok`; no puede fallar.
- `test-brain.sh:5303` y `6425`, `7055`, `7112`, `7142`, `7345`, `7369` — `ok` sin condición visible en la misma sentencia (el aserto vive en un `if`/contador anterior); revisé varios y la condición existe aguas arriba, pero la estructura "ok colgado" dificulta ver qué se afirma. [INFER] riesgo de setup silencioso, no confirmé un caso vacío.
- Setup que se autodeclara: 27 asertos `(teeth)`/`(setup)` (p. ej. `test-brain.sh:3589`, `3607`, `3496`) comprueban que el escenario se montó antes de asertar. **Esto es lo correcto** y es de lo mejor de la suite.

---

## 3. Contraste con bugs escapados

Leyenda de causa: **NT** = no había test · **MOCK** = la decisión estaba mockeada · **FIX-IDEAL** = el fixture era una versión idealizada del caso real · **LÍMITE** = no se probó en el valor límite · **1D** = solo una dirección · **FORMA** = el test miraba la forma.

| # | Bug real (fuente) | Test de PROPÓSITO que lo habría cazado | Por qué la suite no lo cazó |
|---|---|---|---|
| 1 | **(a) `cerrar-slice.sh` `_ci_veredicto` glab: `glab mr view` falla → `st=""` → "sin CI" → mergea a ciegas** (`cerrar-slice.sh:109-137`; fix 2026-10-13) | Correr el script real con un `glab` stub que sale con 3 y aseverar rc≠0 + "no pude determinar el estado del CI" (existe hoy en `test-brain.sh:3426-3446`) | **MOCK.** La sección anterior (A2, 2026-10-11, `test-brain.sh:9034-9054`) usa `CLAUDE_CERRAR_SLICE_CI_MOCK`, que hace que `_ci_veredicto` devuelva el valor inyectado en su primera línea (`cerrar-slice.sh:111`): el mock **salta justo el parseo del forge**, que es donde estaba el bug. Probaba la decisión dado un veredicto, no el veredicto dado la realidad. |
| 2 | **(b) `rehidratar-hilo.sh`: faro a 13000 B, el harness trunca desde ~10 KB** (`rehidratar-hilo.sh:242-254`) | Hilo de ~11 KB → debe llevar faro (hoy `test-brain.sh:4164-4180`) | **LÍMITE.** El único test previo (`4147-4157`) usa 500 líneas ≈ 40 KB: pasa con 9000, con 13000 y con 30000. No distingue el umbral. El fix agrega un test que ancla la banda `(9000,13000)` y se autocomprueba. |
| 3 | **(c) `aviso-contexto.sh`: `"model":"<synthetic>"` como modelo → ventana default 200K** (`aviso-contexto.sh:67-94`) | Transcript real con último mensaje `<synthetic>` (error de API/límite) anterior a uno con modelo real → debe usar el real; si no hay, callar | **FIX-IDEAL + NT.** Los transcripts de fixture solo traían modelos reales/listados; ningún transcript con `<synthetic>`, que el harness sí produce. Además el default 200K estaba en el código (`3c.C3`: "el único default en código es `*) WINDOW=200000`") sin ningún test del caso "modelo desconocido → no inventes" hasta que Jordi lo pidió. |
| 4 | **`cerrar-slice --wait-ci` mergeó con CI pendiente** (`feedbackUsuarios/2026-10-09-cerrar-slice-wait-ci-no-espera-con-gh.md`) | `--wait-ci --dry-run` con checks `pending` → debe abortar/esperar | **NT.** La sección de cerrar-slice nace el 2026-10-11 como respuesta al reporte; antes `cerrar-slice.sh` no tenía ningún test de su ruta de CI [INFER por `git log` de la sección y su comentario "Causa del FP viejo"]. |
| 5 | **CI de develop ROJO 6 corridas: shellcheck SC2148 en 2 libs de control-gui** (`feedbackUsuarios/2026-10-09-ci-develop-rojo-shellcheck-sc2148.md`) | Un paso de CI que corra shellcheck sobre `brain/**/*.sh` (hoy fuera de la suite) | **FORMA equivocada + orden de CI.** La suite hace `bash -n` (`test-brain.sh:49,54,8979-8980`): pasa con un `.sh` sin shebang. Y como el paso shellcheck falla primero, **`test-brain` no corría en CI** esas 6 corridas. Un "verde técnico" que comprueba la propiedad equivocada. |
| 6 | **`aviso-drift-cerebro` marca como "SOBRAN" guards tier-`repo` (dod-verificar, juez-comun…) en repo personal — recurrencia 09-08 → 10-10** (`docs/guards-falsos-positivos.md`, `estado-proyecto.md` N4) | Repo personal con `dod-verificar.sh` (tier repo) en `.claude/hooks/` → NO debe marcarlo; con `git-branch-guard.sh` (tier both) → SÍ | **FIX-IDEAL.** El fixture (`test-brain.sh:4285-4288`) crea una fuente con UN hook, `git-branch-guard.sh`, vacío (`: >`), y un MANIFEST ausente. Nunca ejercita un hook tier-`repo`. Aserta el comportamiento del caso feliz (`4293`) y deja intacto el caso que falla en producción. |
| 7 | **`entorno-maquina-guard` mira el working tree, no lo staged (FP ×3: 09-16, 09-17, 09-24)** (`guards-falsos-positivos.md`; `feedbackUsuarios/2026-09-24-entorno-maquina-guard-mira-working-tree.md`) | `git commit` que solo toca `scripts/`, con `estado-proyecto.md` sucio y SIN stagear → silencio | **1D + FIX-IDEAL.** Los asertos (b2b, `2490-2535`) siempre hacen `git add` del archivo malo y esperan AVISA; el único caso "silencio" es contenido portable. Falta la combinación "archivo ofensivo existe, no está staged". |
| 8 | **`proteger-arbol` frena `branch -D` de ramas integradas por squash vía mini-develop (8+ FP frescos 10-05→10-11, B1)** | Repo con rama integrada por squash cuyo PR tiene como head la mini; el guard debe usar el estado del PR/MR | **FIX-IDEAL.** El "caso squash" del test (`2594-2600`) se arma con **`git cherry-pick`** de la rama, o sea patch-equivalencia perfecta. El real (squash de varias ramitas en una mini, 87-99 % de líneas) no tiene equivalencia por hash ni por cherry. El test prueba el caso que el guard ya sabía resolver. |
| 9 | **`merge-develop-guard` resuelve `TARGET_ROOT` por cwd, no por `--repo` (B4, "~10 rondas", casos 09-21, 09-30×4)** | `glab mr merge --repo <otro/repo>` desde cwd de plantilla, con grant durable solo en el repo destino → pasa | **Parcial.** Existe `test-brain.sh:1953-1960` (cross-repo con `.cwd=<destino>` y grant en el destino), pero resuelve por el `.cwd` **del payload**, que es la vía que sí funciona; el caso roto es `--repo` literal sin `.cwd` apuntando al destino [INFER; no reproduje]. B4 sigue "pending" en `estado-proyecto.md:70`. |
| 10 | **`dod-verificar` FP (cluster 10-01×6, 10-06, 10-09, 09-15, 09-18, 10-10; B3)** | Batería de frases reales de estatus/espera/QA-de-tooling → el juez clasifica CIERRE=no | **MOCK por diseño.** `dod()` (`test-brain.sh:3637-3647`) pasa el veredicto del juez como string (`CLAUDE_DOD_JUEZ_MOCK`) y solo prueba el flujo (¿tocó código? ¿hay navegador?). Los FP viven en la CLASIFICACIÓN, que solo cubre la batería LIVE, **opt-in** (`CLAUDE_DOD_JUEZ_LIVE=1`) y que cuando se salta suma `ok` (`3998`). Es la clase de bug que más se repite y la menos cubierta. |
| 11 | **`secret-scan` frena `Password=PRUEBA-no-real` en un test (B2; 6 casos)** | Commit con `Password=PRUEBA…` en `*/tests/*` → pasa; con `AKIA…` real → deny | **1D.** `test-brain.sh:2225-2429` prueban muchos secretos reales (deny) y los controles son "commit limpio", no "dato de prueba que parece secreto". El caso del corpus (placeholder en test) no tiene escenario. (Búsqueda: no hay `PRUEBA`/`placeholder` en la sección de secret-scan.) |
| 12 | **`barrer-ramas` borró un worktree recién creado (0 commits, con proceso dentro) y la remota de una mini-develop con nombre propio** (`feedbackUsuarios/2026-10-09-barrer-ramas-worktree-recien-creado.md`, `…10-03-…mini-develop-con-nombre-propio.md`) | Worktree nuevo en `origin/develop` sin commits + proceso con cwd dentro → el barrido no lo toca; `epic-*` con HEAD = develop → no se borra | **NT.** `grep` de "recién creado / 0 commits propios / cwd de proceso" en la suite devuelve solo un caso de zombie `gone SIN commits propios` (`3122`) que prueba lo contrario: que SÍ se barre. El caso límite "HEAD == develop pero vivo" no está. |
| 13 | **`pkill -f`/`pgrep -f` que se mata a sí mismo — "cuántas veces a la semana"** (`feedbackUsuarios/2026-10-11-guard-pgrep-f-autokill.md`) | Un guard que detecte el patrón + su test | **NT: norma sin mecanismo.** La regla vivía en `entorno-maquina.md` y memorias; se repetía. Es el caso de manual de "toda norma nace con su mecanismo": no hay test porque no hay guard. |
| 14 | **El fix de timeouts de `dod-verificar` (09-16) NO llegó a 5 de 6 copias por-repo** (`feedbackUsuarios/2026-09-24-dod-verificar-el-fix-de-timeouts…`) | Un test sobre las copias DESPLEGADAS/`settings.json` cableado, no sobre la fuente | **Capa equivocada.** (b4z, `4005-4040`) valida la coherencia de timeouts en la **fuente** del hook y es correcto ahí; el bug estaba en la propagación. Lo cubre en parte (e6d) "settings.json semilla cabla…", no los valores. |
| 15 | **`git-branch-guard`: `git push -q origin develop` en un bare desechable / `pgrep -af` con "push"** (corpus 09-11, 09-17) | Comandos reales del corpus como escenarios | **Cubierto tras el hecho:** los FP históricos se fueron absorbiendo como casos (por eso la sección b1d es la más sólida). Muestra que el patrón "FP del corpus → escenario" funciona cuando se aplica; solo que se aplicó caso por caso, sin mecanismo que lo obligue. |

### Qué dice el conjunto
- De las 15 filas, **solo 1 (la 14, parcialmente) es "test de forma"**. Dominan: MOCK (1, 10), FIX-IDEAL (3, 6, 7, 8), LÍMITE (2), NT (4, 12, 13), 1D (7, 11), CI/orden (5).
- **El patrón común:** el test existe y pasa, pero ejercita el *caso feliz del autor*, no el caso del corpus. El corpus de FP (`guards-falsos-positivos.md`, 171 líneas) y los reportes (`feedbackUsuarios/`, ~33) son el material de escenarios que la suite aprovecha **de forma desigual**: git-branch-guard sí, entorno-maquina-guard/aviso-drift/proteger-arbol/secret-scan/barrer-ramas no.
- Los "mocks" no son malos en sí (`CLAUDE_DOD_JUEZ_MOCK` está bien documentado como "flujo, no clasificación"); el defecto es que **la mitad no mockeada queda opt-in y cuenta PASS cuando se salta**.

---

## 4. Prevención (mecanismos, ordenados por retorno)

Todos genéricos (aplican a cualquier proyecto con una suite en shell/pytest/xunit); entre paréntesis, cómo se haría cumplir.

### 1. "Todo bug escapado nace con su escenario ROJO contra el código viejo" — retorno MUY ALTO, costo medio
- **Qué:** en un commit/MR `fix(...)`, el CI toma los tests nuevos/cambiados de ese commit, los corre contra el árbol del **padre** (código viejo) y exige ≥1 FALLO; luego contra HEAD y exige verde.
- **Por qué:** es exactamente lo que se hizo a mano en los 3 bugs de hoy ("FALLA contra el código viejo"). Esa disciplina existe en la norma ("al agregar cobertura, comprueba que tu test FALLA contra el código viejo") pero sin mecanismo. Cierra NT, MOCK y FIX-IDEAL de golpe, porque obliga a reproducir el caso real.
- **Cumplimiento:** job de CI `fix-needs-red-test` (script ~30 líneas: `git worktree add padre; copiar solo los archivos de test de HEAD; correr; esperar rojo`). Exención explícita y auditable `Sin-test: <razón>` en el mensaje del commit, contada en un reporte semanal.
- **Cobertura:** ataca ~11 de las 15 filas de §3.

### 2. Harness de ESCENARIOS en tabla, con corpus como fuente y las dos direcciones obligatorias — retorno ALTO, costo medio
- **Qué:** `brain/scenarios/<hook>.tsv` con columnas `id | origen (línea del corpus/reporte) | entrada real (comando/transcript/repo-recipe) | esperado (deny/allow/avisa/calla)`. Un runner único (`run-scenarios.sh`) ejecuta el hook real y compara efecto. Los transcripts y comandos salen del corpus anonimizados, no escritos a mano.
- **Reglas verificadas por un lint:** (a) cada hook-guard debe tener ≥1 fila `deny` y ≥1 fila `allow` (dos direcciones); (b) cada línea de `docs/guards-falsos-positivos.md` debe llevar un `[esc:ID]` que apunte a su fila — el lint falla si una línea de corpus no tiene escenario (un FP registrado y sin escenario es deuda visible); (c) las filas con `origen` real pesan más que las sintéticas en el reporte de cobertura.
- **Fixtures reales:** repos git montados por receta (`git-recipe`), con el caso "squash vía mini", "archivo sucio no staged", "hook tier-repo en repo personal", "transcript con `<synthetic>`". Se versionan las recetas, no los repos.
- **Cumplimiento:** el lint corre en CI; la tabla es el único lugar donde se agregan escenarios de guards, y es más barata de escribir que un bloque de 12 líneas de bash (baja la fricción: nacen más).

### 3. Lint de asertos + contador de "tipo de test" — retorno ALTO en E/C, costo BAJO
- **Qué:** análisis estático (≈40 líneas de awk/python) que **falla el CI** si:
  - un `ok` está en la rama `||` o `else` de otro `ok` (`6718`): no puede fallar;
  - un test "SALTADA" suma al conteo de PASS: los saltos se cuentan aparte (`SKIP`) y se reportan; un `SKIP` en CI es rojo salvo allowlist;
  - un `ok` acepta `UNAVAILABLE` como éxito (`1983`, `3876`): el LIVE debe distinguir `PASS/FAIL/SKIP`;
  - un aserto cuyo **único** sujeto es `grep` sobre una ruta bajo `brain/`/skills/widgets (`$SCRIPT_DIR`, `$HOOKS`, `$SKILL`, `$QML9`…) y no lleva la etiqueta `# estructura: <razón>` (§5). Y: no se admite grep a prosa de un `SKILL.md` ("la doc dice X") sin etiqueta.
- Cada `ok` lleva prefijo de categoría (`[E]` escenario / `[P]` plomería / `[S]` estructura); el resumen final imprime `% escenario` y el CI falla si baja de un piso (ratchet: solo puede subir).
- **Cumplimiento:** paso de CI + pre-commit local. Es el mecanismo anti-regresión de la propia convención.

### 4. Mutation testing ligero sobre los hooks tocados — retorno ALTO (cierra LÍMITE y 1D), costo medio-alto
- **Qué:** un script `mutar.sh <hook>` aplica ~10-20 mutaciones mecánicas al `.sh` (invertir `-gt`/`-ge`, cambiar una constante numérica ±1 orden de magnitud, borrar una emisión de `deny`, convertir `exit 0` en `exit 1`, borrar una rama `case`), corre SOLO la sección del hook y exige que **cada mutante muera** (algún `bad`). Un mutante vivo = hueco de test.
- **Qué habría cazado:** `13000 → 9000` y `9000 → 13000` (bug b); borrar la rama `<synthetic>` (bug c); borrar el chequeo `type=="object"` (bug a, si no hubiera mock).
- **Costo/uso:** nocturno o por-PR sobre los hooks que el diff toca (no sobre toda la suite). Reporte de mutantes sobrevivientes, no gate duro al principio (ratchet).
- **Cumplimiento:** job CI `mutar --changed` que falla si sobrevive un mutante *en una línea tocada por el diff* (precisión alta, ruido bajo).

### 5. "Qué mockeo" declarado + el tramo mockeado también se prueba — retorno MEDIO-ALTO, costo bajo
- **Qué:** cada test que usa `*_MOCK`/stub declara `# mockea: <qué>` y `# cubierto-sin-mock-en: <id>`. El lint exige que haya un test del mismo hook que corra **sin** ese mock (con el forge/juez/FS reales stubbeados a nivel de transporte, no de decisión: p. ej. el `glab` falso de `3426`, no `CLAUDE_CERRAR_SLICE_CI_MOCK`).
- **Para el juez LLM:** modo **grabar/reproducir**: las respuestas reales del juez a las frases del corpus se graban una vez (fixtures versionados) y la batería corre en CI en modo reproducción, sin red, sin token y sin flakiness. La batería LIVE queda para re-grabar. Así B3 (el cluster más repetido) deja de depender de un opt-in.
- **Cumplimiento:** lint + CI.

### 6. Valores límite derivados del código — retorno MEDIO, costo bajo
- **Qué:** para cada umbral/constante nombrada de un hook (`REHIDRATAR_FARO_BYTES`, plazos, tamaños), una regla: debe existir un test a `umbral-1`, `umbral` y `umbral+1`, **y** uno en el valor medido del sistema real (aquí 10 KB). Un helper `probar_umbral` genera los tres.
- **Cumplimiento:** el lint lista constantes `*_BYTES|*_SECS|*_MAX` sin test de frontera (informativo al inicio).

### 7. CI que no oculta tests / orden del CI — retorno MEDIO, costo trivial
- Correr `shellcheck` y `test-brain` en jobs paralelos o con `if: always()` (bug 5: 6 corridas sin que corriera la suite). Y un `shellcheck` sobre `brain/**/*.sh` como parte del contrato, no solo `bash -n`.

### Cómo se despliega a otros proyectos
Los 7 son independientes del stack. El paquete mínimo reutilizable: (1) `fix-needs-red-test`, (3) lint de asertos, (2) formato de escenarios tabla. Empaquetables como skill + script en el cerebro (`brain/skills/`), con tier `both` para que viaje a repos compartidos.

---

## 5. Qué conservar (no tirar lo bueno con lo malo)

C/D con valor legítimo:
- **Guards de regresión contra cuelgue/lentitud medidos:** `test-brain.sh:2471` (commit grande limpio ≤3 s), `4005-4040` (b4z, coherencia de timeouts: el crédito del juez cabe bajo el timeout del harness — es un invariante cuantitativo), el hilo que colgaba el chequeo O(n²) (`4154`). Son D en forma, A en intención.
- **Drift fuente-única del MANIFEST** (`6397-6490`, `7060-7153`, `6538-6670`): son generadores de consistencia (README/árbol/roster/widget ↔ MANIFEST). La norma "doc = reflejo de la realidad" no tiene otro mecanismo; `e6c`/`e3c` han evitado que hooks retirados queden como fantasmas. Conservar; etiquetar `# estructura:` y no ampliar con más greps de identificadores.
- **`.ps1` ASCII puro** (`6247`): protege un fallo real y medido de PowerShell 5.1 (caso real citado en el comentario). Conservar.
- **`e6.3` "sin `$HOME` absoluto hardcodeado"** (`6924`) y las paridades `e6.4/e6.5` del **escape de ruta** (`6961-6971`): detectan una clase concreta (inyección/rutas) sin otro mecanismo. [INFER] mejor convertidas a un test funcional con una ruta con espacio y comilla en un tmpdir, pero mientras no, valen.
- **Tests de "norma → mecanismo"** como `8950-8957` (H5: el código vivo no ofrece "la web" como escape de un juez) y `7653-7655` (g4): son el mecanismo de una norma dura ("toda norma nace con su mecanismo", "NUNCA ofrezcas el clic en la web"). Conservar. Falta convertirlos en comportamiento: instalar y verificar que el `CLAUDE.md` global resultante trae la norma (el efecto), no que el archivo fuente la contenga.
- **`bash -n`/`jq empty`** (a): smoke barato; solo debe dejar de venderse como "calidad de lint".
- **Los 27 asertos `(teeth)/(setup)`:** son el patrón correcto; generalizar (lint: todo escenario declara su precondición).
- **`(e2e)` reubicar-master sobre `$HOME` falso** (`8458-8869`, incl. `8869` "el `~/.claude` real quedó intacto"): efecto real, aislamiento comprobado.

Candidatos a **borrar o convertir**:
- Los ~22 greps a prosa de `SKILL.md` (rm g1-g12 `7811-7936`, r2-4 `8331-8346`, #83 `8429-8443`, 2b/3c `8451-8454`): congelan texto. Si la regla importa, vive en un script con test (como ya hizo `reubicar-master.sh`); si no, borrar.
- Los 17 de widgets `(e9)` `7237-7247`: o se prueban los widgets (build + render) o se declaran fuera de la suite.
- Los 3 "SALTADA/UNAVAILABLE=ok" (§2-E): arreglar, no borrar.

---

## 6. Limitaciones de esta auditoría
- No ejecuté la suite ni leí los 1314 asertos uno por uno. A/B son estimaciones por sección; C, D y E sí fueron revisados individualmente.
- La heurística automática subestima A (muchos `ok` de efecto en `$HOME` falso se parecen a "estructura") y la corregí leyendo las 121 sentencias marcadas.
- Para los bugs 1-3 el código ya está corregido en el worktree; el "qué faltaba antes" lo reconstruyo de los comentarios de los tests nuevos y del historial. Para 6-12 la causa es lectura del fixture, no reproducción del bug.
- Los números de "FP del corpus" por hook los contaré de `docs/guards-falsos-positivos.md` sin ordenar por duplicados; no se contrastó 1:1 contra cada línea del corpus (≥40 entradas leídas, ~10 mapeadas a su escenario).
