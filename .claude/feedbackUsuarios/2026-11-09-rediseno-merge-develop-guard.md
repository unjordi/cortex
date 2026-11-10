# Rediseño de merge-develop-guard — decisión de unjordi, 2026-11-09 (vía claudio-master)

[user 2026-11-09: "Impedir el push directo a develop/main está mal y justo ya habíamos decidido quitarlo del guardián y dejarlo únicamente como aviso cuando el guardián detecte que no está protegido el repo, hacerlo con lo que ahora sé que se llama árbol shfmt, y un juez haikú"]
[user 2026-11-09: "justo venimos de un montón de tunning, que siempre que lo hacemos mecánico, falla"]
[user 2026-11-09: "Ahorita me preocupan más los frenos en falso, apretar más ese guardián solamente nos va a causar más falsos positivos"]

No había registro previo de esta decisión en memorias de cortex/axon/plantilladotnet ni en transcripts de 120 días (Mac y cachy); vale desde hoy.
axon no tiene este diseño: su git-guard.ts es un port del mismo ruleset de regex (paridad 84 casos contra el .sh); lo que sí aporta son tools de git estructuradas y que protege la mini-develop en el servidor al sembrarla.

## Diseño
1. **El push directo a develop/main ya no se frena.** Lo impide el servidor (ramas protegidas). El guard solo AVISA (additionalContext, no bloquea) cuando un push va a develop/main y detecta que en ESE repo la rama NO está protegida en el servidor (GitHub: `gh api repos/<slug>/branches/<rama>/protection`; GitLab: `glab api projects/:id/protected_branches/<rama>`), con caché por sesión. Si no puede saberlo, no dice nada.
2. **Qué es cada comando lo dice el árbol de shfmt**, no regex: comandos reales vs comentarios, comillas, heredocs y texto citado; cada comando con su propio -C/--git-dir/cd. Sin shfmt: modo degradado anunciado.
3. **Lo que queda en el guard es lo que el servidor no ve:** el merge de MR/PR a develop (squash + borrar rama salvo la mini) y la AUTORIZACIÓN (OK del usuario, grant) para develop en repos coordinados y para main siempre. Detección del merge = AST; la autorización la decide el juez Haiku con la conversación.
4. **Lo ambiguo lo decide el juez Haiku**, no una regla mecánica nueva. Nada de «DENY conservador» por patrón.
5. **Cero frenos en falso** en el corpus de docs/guards-falsos-positivos.md + batería de comandos diarios legítimos = condición de release, igual que cero evasiones del merge a main.
6. Lo que se retira (PASO 0 como freno y sus regex de evasiones de push) se borra, no se deja comentado; los diagramas 03/06/07 se rehacen con el diseño nuevo.

## Antecedente encontrado (corrige «no había registro previo»)
La decisión de fondo es del 2026-10-21, en .claude/feedbackUsuarios/2026-10-21-ok-retirar-git-branch-guard.md: retirar git-branch-guard, nada de pre-filtro determinista [user: "no confío nada en lo determinista. Lo deprecamos por inútil"], y el repo/destino se resuelve POR GIT y preguntándole a gh/glab con los mismos argumentos, nunca por análisis del comando [user: "la resolución de \"qué repo estamos afectando\" VA POR GIT!! YA LO HABÍAMOS DICHO UN MONTÓN! NO POR ANÁLISIS DE COMANDO"]. El freno al push directo se conservó entonces por indicación de claudio-master (repos sin protección como PowerScripts); hoy unjordi lo reemplaza por el aviso.

---
# Re-auditoría del rediseño (481f7f15) — claudio-master, 2026-11-09 tarde
claudio verificó en el código C1 (merge-develop-guard.sh:313, `case "$cmd" in *git*|*glab*|*gh*` sobre el texto crudo antes del AST) y C2 (ACG_ES_MERGE_MR_JQ, analizar-comando-git.sh:434, compara `.exe=="gh"/"glab"` literal). Los frenos en falso casi desaparecieron; quedan evasiones del merge a main.

## Cómo cerrar, sin volver al regex ni a frenos en falso (criterio de claudio-master, según las decisiones de unjordi)
1. **Sin pre-filtro de texto.** Con shfmt presente, el AST corre siempre (es barato). El pre-filtro solo vale en modo degradado.
2. **Ejecutable**: compara el basename en minúsculas (macOS no distingue mayúsculas) y pela también exec/watch/xargs/time/nice/nohup/command además de env/sudo.
3. **Lo que el árbol no puede afirmar va al JUEZ, no pasa**: ejecutable opaco ($VAR, $(…)), eval/source/bash -c/sh -c con cuerpo no literal, process substitution, parseo fallido de shfmt — SOLO si en el árbol aparece un token `merge`/`accept` (o el cuerpo literal lo contiene). Así no se manda al juez cada comando opaco. El juez decide con la conversación y destino DESCONOCIDO (y el piso de main aplica).
4. **Merge por API** (`gh api … pulls/<n>/merge`, `glab api … merge_requests/<n>/merge`, `curl` a la API de la forja con `/merge`): es un merge; el número sale de la ruta y el destino se le pregunta a la forja igual que con `gh pr merge`.
5. **Repo por git, por comando**: el directorio donde corre CADA comando según el árbol (cd previo en su mismo subshell; el `-C`/`--work-tree` de OTRO comando no cuenta; `GH_REPO=`/`GITLAB_*` en la asignación de ESE comando sí cuentan, porque gh/glab los usan). Nunca el texto completo.
6. **Frenos en falso que quedan** (condición de release): L268 (PR nombrado por su rama: pregúntale a gh/glab por la rama), L284 (cwd no git), OK dentro de un slash-command, «release 1.4 a main», «…, sin squash», «…, no hay pendientes».
7. **Aviso**: GitLab compara con los comodines de protected_branches (`*`, `dev*`); GitHub usa `gh api repos/<slug>/branches/<rama>` y su campo `protected` (lo puede leer quien no es admin) en vez de /protection (404 para no-admin); `git push -u origin HEAD` resuelve HEAD a la rama actual; el `-C` de otro comando no cuenta.
8. **Pruebas**: b1d-merge-ast debe incluir los disfraces de C1/C2 y fallar contra 481f7f15; la batería de cierre del bloque 5 corre contra el guard COMPLETO.

## Dictamen del auditor
# Auditoría del rediseño de `merge-develop-guard` — rama feat/shfmt-tokenizer @ 481f7f15 — 2026-11-09

Contexto leído: `cortex/.claude/feedbackUsuarios/2026-11-09-rediseno-merge-develop-guard.md` y la sección «Decisiones de unjordi sobre el PASO 3» de `2026-10-21-ok-retirar-git-branch-guard.md`. El push directo a base ya no se frena: no lo reporto como evasión.

Método: arnés aislado en `/tmp/mdg` (ya borrado), con stubs de `gh`, `glab`, `curl` y `security` por PATH; `shfmt` 3.13.1 real; `TMPDIR` aislado; `ACG_PATH_AUGMENT=0`; sin API real, llavero, `~/.claude` ni push. El juez se controla con un `curl` stub, así que el veto de cita y el piso de main corren con su código real. Ejemplos: en el repo compartido, PR 9 → main y PR 10 → develop; en el personal, PR 7 → develop y PR 9 → feat/q. Juez = DENY salvo que se indique.

## Resumen

| Severidad | # | Hallazgos |
|---|---|---|
| CRÍTICO | 2 | C1 el pre-filtro de texto deja pasar cualquier comando sin el literal `gh`/`glab`, sin llegar al árbol · C2 el ejecutable se compara en minúsculas exactas y no se gatea cuando es opaco o va tras un envoltorio desconocido |
| ALTO | 3 | A1 si shfmt no parsea el comando, se cae a regex en silencio · A2 el merge por la API (`gh api`, `glab api`, `curl`) no se gatea, y el «respaldo del servidor» no lo cubre · A3 el repo del merge se sigue resolviendo por texto: un `-C`, `--work-tree`, `(cd X)` o `GH_REPO` de otro comando lo desvía |
| MEDIO | 5 | M1 tres frenos en falso del corpus siguen vivos · M2 el OK dentro de un slash-command y releases legítimos se frenan · M3 avisos falsos o perdidos en GitLab, en GitHub y con `-C` lateral · M4 la detección es por AST, pero el MR-id y la herramienta se sacan del texto ya despojado · M5 las pruebas nuevas no cubren lo que el AST debía arreglar |
| BAJO | 3 | B1 `git push -u origin HEAD` en develop no avisa · B2 en modo degradado, texto citado en varias líneas cuenta como merge · B3 `gh pr merge --merge #9` (comentario) |

---

## Evasiones del merge a main o a develop coordinado

### C1 — CRÍTICO · El pre-filtro de texto se salta el árbol
- **Dónde:** `merge-develop-guard.sh` (bloque «PRE-FILTRO barato»): `case "$cmd" in *git*|*glab*|*gh*) : ;; *) exit 0 ;; esac`.
- **Repro (MEDIDO, repo compartido, PR 9 → main):** `g""h pr merge 9 --merge`, `g''h pr merge 9 --merge`, `"g"h pr merge 9 --merge`, `g\h pr merge 9 --merge` → **PASS**. El shell las ejecuta como `gh`; el árbol las resuelve bien (`acg_ast_json` da `exe:"gh"`), pero nunca llega a correr porque el texto crudo no contiene el literal `gh`.
- **Arreglo:** quitar el pre-filtro, o aplicarlo sobre el árbol (y en modo degradado, sobre el texto des-entrecomillado). Prueba: los cuatro comandos → DENY de release.

### C2 — CRÍTICO · El ejecutable efectivo se compara literal y no se gatea cuando es opaco o desconocido
- **Dónde:** `analizar-comando-git.sh:434` (`ACG_ES_MERGE_MR_JQ`: `$x=="gh"`/`"glab"`) y `effidx` (:156-166).
- **Repro (MEDIDO, compartido, PR 9 → main; todos PASS):**

| Comando | Por qué pasa |
|---|---|
| `GH pr merge 9 --merge`, `Gh pr merge 9 --squash --delete-branch` | En macOS (APFS no distingue mayúsculas) ejecuta gh; el guard compara en minúsculas exactas |
| `G=gh; $G pr merge 9 --merge` | Ejecutable opaco, no se gatea |
| `exec gh pr merge 9 --merge`, `watch -n1 gh pr merge 9 --merge` | `exec` y `watch` no están en la lista de envoltorios |
| `echo 9 \| xargs -I {} gh pr merge {} --merge` | `-I` consume `{}` y `effidx` no lo sabe: toma `{}` como ejecutable |
| `source /dev/stdin <<<'gh pr merge 9 --merge'` | `source`/`.` no está en la lista de intérpretes |
| `bash <(echo 'gh pr merge 9 --merge')` | Sustitución de proceso: el código va en un argumento de `echo` |

- Sí detecta: `</dev/null gh …`, `"gh" …`, `gh "pr" "merge"`, `bash -c`, `bash -lc`, `eval`, `bash <<<`, `bash -s <<EOF`, función, `$( … )` y `xargs gh pr merge` sin `-I`.
- **Arreglo, en el espíritu del diseño («lo ambiguo lo decide el juez»):** comparar el basename en minúsculas; si en un comando aparecen las palabras `pr merge` o `mr merge|accept` y el ejecutable efectivo es opaco o no es `gh`/`glab`, tratarlo como merge con destino desconocido y mandarlo al juez, en vez de dejarlo pasar. Agregar `exec`, `watch` y `source`/`.` a las listas, y los flags que consumen valor de `xargs` (`-I`, `-n`, `-P`, `-L`, `-s`, `-E`). Prueba: la tabla → DENY.

### A1 — ALTO · Si shfmt no puede parsear el comando, se cae a regex en silencio
- **Dónde:** `acg_ast_json` (:189-209) devuelve 1 si el parseo falla; `acg_es_merge_mr` cae entonces a `acg_es_merge_mr_regex`. No se pone la nota de modo degradado porque `acg_ast_disponible` sigue siendo verdadero.
- **Repro (MEDIDO):** `declare -A m=([a b]=1)` es bash válido que shfmt 3.13.1 rechaza. `declare -A m=([a b]=1); </dev/null gh pr merge 9 --merge` → **PASS**; `declare -A m=([a b]=1); "gh" pr merge 9 --merge` → **PASS**. Vuelven las evasiones de la regex vieja, sin ningún aviso.
- **Arreglo:** si shfmt falla el parseo y el texto contiene `merge`/`accept` cerca de `pr`/`mr`, tratarlo como merge con destino desconocido (al juez) y anunciarlo. Prueba: los dos comandos → DENY.

### A2 — ALTO · El merge por la API no se gatea y el servidor no lo respalda
- **Repro (MEDIDO):** `gh api -X PUT repos/org/shared/pulls/9/merge -f merge_method=merge`, `glab api -X PUT projects/:id/merge_requests/9/merge` y `curl -X PUT … https://api.github.com/repos/org/shared/pulls/9/merge` → **PASS**.
- Está documentado como «residual aceptado con respaldo del servidor (ramas protegidas)». Pero una rama protegida no impide un merge de PR por la API: es la misma operación que `gh pr merge`. Con el PASO 0 retirado, este gate es el único freno a un merge a main por CLI.
- **Arreglo:** con el árbol es barato: un comando `gh api`/`glab api` cuya ruta termina en `/merge`, o un `curl` a `api.github.com`/`/api/v4/` con `/merge`, se trata como merge con destino desconocido (al juez). Prueba: los tres → DENY.

### A3 — ALTO · El repo del merge se sigue resolviendo por texto, no con los mismos argumentos que usaría gh
- **Dónde:** `acg_target_dir` (:298-345) busca `-C`, `--work-tree`, `--git-dir`/`GIT_DIR` y `cd` en el comando ENTERO, con regex. `acg_target_remote` ignora `GH_REPO`. Va contra la decisión #4 de unjordi («se le pregunta a la herramienta con los mismos argumentos»).
- **Repro (MEDIDO; cwd = compartido, PR 9 → main; `org/personal#9` → feat/q):**
  - `git -C …/personal fetch; gh pr merge 9 --merge` → **PASS**
  - `git --work-tree=…/personal status; gh pr merge 9 --merge` → **PASS**
  - `(cd …/personal && git status); gh pr merge 9 --merge` → **PASS**: el `cd` vive en un subshell, pero el guard lo aplica igual.
  - Desde el repo personal: `GH_REPO=org/shared gh pr merge 9 --merge` → **PASS**.
  - En todos, el guard consultó `org/personal#9` y gh habría mergeado `org/shared#9` → main.
- **Arreglo:** que el árbol dé el cwd efectivo del COMANDO de merge (los `cd` previos en el mismo nivel, no dentro de subshells; los `-C` de otros comandos no aplican) y sus asignaciones `GH_REPO`/`GITLAB_HOST` (más un `export` previo). Consultar `gh pr view <args de selección del merge>` desde ese dir con ese entorno. Prueba: los cuatro → DENY.

---

## Frenos en falso (prioridad de unjordi)

### M1 — MEDIO · Tres casos del corpus siguen frenando
Corrí los casos reproducibles por estructura de `docs/guards-falsos-positivos.md` (los de criterio del LLM no son reproducibles offline).
- **Pasan (MEDIDO):** L31 (`--repo` de un repo personal desde un cwd compartido), L32/L139/L153 (`git commit -F - <<EOF` que menciona el merge), L33 (`cat > doc.md <<EOF` con `glab.exe mr merge`), L47/L64/L125/L138 (`printf … >> docs/fp.md` con el merge citado), L90/L154 (`python3 - <<PY` cuyo texto cita el merge), L104/L219 (MR hacia la mini; la mini sin borrar), L107 (`--body "$(cat <<EOF…)"`), L140 (`cat > qa.py <<EOF`), L161/L175/L225 (`--repo` a un hermano con grant), L191 (`…; M=…; git -C $M pull`), L229 (`grep -c 'gh pr merge'`) y L286 (`cerrar-slice … ; glab schedule run 4319522`).
- **Siguen frenando (MEDIDO):**
  - **L268:** `cd …/personal && git worktree list && gh pr merge feat/x --repo org/personal --squash --delete-branch` → DENY «no pude confirmar el destino». El PR se nombra por su rama; `acg__mrid_de_tokens` solo acepta números, aunque `gh pr view feat/x` lo resolvería. Lo mismo pasa con `gh pr merge --squash --delete-branch` sin argumento (el PR de la rama actual).
  - **L284:** con cwd que no es git (`/tmp`), `gh pr merge 442 --repo org/personal --squash --delete-branch` → DENY. Sin clon local cae al juez; la decisión #5 dice «sin clon local → la marca se consulta en la forja», y eso no está implementado.
  - **(Por el texto)** Cuando el comando trae el ejecutable entrecomillado (`"gh" pr merge 7 …`), en el repo personal pasa al juez con destino desconocido: el MR-id se saca del texto despojado (ver M4).
- **Arreglo:** pasarle a `gh pr view`/`glab mr view` el selector tal cual (número, rama o URL); implementar la marca por la forja; sacar el id del árbol (M4).

### M2 — MEDIO · Un OK dentro de un slash-command y releases legítimos se frenan
- **Batería diaria: pasa todo (MEDIDO):** push a ramita con comentario, `git push -u origin HEAD`, `git config push.default current && git push`, `git config --global alias.st status`, heredoc a `git commit -F -`, `gh pr create --base develop --fill`, `gh pr view 7 --json …`, `gh pr merge 7 --squash --delete-branch` y `-s -d` en personal, la mini sin borrar (`gh pr merge 13 --squash`, `glab mr merge 58 --squash --yes`), `glab mr merge 57 --squash --remove-source-branch --yes`, `cerrar-slice.sh --id 7` en personal, y un merge con `--body "$(cat resumen.md)"`.
- **Con juez ALLOW y la cita real (MEDIDO):**
  - Pasan: «mergea a develop el PR 10», «libera a main el 9».
  - **Se frenan:**
    - El mismo OK dado como `<command-args>mergea a develop el PR 10</command-args>` → DENY, con el mensaje engañoso «no pude LEER la conversación».
    - «release 1.4 a main» → DENY: el número de versión se toma como id de otro MR.
    - «libera a main el 9, sin squash» → DENY.
    - «sí, ya libera a main, no hay pendientes» → DENY.
  - Controles que deben frenar y frenan: «todavia NO hagas el release, espera» y «libera a main el PR 390».
- **Contra el diseño:** el piso de main (`acg_lexico_release_afirmativo_para_mr`) es justo la «regla mecánica» que el diseño quería sustituir por el juez. Recomiendo que el piso exija solo que haya léxico de release en una línea USUARIO cuya cita sea la que el juez usó, y que la polaridad y el MR los decida el juez. Para `command-args`: no descartarlo (es texto del usuario).

### M3 — MEDIO · El AVISO: nunca bloquea, pero avisa en falso y a veces no avisa
- **Bien (MEDIDO):**
  - GitHub 404 → aviso; 200 → silencio; 500 → silencio; 403 «Upgrade to GitHub Pro» → aviso una sola vez por sesión.
  - Silencio en: ramita, pelón en ramita, `HEAD:develop` con 404 (sí avisa), pelón parado en develop con 404 (sí avisa).
  - GitLab con develop en la lista → silencio.
  - Un compuesto push+merge lo decide el gate de merge.
  - Nunca hubo `deny` por el aviso.
- **Avisos falsos o perdidos:**
  - **GitLab, comodines (MEDIDO):** si la protección es `*` o `dev*`, `git push origin develop` → AVISO falso (se compara `.name==rama` exacto). Además, la API pagina de 20 en 20: con más de 20 reglas, develop puede caer en la página 2 [RAZONADO].
  - **GitHub, 404 ambiguo [RAZONADO]:** `GET …/branches/<b>/protection` responde 404 también cuando la rama está protegida por un *ruleset* (la forma actual de proteger) y cuando el usuario no es admin. El aviso diría «NO está protegida» en falso. Distinguir por el cuerpo (`"Branch not protected"` frente a `"Not Found"`) y consultar también `repos/<slug>/rules/branches/<b>`.
  - **`-C` de otro comando (MEDIDO):** cwd = glrepo y `git -C …/personal status; git push origin develop`. Avisa en falso cuando el repo real está protegido y el lateral no; calla cuando es al revés. Misma causa que A3.
  - **B1:** `git push -u origin HEAD` parado en develop no avisa (MEDIDO): `HEAD` cuenta como refspec de ramita. Es la forma que Claude usa más seguido.

### M4 — MEDIO · La detección es por árbol, pero el id y la herramienta salen del texto despojado
- **Dónde:** `acg__destino_de_mr_full` (:655-658) hace `u=$(acg_despoja_comillas "$raw")` y luego `acg_mrid "$u"` y `grep 'glab…mr'` sobre `u`. Con `"gh" pr merge 9 …`, el árbol detecta el merge, pero el texto despojado queda en ` pr merge 9` y el id sale vacío.
- **Efecto (MEDIDO):** destino desconocido. En compartido es fail-safe, con el mensaje «integrar a develop SQUASHEA» aunque sea un release. En personal es un freno en falso.
- **Arreglo:** pasar `$raw` a `acg_mrid` y sacar la herramienta del `.exe` del árbol.

### M5 — MEDIO · Calidad de las pruebas nuevas
- **b1d-merge-ast:** prueba en las dos direcciones y los dos carriles, pero con casos que la regex vieja YA resolvía (`sudo glab…`, `env X=1 gh…`, `bash -c`, `echo …`). Fuera de las aserciones sobre `.eff`/`.exe` (función nueva), **no fallaría contra el código viejo**. No hay ningún caso de lo que motivó el árbol (`</dev/null gh…`, `"gh" pr merge`, `bash <<<`, `bash -s <<EOF`, el apóstrofo en un comentario), ni de C1, C2 o A1.
- **b1d-aviso:** buena: mide el efecto (aviso o silencio, nunca deny), caché por sesión, 403 una sola vez, cero falsos positivos en ramita, opaco, pelón en ramita, forja desconocida y `echo`. Falla contra bde38381. Faltan: comodines de GitLab, 404 por ruleset, `-C` lateral, `push -u origin HEAD`. El caso compuesto `git push origin develop && glab mr merge 5 --yes` frena por «falta --squash», no por el gate: cambiar a `--squash --remove-source-branch` para que pruebe lo que dice.
- **b1d-nojq:** correcta y mide el efecto. `gh pr merge 5` sin jq → DENY es trivial (el grep crudo ve `pr merge`), pero sirve como red mínima.
- **b1d-push-retirado:** correcta: los seis casos fallan contra 1adca68a (que denegaba) y pasan ahora.
- **Falta:** una batería de «corpus de FP + comandos diarios» que corra el guard completo, como condición de release (punto 5 del diseño). Los casos de M1 y M2 servirían de semilla.

---

## Modo degradado (sin shfmt)
- **Se anuncia (MEDIDO):** el veredicto (PASS o DENY) de un merge detectado lleva «⚠️ MODO DEGRADADO (sin shfmt)…»; con shfmt presente no.
- **No abre evasiones peores que antes (MEDIDO):** son las mismas de la regex anterior: `</dev/null gh…`, `"gh" …` y `bash <<<'…'` → PASS, sin anuncio (porque no se detectaron). `exec gh pr merge` sí se detecta en degradado; en el carril AST no (C2).
- **B2:** en degradado, un `git commit -m '…⏎NO usar gh pr merge 9 a mano'` se detecta como merge. Pasó porque el PR 9 del personal va a feat/q; con un destino de base sería un freno en falso.
- El aviso no corre en degradado. Es correcto: sin árbol, mejor silencio que falso positivo.

## B3 — BAJO
- `gh pr merge --merge #9`: el shell toma `#9` como comentario y mergearía el PR de la rama actual. El guard juzga el 9; hoy da DENY por «falta squash», pero con `--squash --delete-branch` se juzgaría un PR distinto del que corre. El árbol ya lo sabe (los comentarios no son Args): bastaría con tomar el id del árbol y no del texto (M4).

---

## Lo que está bien (verificado)
- El freno de push se retiró limpio: push explícito, pelón, `--force` a develop/main, `checkout develop && git merge` local → silencio. La batería diaria completa pasa.
- El árbol cierra lo que la regex no veía: `</dev/null gh pr merge`, `"gh" pr merge`, `gh "pr" "merge"`, `bash -c/-lc`, `eval`, `bash <<<`, `bash -s <<EOF`, una función que mergea, `$(gh pr merge …)`, `xargs gh pr merge` → todos gatean.
- Menciones que antes frenaban ahora pasan: heredocs a escritores o a `git commit`, `printf … >>`, `python3 - <<PY` cuyo texto cita el merge, `grep -c 'gh pr merge'`.
- El gate de merge sigue intacto: squash obligatorio a develop, borrar la rama salvo la mini (y prohibido borrar la mini), grant por repo, piso de main, juez con veto de cita.
- Sin jq, todo merge de MR → DENY y ningún push se frena. Con PATH mínimo de launchd y gh vía `ACG_EXTRA_BIN`, el merge personal pasa.
- El aviso nunca bloqueó en ninguna corrida.

## Veredicto
No converge. Los frenos en falso bajaron mucho: la batería diaria pasa completa y del corpus solo quedan L268 y L284. Pero hay evasiones del merge a main de una sola línea:
- el pre-filtro de texto (`g""h`, `g\h`);
- ejecutable en mayúsculas, opaco o tras `exec`/`watch`/`xargs -I`/`source`;
- un parseo fallido de shfmt que cae a regex en silencio;
- el merge por la API;
- la resolución del repo por un `-C`, `--work-tree`, `(cd)` o `GH_REPO` de otro comando.

La mayoría se cierra con la misma idea: lo que el árbol no puede afirmar (ejecutable opaco o desconocido, parseo fallido, una ruta de API `/merge`), mandarlo al juez con destino desconocido en vez de dejarlo pasar.
