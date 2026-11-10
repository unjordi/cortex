# Inventario de capacidades de git antes de borrar la maquinaria

Fecha: 2026-11-09 · Refs fuente: `origin/develop` 69da5136 y `3b00b32b` (rama `feat/shfmt-tokenizer`).
Propósito: conservar las firmas y capacidades de lo que se elimina (decisión en `.claude/feedbackUsuarios/2026-11-09-revision-git-sin-biblioteca.md`) para no perder ninguna al reescribir.
Se leyeron 126 funciones con nombre distinto (más la lógica inline de `merge-develop-guard.sh`, `proteger-arbol.sh`, `barrer-ramas.sh`, `limpiar-impl-*.sh` y `cerrar-slice.sh`, que no son funciones), repartidas en 58 capacidades.

Convenciones: `AH` = `brain/hooks/analizar-comando-git.sh`; `MDG` = `merge-develop-guard.sh`; `RZ` = `ramas-zombie.sh`; `JC` = `juez-comun.sh`; `PA` = `proteger-arbol.sh`; `BR` = `barrer-ramas.sh`; `LI-R/W/X` = `limpiar-impl-ramas/worktrees/residuo.sh`; `CS` = `cerrar-slice.sh`. «(solo en la rama)» = existe en `3b00b32b` y no en 69da5136; «(solo en develop)» = al revés. Firmas en bash: `$1…` posicionales, «→ stdout», «rc» = código de salida. `cmd` es siempre el texto crudo del comando; `pcwd` el `cwd` del payload del hook.

---

## 1. Leer el comando

### 1.1 Aplanar el texto ejecutable
- **Capacidad:** devolver el texto del comando con heredocs descartados (salvo los que alimentan un intérprete: bash/sh/python/perl/ruby/pwsh) y con `eval "…"` / `bash -c "…"` desenvueltos para que lo de adentro se analice como comando.
- **Firma:** `segmentos_ejecutables(cmd) → stdout texto`; rc 0.
- **Implementaciones:** `AH acg_segmentos_ejecutables` (idéntica en develop y rama).
- **Quién la usa:** `acg_despoja_comillas`, `acg_comillas_a_marca`, `acg_push_toca_base`, `PA` (nombres de ramas a borrar).
- **Sin reimplementar:** `shfmt --to-json` ya resuelve heredocs, `-c` y `eval` como nodos del árbol (campos `reparse` del extractor de la rama).

### 1.2 Quitar o marcar comillas
- **Capacidad:** versión del comando sin el contenido entrecomillado (para que un `--squash` o un `git push` dentro de un mensaje no cuente), o con cada cadena reemplazada por `_Q_`.
- **Firma:** `despoja_comillas(cmd) → stdout`; `comillas_a_marca(cmd) → stdout` (rc 0).
- **Implementaciones:** `AH acg_despoja_comillas`; `AH acg_comillas_a_marca`; `PA` repite el sed `s/'[^']*'//g; s/"[^"]*"//g` como fallback propio si la lib no carga.
- **Quién la usa:** `MDG` (flags de squash/delete, tool gh/glab), `PA`, `entorno-maquina-guard`, `no-bypass-deploy`, `acg_es_merge_mr_regex`, `acg_invoca_cerrar_slice`, `acg_push_toca_base`.
- **Sin reimplementar:** el árbol de shfmt distingue palabra literal de cadena (`SglQuoted`/`DblQuoted`); no hay que quitar comillas.

### 1.3 Partir en subcomandos
- **Capacidad:** un subcomando por línea, partiendo por `; & | \n` fuera de comillas.
- **Firma:** `partir_subcomandos(texto) → stdout una línea por subcomando`.
- **Implementaciones:** `AH acg_partir_subcomandos`.
- **Quién la usa:** `acg_es_merge_mr(_regex)`, `acg_invoca_cerrar_slice`, `acg_mrid_regex`, `acg_push_toca_base`.
- **Sin reimplementar:** cada `CallExpr` del árbol de shfmt es un subcomando.

### 1.4 Lista de comandos desde el árbol (extractor)
- **Capacidad:** de un comando (también código embebido: heredoc→intérprete, `eval`, `-c`, process substitution, hasta profundidad 4) sacar el arreglo de comandos con `exe` (basename sin `.exe`), `args`, `opq` (palabra con `$VAR/$()` por palabra), `eff` (índice del ejecutable real tras pelar `env sudo doas exec watch nohup time nice command builtin stdbuf ionice setsid caffeinate arch timeout chrt xargs` y `VAR=val`), `assigns`, `hdocs`, `reparse`.
- **Firma:** `ast_disponible() → rc 0 si hay shfmt y jq y ACG_AST_OFF≠1`; `ast_json(cmd, depth=0) → stdout JSON array`, rc 1 si no hay árbol o shfmt no parseó (el llamador degrada).
- **Implementaciones:** `AH acg_ast_disponible`, `acg_ast_json`, `ACG_AST_REDUCE_JQ` (solo en la rama).
- **Quién la usa:** `acg_clasifica_merge`, `acg_mrid`, `acg_push_clasifica`, `MDG`.
- **Sin reimplementar:** es el helper mínimo que la decisión deja (`shfmt --to-json | jq`); todo lo demás de esta sección lo reemplaza.

### 1.5 Normalizar el prefijo `git -c/-C …`
- **Capacidad:** colapsar `git -c k=v -C dir --git-dir … <sub>` a `git <sub>` para que `git` y su subcomando queden adyacentes; tolera `git.exe`.
- **Firma:** `normaliza_git_prefijo(cmd) → stdout`.
- **Implementaciones:** `AH acg_normaliza_git_prefijo`.
- **Quién la usa:** `acg_push_toca_base`, `PA`, `entorno-maquina-guard`.
- **Sin reimplementar:** `eff` + el primer arg no-flag del árbol (subcomando) con la lista de flags que consumen valor (`-C -c --git-dir --work-tree --namespace --exec-path --super-prefix`).

### 1.6 Quitar `--repo/-R <valor>` del texto
- **Capacidad:** eliminar el flag de repo para que su valor (p. ej. `…-develop`) no se confunda con una rama.
- **Firma:** `sin_flag_repo(texto) → stdout`.
- **Implementaciones:** `AH acg_sin_flag_repo`.
- **Quién la usa:** `acg_push_toca_base`, `acg_es_merge_mr(_regex)`, `acg_merge_menciona_base`, `MDG _es_release_explicito`.
- **Sin reimplementar:** los args del árbol ya separan flag y valor.

### 1.7 ¿Es `git commit`?
- **Capacidad:** detectar un `git commit` por regex.
- **Firma:** `es_commit(cmd) → rc 0 si lo es`.
- **Implementaciones:** `AH acg_es_commit`.
- **Quién la usa:** `entorno-maquina-guard`.
- **Sin reimplementar:** `exe=="git"` y primer no-flag `== commit`.

### 1.8 ¿Invoca `cerrar-slice.sh --id`?
- **Capacidad:** reconocer la invocación real de `cerrar-slice.sh` con `--id` (ignora `echo/printf`, `--help/-h/--dry-run/-n`).
- **Firma:** `invoca_cerrar_slice(cmd) → rc 0 si sí`.
- **Implementaciones:** `AH acg_invoca_cerrar_slice`.
- **Quién la usa:** `MDG` (trata el merge como destino develop sin exigir flags, porque el script los garantiza).
- **Sin reimplementar:** `exe`/`args[0]` del árbol termina en `cerrar-slice.sh` y trae `--id`.

### 1.9 ¿El comando es un merge de MR/PR? (clasificación)
- **Capacidad:** decidir si hay un merge de forja: `gh pr merge`, `glab mr merge|accept`, `gh|glab api …/merge`, `curl` a la API; separa CIERTO / INCIERTO (opaco, API, no parseable) / NO; ignora `echo/printf`, `--help/-h/--dry-run`.
- **Firma:** `clasifica_merge(cmd) → stdout CERTAIN|UNCERTAIN|NO`; `es_merge_mr(cmd) → rc 0 si ≠NO`.
- **Implementaciones:** `AH acg_clasifica_merge` + `ACG_CLASIFICA_MERGE_JQ` (rama; árbol con degradación a regex); `AH acg_es_merge_mr` (develop: regex por subcomando; en la rama pasa a envolver `clasifica_merge`); `AH acg_es_merge_mr_regex` (solo en la rama, el regex viejo como respaldo sin shfmt); `ACG_ES_MERGE_MR_JQ` (rama, filtro para `acg_mrid`).
- **Quién la usa:** `MDG` (entrada), `BR` (dispara barrido), `install-brain.sh`.
- **Sin reimplementar:** `exe` + `args[eff+1..2]` en el árbol; opaco → juez con destino desconocido.

### 1.10 Merge que nombra la base en el propio comando
- **Capacidad:** frenar `gh pr merge … --base main`, `glab mr merge … --target-branch develop` (flags `--base --target --target-branch -B` con `main|master|develop`).
- **Firma:** `merge_menciona_base(cmd) → rc 0 si nombra la base`.
- **Implementaciones:** `AH acg_merge_menciona_base` (solo en develop).
- **Quién la usa:** `MDG` (freno determinista y rama sin-jq).
- **Sin reimplementar:** el destino real lo da la forja (`target_branch`, ver 3.1); el flag del texto no es un hecho.

### 1.11 Alcance del comando que contiene el merge
- **Capacidad:** de una línea compuesta (`cd X && A; gh pr merge 5`) recortar solo el comando de merge y el `cd/pushd` previo que lo gobierna (mismo subshell), más `GH_REPO=` del merge y qué herramienta es (gh/glab), para no tomar el `-C`/`--repo` de otro comando.
- **Firma:** `merge_scope(cmd) → 4 líneas: cd_slice+merge_slice \n GH_REPO \n tool`; `merge_dir_repo(cmd, pcwd) → 3 líneas: dir \n repo \n tool`; `byteslice(str, ini, fin) → stdout`.
- **Implementaciones:** `AH acg_merge_scope`, `ACG_MERGE_SCOPE_JQ`, `acg__byteslice`, `acg_merge_dir_repo` (solo en la rama).
- **Quién la usa:** `acg__destino_de_mr_full`, `acg_origen_de_mr`, `acg_lista_prs_abiertos`, `MDG`.
- **Sin reimplementar:** los offsets de los nodos `CallExpr`/`Subshell` del árbol; con el helper genérico basta `dir` efectivo y `env` por comando.

### 1.12 Id del MR/PR
- **Capacidad:** el número del MR del comando: el único posicional numérico tras `mr merge|accept` / `pr merge`, saltando los valores de `-t --subject -b --body -F --body-file -m --message --squash-message --sha -R --repo --author-email --match-head-commit`; si hay 0 o ≥2 candidatos, vacío.
- **Firma:** `mrid(cmd) → stdout id | vacío`; `mrid_regex(cmd)`; `mrid_de_tokens(tokens_por_línea)`.
- **Implementaciones:** `AH acg_mrid` (develop: regex; rama: árbol con respaldo regex), `acg_mrid_regex`, `acg__mrid_de_tokens` (rama).
- **Quién la usa:** `acg__destino_de_mr_full`, `acg_origen_de_mr`, `MDG` (id actual, léxico por MR).
- **Sin reimplementar:** posicionales del árbol; si hay ambigüedad, `gh pr view` sin id usa la rama actual.

### 1.13 Flags del merge y herramienta
- **Capacidad:** (a) `--squash` obligatorio a develop (`--squash`, `--squash=true|1|yes|on`, `-s`); (b) borrar la rama de origen (`--delete-branch|-d` en gh, `--remove-source-branch|-d` en glab) salvo que el origen sea mini/integración; (c) saber si es gh o glab; (d) sugerir el comando correcto de rehacer.
- **Firma:** inline en `MDG`: `SQUASH_RE`, `_flag_del`; `_tool_es_gh() → rc 0 si gh`; `_rehaz_sugerido() → stdout comando sugerido`.
- **Implementaciones:** `MDG SQUASH_RE`, `_tool_es_gh`, `_rehaz_sugerido`; en develop `_tool_es_gh` es un grep sobre el texto sin comillas en vez del árbol.
- **Quién la usa:** `MDG` (freno y recordatorio del squash-message).
- **Sin reimplementar:** los flags salen de los args del comando del árbol (`--squash`, `--delete-branch`).

### 1.14 ¿El comando es un `git push` a la base? (clasificación de push)
- **Capacidad:** saber si un push apunta a `develop|main|master`: refspec explícito (`dst`, `src:dst`, `+`, `refs/heads/`), comodines (`refs/heads/*`, `+*:`), `--all`/`--mirror`, push configurado por `-c remote.X.push|push.default|alias.`, `xargs git push`, destino opaco (`$VAR`), y el push pelado (sin refspec) mirando la rama actual o la que fija un `checkout/switch` previo del mismo comando (`-b/-B/-c` nueva; posicional si existe local o remota; `checkout -` irresoluble; `--` o ≥2 posicionales = restore, no switch).
- **Firma:** `es_push(cmd) → rc 0` · `push_destino_base(cmd) → rc 0` · `push_destino_opaco(cmd) → rc 0` · `push_sin_refspec(cmd) → rc 0` · `checkout_rama(seg) → stdout "NUEVA r"|"POSIC r"|"IRRES r"|vacío` · `rama_remota_existe(dir, nombre) → rc 0` · `push_toca_base(cmd, pcwd) → rc 0 si toca la base` · rama: `push_clasifica(cmd) → stdout BASE:<rama>|PELON|SILENCIO`.
- **Implementaciones:** `AH acg_es_push` (develop, tokenizador propio con lista de consumidores de datos `echo grep cat awk sed…`), `acg_push_destino_base`, `acg_push_destino_opaco`, `acg_push_sin_refspec`, `acg_checkout_rama`, `acg__rama_remota_existe`, `acg_push_toca_base` (todos solo en develop); `acg_push_clasifica` + `ACG_PUSH_CLASIFICA_JQ` (solo en la rama, sobre el árbol: salta `-C -c --git-dir…`, ignora `-o/--push-option`).
- **Quién la usa:** `MDG` (en develop: freno al push directo; en la rama: solo el aviso de 3.7), rama sin-jq.
- **Sin reimplementar:** push directo a la base lo impide el servidor (rama protegida); queda el aviso si no está protegida (3.7). Si se quiere afirmar el destino de un pelado: `git -C <dir> rev-parse --abbrev-ref HEAD` y `git config push.default`.

---

## 2. Repo y directorio objetivo

### 2.1 Directorio donde corre el comando
- **Capacidad:** el directorio efectivo: `-C <dir>` > `--work-tree` > `--git-dir`/`GIT_DIR` (quitando `/.git`) > `cd|pushd <dir>` previo > `cwd` del payload > `CLAUDE_PROJECT_DIR`; expande `~` y `$HOME`; `$VAR`/backtick = irresoluble (cae al siguiente nivel).
- **Firma:** `target_dir(cmd, pcwd) → stdout ruta`; `expande_home(ruta) → stdout`; `dir_opaco(cmd) → rc 0 si hay cd/pushd a $VAR/backtick`.
- **Implementaciones:** `AH acg_target_dir`, `acg_expande_home`, `acg_dir_opaco`. En la rama `MDG` lo aplica sobre el comando recortado de 1.11.
- **Quién la usa:** `MDG`, `BR`, `PA`, `entorno-maquina-guard`, y todas las consultas a la forja.
- **Sin reimplementar:** el helper entrega `dir` efectivo por comando (cd previo, `-C`).

### 2.2 `--repo/-R` explícito
- **Capacidad:** el slug literal de `--repo|-R` (con comillas o `=`), `OPACO` si trae `$`/backtick, vacío si no hay.
- **Firma:** `repo_explicito(cmd_crudo) → stdout slug|OPACO|vacío`; `repo_opaco(cmd) → rc 0 si OPACO`.
- **Implementaciones:** `AH acg_repo_explicito`, `acg_repo_opaco`.
- **Quién la usa:** `MDG`, `BR`, `acg_target_remote`, `acg__destino_de_mr_full`.
- **Sin reimplementar:** args del árbol (`--repo` y su valor, `opq` marca lo opaco).

### 2.3 Slug `org/repo` del repo afectado
- **Capacidad:** slug del remoto `origin` de un directorio, o el `--repo` explícito (que gana); `GH_REPO` del merge en la rama.
- **Firma:** `target_remote(cmd, pcwd) → stdout slug|vacío`; `slug_de_dir(dir) → stdout slug|vacío` (quita `git@host:`, `ssh://host/`, `https://host/`, `.git`).
- **Implementaciones:** `AH acg_target_remote`, `acg_slug_de_dir`; repetido inline en `MDG` (2 seds `s#^(git@[^:]+:|https?://[^/]+/)##`), en `RZ _bz_cargar_prcache/_bz_cargar_stcache` (sed de `proj` y de `host`), y en `CS _forge_por_origin`/`_gitleaks_gate`.
- **Quién la usa:** `MDG`, `acg_clon_local_de_slug`, `acg_aviso_push_base`, `RZ`, `CS`.
- **Sin reimplementar:** `gh repo view --json nameWithOwner` / `glab repo view` en el dir, o `git remote get-url origin`.

### 2.4 Clon local de un slug
- **Capacidad:** ubicar el toplevel de un clon cuyo `origin` es ese slug: el repo del dir pista, o sus hermanos en el directorio padre del clon principal (resuelve worktrees por `--git-common-dir`).
- **Firma:** `clon_local_de_slug(slug, dir_pista=.) → stdout toplevel`; rc 1 si no hay.
- **Implementaciones:** `AH acg_clon_local_de_slug`.
- **Quién la usa:** `MDG` (raíz del grant y de la marca), `BR` (dónde barrer), `CS` (`--repo` y `--abrir`).
- **Sin reimplementar:** no hay equivalente; con `--repo` explícito `gh`/`glab` no necesitan clon. Sin claro si hace falta tras el rediseño.

### 2.5 Rama actual de un directorio
- **Capacidad:** nombre de la rama de HEAD en un dir.
- **Firma:** `rama_actual(dir=$CLAUDE_PROJECT_DIR) → stdout rama`.
- **Implementaciones:** `AH acg_rama_actual`; inline `git symbolic-ref --short -q HEAD` en `RZ bz_resolver_base/bz_aviso_base`, `PA`, `LI-R`.
- **Quién la usa:** `acg_push_toca_base`, `acg_aviso_push_base`, `PA`, `RZ`, `CS` (fallback de rama).
- **Sin reimplementar:** `git -C <dir> rev-parse --abbrev-ref HEAD`.

### 2.6 Forja de un repo (GitHub o GitLab)
- **Capacidad:** decidir gh o glab por el host del remoto (`github.com|*.github.com` → gh; `*gitlab*` → glab; otro → desconocido).
- **Firma:** `forja_de_dir(dir) → stdout github|gitlab|vacío`; `forge_por_origin() → stdout gh|glab|vacío`.
- **Implementaciones:** `AH acg_forja_de_dir` (rama); `CS _forge_por_origin`; `RZ _bz_cargar_prcache`/`_bz_cargar_stcache` (case sobre `host`, con host desconocido = prueba ambos).
- **Quién la usa:** `acg_aviso_push_base`, `CS`, `RZ`.
- **Sin reimplementar:** `gh`/`glab` ya detectan el remoto; solo el helper necesita saber cuál invocar (host del remoto).

### 2.7 Repo personal o coordinado
- **Capacidad:** repo COORDINADO si `<raíz>/.claude/repo-compartido` existe (gatea el merge a develop); PERSONAL si es un repo git válido sin marca (develop sin fricción); INCIERTO (gatea) si `--repo` es otro repo literal o hay `--repo $VAR` / `cd $X`. La raíz del grant solo vale si `TARGET_ROOT` es el repo del merge.
- **Firma:** inline en `MDG` (variables `_es_personal`, `_grant_root_ok`, `TARGET_ROOT`).
- **Implementaciones:** `MDG` (bloque inline, idéntico en develop y rama salvo el comando recortado).
- **Quién la usa:** `MDG`.
- **Sin reimplementar:** archivo marca versionado (ya es dato, no heurística).

### 2.8 ¿Rama de integración personal?
- **Capacidad:** reconocer mini-develop/integración por convención: `Develop[A-Z]*`, `integracion/*`, `epic/*`.
- **Firma:** `es_rama_integracion(nombre) → rc 0 si lo es`.
- **Implementaciones:** `AH acg_es_rama_integracion`; la misma convención se repite en `RZ bz_protegida` (`develop main Develop* keep/* epic/* epic-* integracion/* integracion-*`) y en `RZ bz_resolver_base` (`Develop?*`).
- **Quién la usa:** `MDG` (no exigir borrar el origen, prohibirlo).
- **Sin reimplementar:** no hay; es convención del equipo. Una sola lista de patrones.

---

## 3. Estado de MR/PR y ramas en la forja

### 3.1 Rama destino (target) de un MR
- **Capacidad:** destino real del MR con el motivo cuando no se conoce (`SIN-CLI`, `DIR-IRRESOLUBLE`, `SIN-MRID`, `REPO-VARIABLE`, `SIN-RED`, `TIMEOUT`, `MERGE-INCIERTO`).
- **Firma:** `destino_de_mr_full(cmd, pcwd) → 2 líneas: destino \n API|DESCONOCIDO:<motivo>`; `destino_de_mr(cmd, pcwd) → destino`; `destino_conf(cmd, pcwd) → confianza`; `_pr_base_branch() → destino` (CS, con `$ID/$REPO/$FORGE` globales).
- **Implementaciones:** `AH acg__destino_de_mr_full`, `acg_destino_de_mr`, `acg_destino_conf`; `CS _pr_base_branch`.
- **Quién la usa:** `MDG`, `CS` (solo integra a develop; main = release).
- **Sin reimplementar:** `gh pr view <id> -R <repo> --json baseRefName -q .baseRefName` / `glab mr view <id> -F json | jq .target_branch`, ejecutado en el dir del comando.

### 3.2 Rama origen (source) de un MR
- **Capacidad:** rama de origen del MR (con caché por repo|herramienta|id, 600, TTL 7 días) para no pedir borrar la rama de una mini.
- **Firma:** `origen_de_mr(cmd, pcwd) → stdout rama|vacío`.
- **Implementaciones:** `AH acg_origen_de_mr`; `CS` repite la consulta inline dos veces (`_rama` y dentro de `_gitleaks_gate` para `head`): `gh pr view --json headRefName` / `glab mr view -F json | jq .source_branch`.
- **Quién la usa:** `MDG`, `CS`.
- **Sin reimplementar:** `gh pr view --json headRefName` / `glab mr view -F json`.

### 3.3 MRs/PRs abiertos
- **Capacidad:** lista de abiertos `{number,title,baseRefName,headRefName,isDraft}` (límite 50, caché por repo|herramienta).
- **Firma:** `lista_prs_abiertos(cmd, pcwd) → stdout JSON array|vacío`.
- **Implementaciones:** `AH acg_lista_prs_abiertos`.
- **Quién la usa:** `MDG` (destino de respaldo y contexto del juez).
- **Sin reimplementar:** `gh pr list --state open --json …` / `glab mr list --output json`.

### 3.4 ¿La rama tuvo un MR mergeado? (por rama y sha)
- **Capacidad:** de la forja, líneas `rama<TAB>sha` de los MRs mergeados (hasta `CLAUDE_BZ_PR_LIMIT`=1000, glab paginado de 100 con tope), una carga por repo; una rama cuenta si su tip es ancestro del head mergeado.
- **Firma:** `pr_mergeado(root, rama, ref=rama) → rc 0 si integrada por MR`; internas `_bz_cargar_prcache(root)`, `_bz_intentar_gh(root, proj)`, `_bz_intentar_glab(root, proj)`, `_bz_glab_paginar(proj, filtro, destino, jq) → rc 0 si la 1ª consulta tuvo éxito`, `_bz_limite() → stdout N`. Banderas globales `_BZ_D_INTENTADO`, `_BZ_D_APLICABLE`, `CLAUDE_BZ_PRCACHE`.
- **Implementaciones:** `RZ bz_pr_mergeado`, `_bz_cargar_prcache`, `_bz_intentar_gh`, `_bz_intentar_glab`, `_bz_glab_paginar`, `_bz_limite`.
- **Quién la usa:** `RZ` (zombie), `BR`/`LI-R`/`LI-W`/`PA` por transitividad.
- **Sin reimplementar:** `gh pr list --state merged --json headRefName,headRefOid` / `glab mr list -M`, o `gh pr view <rama> --json state,mergedAt` por rama.

### 3.5 Estado del PR de una rama (abierto / cerrado / mergeado / sin PR)
- **Capacidad:** texto «PR #N ABIERTO | CERRADO sin merge | MERGEADO | SIN PR | desconocido» por rama (todos los estados, caché por repo).
- **Firma:** `pr_estado(root, rama) → stdout texto`; interna `_bz_cargar_stcache(root)`.
- **Implementaciones:** `RZ bz_pr_estado`, `_bz_cargar_stcache` (duplica la consulta de 3.4 con `--state all`/`-A`).
- **Quién la usa:** `LI-R reportar_represada_si_aplica`.
- **Sin reimplementar:** `gh pr view <rama> --json state,number` / `glab mr list --source-branch <rama> -A`.

### 3.6 Veredicto de CI de un MR
- **Capacidad:** `VERDE|ROJO|PENDIENTE|SINCI|INDET` de los checks/pipeline del MR; con `--wait-ci` sondea hasta `CERRAR_SLICE_CI_TIMEOUT` (600 s) cada `CERRAR_SLICE_CI_POLL` (15 s).
- **Firma:** `_ci_veredicto() → stdout veredicto` (usa `$ID $REPO $FORGE`).
- **Implementaciones:** `CS _ci_veredicto`.
- **Quién la usa:** `CS`.
- **Sin reimplementar:** `gh pr checks <id> --watch --fail-fast` (o `--json bucket`) / `glab ci status` / `glab mr view -F json | jq .pipeline.status`.

### 3.7 ¿La rama está protegida en el servidor?
- **Capacidad:** `PROTEGIDA | NO-PROTEGIDA | NO-PROTEGIBLE (GitHub 403 «Upgrade to GitHub Pro») | DESCONOCIDO` de una rama (GitLab: `protected_branches`; GitHub: `branches/<rama>/protection`, 200/404/403) y el aviso de push a base no protegida, con caché por sesión+repo+rama y un solo aviso 403 por sesión y repo.
- **Firma:** `proteccion_rama(dir, forja, slug, rama) → stdout estado`; `aviso_push_base(cmd, pcwd, sid) → stdout texto del aviso|vacío`.
- **Implementaciones:** `AH acg_proteccion_rama`, `acg_aviso_push_base` (solo en la rama).
- **Quién la usa:** `MDG` (en la rama, para el `additionalContext` cuando no es merge).
- **Sin reimplementar:** `gh api repos/<slug>/branches/<rama> --jq .protected` / `glab api projects/:id/protected_branches` (con comodines).

### 3.8 Ejecutar la consulta en un dir con timeout
- **Capacidad:** correr una herramienta en un directorio con tiempo máximo (`timeout`/`gtimeout`/respaldo con kill), `ACG_MR_TIMEOUT`=6; que un host colgado no cuelgue el hook. También `git` con tope (fetch 20 s, ls-remote 12 s).
- **Firma:** `run_timeout(seg, cmd…) → rc del comando`; `run_en_dir(dir, seg, cmd…) → stdout/rc`; `_bz_run(seg, cmd…)`; `_git_acotado(seg, git-args…) → rc`.
- **Implementaciones:** `AH acg__run_timeout`, `acg__run_en_dir`; `RZ _bz_run`; `LI-R _git_acotado`; `MDG _es_sync_upstream_autorizado` llama `timeout 15/30` directo.
- **Quién la usa:** todas las consultas a forja y a remoto.
- **Sin reimplementar:** `timeout N <cmd>` (con `gtimeout` en macOS).

### 3.9 Caché confiable en /tmp
- **Capacidad:** reutilizar un archivo de caché solo si es del uid actual, permisos `*00` y menor al TTL (`ACG_CACHE_TTL_DIAS`, por defecto 7).
- **Firma:** `cache_confiable(path) → rc 0 si confiable`.
- **Implementaciones:** `AH acg__cache_confiable`.
- **Quién la usa:** `acg_origen_de_mr`, `acg_lista_prs_abiertos`, `acg_aviso_push_base`.
- **Sin reimplementar:** no hace falta si cada consulta es directa (el rediseño pide no cachear MRs).

### 3.10 PATH con gh/glab
- **Capacidad:** añadir al final del PATH `/opt/homebrew/bin /usr/local/bin ~/.linuxbrew/bin ~/.local/bin ~/bin` (y `ACG_EXTRA_BIN`) cuando el hook hereda el PATH mínimo de launchd; `ACG_PATH_AUGMENT=0` lo apaga.
- **Firma:** `acg__augmenta_path() → rc 0` (exporta PATH; se corre al `source`).
- **Implementaciones:** `AH acg__augmenta_path`.
- **Quién la usa:** `MDG` al cargar la lib.
- **Sin reimplementar:** una línea al inicio del hook.

---

## 4. Estado de ramas locales y remotas

### 4.1 Base de integración
- **Capacidad:** qué rama es la base contra la que se juzga «ya entró»: `CLAUDE_INTEGRACION_BASE` > HEAD si es `Develop?*` > la única `Develop*` local > `develop` > rama por defecto de `origin` > `main`; validar que exista; avisar si hay varias minis y HEAD en ninguna.
- **Firma:** `resolver_base(root) → stdout rama`; `base_valida(root, base) → rc 0`; `aviso_base(root) → stdout texto|vacío`.
- **Implementaciones:** `RZ bz_resolver_base`, `bz_base_valida`, `bz_aviso_base`.
- **Quién la usa:** `LI-R`, `LI-W`, `PA` (borrado de rama).
- **Sin reimplementar:** `git symbolic-ref refs/remotes/origin/HEAD`; la elección mini-vs-develop es política (sin equivalente).

### 4.2 ¿La rama ya entró a la base? (zombie)
- **Capacidad:** una rama local o remota está integrada si: (a) su tip es ancestro de la base; (e) la forja o el log tiene un squash con `Rama: <rama>` en la base y el contenido está presente (`git merge-tree --write-tree` de algún commit first-parent de la base con la rama == árbol de ese commit; tope `CLAUDE_BZ_PRESENCIA_MAX`=200); (d) MR mergeado (3.4); (c) `git cherry` sin `+`; (p) presencia de contenido (solo modo barrido); (t) transitiva: una rama que la contiene está integrada; (r) integrada contra la base REMOTA (`<base>@{upstream}` u `origin/<base>`); (b) remota borrada y sin commits únicos; si no, vivo o indeterminado (forja no consultable).
- **Firma:** `es_zombie(root, rama, base, modo="") → rc 0 si integrada`, deja `BZ_RAZON` ∈ {a,e,d,c,p,t,r,b,vivo,indeterminado}; `remota_integrada(root, rama, ref, baseref) → rc 0`, deja `BZ_RRAZON`; internas `_bz_integrada`, `_bz_integrada_directa(root, rama, base, modo)`, `_bz_base_remota(root, base) → stdout`, `_bz_squash_ct(root, rama, base) → stdout epoch`, `_bz_presencia_contenido(root, rama, base) → rc`.
- **Implementaciones:** `RZ bz_es_zombie`, `bz_remota_integrada`, `_bz_integrada`, `_bz_integrada_directa`, `_bz_base_remota`, `_bz_squash_ct`, `_bz_presencia_contenido` (`bz_remota_integrada` y `_bz_integrada_directa` repiten la misma cadena a/e/d/c con distinta referencia); `LI-W es_zombie` (envoltorio con modo barrido); `CS` repite «tip contenido en la fuente y no en develop» con `merge-base --is-ancestor` para agregar trazas `Rama:` de sub-ramas.
- **Quién la usa:** `LI-R`, `LI-W`, `PA` (avisa si el borrado orfanaría trabajo).
- **Sin reimplementar:** forja primero (`gh pr view <rama> --json state,mergedAt` / `glab mr list --source-branch <rama> -M`), luego `git merge-base --is-ancestor <rama> <base>`; `git cherry` solo vale en su positivo. Equivalencia por patch o por texto: «solo si una prueba de uso real demuestra que hacen falta».

### 4.3 ¿La rama se protege del borrado?
- **Capacidad:** no borrar la base, la rama actual, `develop|main|Develop*|keep/*|epic/*|epic-*|integracion/*|integracion-*`, ni las ramas con worktree; devuelve el motivo (`base_actual|convencion|worktree`).
- **Firma:** `protegida(rama, base, actual="", wt_ramas="") → rc 0`, deja `BZ_PROT_RAZON`.
- **Implementaciones:** `RZ bz_protegida`.
- **Quién la usa:** `LI-R`, `LI-W`.
- **Sin reimplementar:** `git worktree list --porcelain` para worktrees; el resto es convención (ver 2.8).

### 4.4 Worktree recién nacido
- **Capacidad:** proteger un worktree cuya rama no tiene commits sobre la base, cuyo reflog no muestra trabajo (commit/merge/rebase/cherry-pick/pull/am/revert) y con árbol limpio (agente que acaba de arrancar).
- **Firma:** `_worktree_recien_nacido(wt, rama) → rc 0 si proteger`.
- **Implementaciones:** `LI-W _worktree_recien_nacido`.
- **Quién la usa:** `LI-W`.
- **Sin reimplementar:** `git rev-list --count base..rama`, `git reflog show`, `git status --porcelain`.

### 4.5 ¿Un comando destructivo orfanaría trabajo?
- **Capacidad:** detectar `git reset --hard|--merge|--keep`, `checkout -f|--force`, `rebase`, `branch -d|-D|--delete`; para borrado de rama, avisar si alguna rama a borrar no está integrada (4.2) salvo que el mismo comando la mergee antes; para el resto, contar commits sin pushear (`@{u}..HEAD`, o `merge-base` con `origin/develop|main`) y avisar si el árbol es el principal compartido; en worktree aislado, nota informativa salvo que el destino sea la propia rama u `origin/<rama>`/`develop|main`; exento si se resetea `develop|main` a `origin/<misma>` sin commits propios.
- **Firma:** inline en `PA` (sin funciones): stdout `additionalContext` con `AVISO`/`Nota`; rc 0 siempre (solo avisa).
- **Implementaciones:** `PA` (script completo, 195 líneas; fallback heredoc-ciego propio si `AH` no carga).
- **Quién la usa:** hook PreToolUse de Bash.
- **Sin reimplementar:** `git rev-list @{u}..HEAD`, `git branch --merged`, estado del MR/PR (4.2); el ejecutable y sus args salen del helper.

### 4.6 Reportar rama represada
- **Capacidad:** una rama sin integrar con ≥`LIMPIAR_RAMAS_DIAS_HUERFANA` (14) días de inactividad y que cumple el patrón se anota una sola vez por (rama, sha) en la bitácora con el estado de su PR, y nunca se borra.
- **Firma:** `reportar_represada_si_aplica(rama, ref=rama) → stdout línea`; `huerf_ya_reportada(rama, sha) → rc 0`.
- **Implementaciones:** `LI-R reportar_represada_si_aplica`, `huerf_ya_reportada`.
- **Quién la usa:** `LI-R`.
- **Sin reimplementar:** `git log -1 --format=%ct <ref>` y 3.5.

---

## 5. Autorización y juez

### 5.1 Conversación reciente intercalada
- **Capacidad:** del transcript (últimas 6000 líneas) extraer la conversación `USUARIO:`/`ASISTENTE:` desde 4 turnos antes del décimo mensaje de usuario más reciente; descarta meta, resúmenes de `/compact`, inyecciones de sistema, salida de comandos y mensajes de otros agentes; incluye `queued_command` humano y respuestas de preguntas (`answers/annotations`); asistente truncado a 700 caracteres.
- **Firma:** `recent_intercalado(transcript_jsonl) → stdout texto`.
- **Implementaciones:** `AH acg_recent_intercalado`; `MDG _recent_intercalado` (envoltorio).
- **Quién la usa:** `MDG` (juez, release explícito, sync de upstream).
- **Sin reimplementar:** es juicio sobre el transcript; no hay comando de git. Lo lee el juez.

### 5.2 Líneas del usuario «de hoy» (hora CDMX)
- **Capacidad:** líneas de usuario del transcript con fecha de hoy en CDMX (UTC−6) y saber si hay alguna con timestamp, para validar autorizaciones del día que quedaron fuera de la ventana.
- **Firma:** `user_lineas_hoy_cdmx(transcript) → stdout líneas`; `tiene_user_fechado(transcript) → rc 0`.
- **Implementaciones:** `AH acg_user_lineas_hoy_cdmx`, `acg_tiene_user_fechado`.
- **Quién la usa:** `MDG _juez_merge_uno` (develop).
- **Sin reimplementar:** juicio; va al juez.

### 5.3 Léxico de release / main / develop
- **Capacidad:** pruebas por palabras sobre las líneas del usuario: ¿hay lenguaje de release (`release|liber…|a main|hacia master`)? ¿aplica a este MR (número nombrado o sin número)? ¿es afirmativo (sin `no|nunca|todavía|aún|espera|sin`)? ¿hay señal amplia de main/promover en cualquier rol? ¿el usuario nombró `develop`? ¿el comando mismo ya dice `main` o `release`?
- **Firma:** `lexico_release(msgs) → rc 0`; `lexico_release_para_mr(msgs, mrid="") → rc`; `lexico_release_afirmativo_para_mr(msgs, mrid="") → rc`; `lexico_main_amplio(msgs) → rc`; `lexico_develop_explicito(msgs) → rc`; `MDG _lexico_release_en_ventana(msgs)` (envoltorio); `MDG _es_release_explicito(cmd) → rc`.
- **Implementaciones:** `AH acg_lexico_release`, `acg_lexico_release_para_mr`, `acg_lexico_release_afirmativo_para_mr`, `acg_lexico_main_amplio`, `acg_lexico_develop_explicito`; `MDG _lexico_release_en_ventana`, `_es_release_explicito`.
- **Quién la usa:** `MDG` (gate estricto de release en el veredicto, squash cuando el destino es desconocido).
- **Sin reimplementar:** juez (autorización); el destino sale de la forja (3.1).

### 5.4 Contexto factual para el juez
- **Capacidad:** bloque de texto con título, rama y base del MR, y cuántos abiertos hay hacia esa base (1 = una referencia vaga es inequívoca; ≥2 = debe nombrar cuál; 0 = no asumas; lista no disponible = resolver con la conversación).
- **Firma:** `hint_candidatos(json_abiertos, destino, mrid) → stdout bloque`.
- **Implementaciones:** `AH acg_hint_candidatos`.
- **Quién la usa:** `MDG` (parte del prompt del juez).
- **Sin reimplementar:** 3.3 más el prompt del juez.

### 5.5 Veredicto del juez de merge
- **Capacidad:** pedir a Haiku ALLOW/DENY de si el usuario autorizó ESTE merge a ese destino: gate por destino (develop = instrucción clara; main/master = lenguaje de release); exige CITA verbatim de una línea `USUARIO:` que case con la conversación (5.7); en develop revalida contra las líneas de hoy salvo que la cita nombre el id; en main/destino desconocido exige además léxico afirmativo de release anclado al MR; N votos en paralelo (`CLAUDE_MERGE_JUEZ_VOTES`, cualquier DENY = DENY); `UNAVAILABLE_NOTOKEN|EXPIRED|NET` si no hay veredicto.
- **Firma:** `_juez_merge_uno(destino, mrid, mensajes, hint, repo, transcript) → stdout ALLOW|DENY|UNAVAILABLE_*`; `_juez_merge(…mismos) → stdout`; `_juez_agrega_votos() ← stdin un voto por línea → stdout`.
- **Implementaciones:** `MDG _juez_merge_uno`, `_juez_merge`, `_juez_agrega_votos`.
- **Quién la usa:** `MDG`.
- **Sin reimplementar:** es «juez»; el prompt es el contrato.

### 5.6 Llamada al modelo (Haiku) y tokens
- **Capacidad:** una llamada a `api.anthropic.com/v1/messages` con token OAuth (llavero macOS > `.credentials.json` > `CLAUDE_CODE_OAUTH_TOKEN`; prueba cada canal y distingue sin token / expirado (401/403) / red), o a un modelo local Ollama (`CLAUDE_JUEZ_LOCAL_MODEL`, solo hosts locales salvo `…_ALLOW_REMOTE=1`); estado en la línea 1 y texto después.
- **Firma:** `_juez_llamar_api(modelo, maxtok, timeout, temp, prompt) → stdout "ESTADO\ntexto"`, rc 0 si OK; `_juez_token() → stdout`; `_juez_tokens_ordenados() → stdout uno por línea sin duplicados`; `_juez_token_de_llavero|_de_archivo|_de_env`; `_juez_dir()`; `_juez_deps_ok()`; `_juez_curl_crudo(token, body, timeout)`; `_juez_curl_local(url, body, timeout)`; `_juez_centinela(texto, regex)`; `_juez_url_host(url)`; `_juez_host_es_local(host)`.
- **Implementaciones:** `JC` (las 14 funciones `_juez_*`).
- **Quién la usa:** `MDG` (único consumidor en estos archivos; `JC` es lib compartida con otros hooks).
- **Sin reimplementar:** es la plomería del juez; `claude -p` no la reemplaza sin cambiar el contrato. `_juez_centinela` sin uso claro (no la llama nadie en los archivos leídos: `JC` línea 92).

### 5.7 Cita verbatim del juez
- **Capacidad:** verificar que la cita del juez aparece en alguna línea real del usuario: normaliza (ASCII, minúsculas, solo alfanumérico), acepta subcadena de ≥6 caracteres (`CLAUDE_JUEZ_CITA_MIN_CHARS`) o ≥85 % de tokens en citas de ≥4 palabras.
- **Firma:** `_juez_cita_norm(texto) → stdout`; `_juez_cita_casa(cita, líneas) → rc 0 si casa`.
- **Implementaciones:** `JC _juez_cita_norm`, `_juez_cita_casa`.
- **Quién la usa:** `MDG _juez_merge_uno`.
- **Sin reimplementar:** no hay; es el anti-alucinación del juez.

### 5.8 Grant vigente de merge a develop
- **Capacidad:** si `<raíz>/.claude/memory/autorizaciones-vigentes.local.md` trae una línea `scope=merge-develop` sin vencer (`vence_epoch=N` mayor que ahora; sin vencimiento = vigente; `vence:`/`vence=` no epoch = se ignora), el merge a develop pasa sin juez (solo si la raíz es el repo del merge).
- **Firma:** inline en `MDG` (awk), rc→`_salir_ok`.
- **Implementaciones:** `MDG` (bloque inline).
- **Quién la usa:** `MDG`.
- **Sin reimplementar:** archivo de datos; el rediseño lo conserva («autorización = juez + grant»).

### 5.9 Excepción: merge sin squash para sync de upstream
- **Capacidad:** permitir `gh pr merge --merge` a develop si el usuario lo pidió por nombre (`--merge|sin squash` junto al id), el `--repo` es literal, el PR apunta a develop y el PR trae un merge-commit cuyo segundo padre está adelante de develop.
- **Firma:** `_es_sync_upstream_autorizado(cmd, transcript) → rc 0 si exento`.
- **Implementaciones:** `MDG _es_sync_upstream_autorizado`.
- **Quién la usa:** `MDG`.
- **Sin reimplementar:** `gh api repos/<repo>/pulls/<id>` (`.base.ref`), `…/commits` y `compare/develop...<sha>` (`.ahead_by`); la autorización va al juez.

---

## 6. Salida del hook

### 6.1 Denegar, avisar, salir
- **Capacidad:** emitir el JSON de PreToolUse (`permissionDecision:"deny"` con razón; o `additionalContext` informativo con notas de modo degradado/merge incierto y recordatorios); nunca frenar si no hay nada que decir.
- **Firma:** `_deny_json(razón) → stdout JSON`; `_salir_ok() → stdout JSON opcional, exit 0`; `_dsj(razón) → stdout JSON y exit 0` (solo develop, rama sin-jq con JSON a mano).
- **Implementaciones:** `MDG _deny_json`, `_salir_ok`, `_dsj` (solo en develop); `PA`, `BR` y `AH acg_aviso_push_base` arman el `additionalContext` con `jq -n` inline.
- **Quién la usa:** `MDG`, `PA`, `BR`.
- **Sin reimplementar:** es el contrato de salida del hook; una función `emitir(tipo, texto)`.

### 6.2 Fail-safes de entorno
- **Capacidad:** sin `jq` — freno por texto crudo si parece merge (en develop también push directo, `acg_merge_menciona_base` y el `command` sacado con sed), salvo `CLAUDE_GIT_GUARD_SIN_JQ_PERSONAL=1`; lib que no carga o incompleta — freno si el comando menciona `merge|accept` (en develop `push` también); sin `shfmt` — modo degradado con nota; siembra de repo vacío `CLAUDE_GIT_GUARD_SEED=1` exime del freno de push (solo en develop).
- **Firma:** inline en `MDG` (prólogo).
- **Implementaciones:** `MDG` (prólogo; en develop usa `_dsj`).
- **Quién la usa:** `MDG`.
- **Sin reimplementar:** no hay; con el helper mínimo desaparecen los casos «lib rota».

---

## 7. Limpieza de ramas, worktrees y residuo

### 7.1 Disparar el barrido (hook)
- **Capacidad:** tras un merge de MR (PostToolUse/Bash) o al arrancar sesión, lanzar en segundo plano `limpiar.sh worktrees` y luego `limpiar.sh ramas` en el repo afectado, con debounce de 30 s por repo tras merge (`BARRER_RAMAS_MERGE_DEBOUNCE`) y throttle de 24 h al arrancar (`BARRER_RAMAS_HORAS`); sellos y logs por repo en `~/.claude/memory/.barrer-ramas`; sin remoto no hay nada que barrer; opaco no barre.
- **Firma:** `lanzar() → rc 0 si se lanzó` (usa `$ROOT $LIMPIAR $log $logwt`); stdout JSON `additionalContext`; `CLAUDE_SKIP_BARRER_RAMAS=1` lo apaga.
- **Implementaciones:** `BR lanzar` y el cuerpo del script.
- **Quién la usa:** hook PostToolUse/SessionStart.
- **Sin reimplementar:** `nohup limpiar.sh …`; el repo sale del helper (`dir` del merge).

### 7.2 Dispatcher de limpieza
- **Capacidad:** `limpiar.sh ramas|worktrees|residuo [flags]` reenvía a `limpiar-impl-<sub>.sh`.
- **Firma:** `limpiar.sh <sub> [flags…] → rc del subcomando`; 2 sin args; `_uso()` imprime la ayuda.
- **Implementaciones:** `limpiar.sh` (script, `_uso`).
- **Quién la usa:** `BR`, `cerrar-slice`, a mano.
- **Sin reimplementar:** no hay.

### 7.3 Barrer ramas locales integradas
- **Capacidad:** `fetch --all --prune` acotado; resolver la base (4.1); por cada rama local no protegida y zombie (modo barrido): `branch -D` y luego borrar la remota si sigue en el servidor y su tip es ancestro del tip local; conservar vivas, indeterminadas (sin foro) y reportar represadas (4.6); `--dry-run`, `--no-fetch`; resumen final; si `origin` no se pudo actualizar, no borra por esa duda.
- **Firma:** `limpiar-impl-ramas.sh [--dry-run] [--no-fetch] → stdout resumen`, rc 1 si la base es irresoluble; `rama_remoto(rama) → stdout remoto` (upstream o `origin`); `barrer_remota(rama, remoto, sha_local_tip)`; `_join(sep, acumulado, nuevo)`.
- **Implementaciones:** `LI-R` (script + `rama_remoto`, `barrer_remota`, `_join`, `_git_acotado`).
- **Quién la usa:** `BR`, `cerrar-slice` (aviso), a mano.
- **Sin reimplementar:** `git fetch --prune`, `gh pr view`/`glab mr view` + `git merge-base --is-ancestor`, `git push <remoto> --delete`.

### 7.4 Barrer remotas sin local
- **Capacidad:** para cada remoto, ramas remotas sin rama local (no protegidas): si están integradas (`bz_remota_integrada`) y el `ls-remote` en vivo sigue en el mismo sha evaluado, `push --delete`; si avanzó o no se pudo consultar, no se toca; las no integradas se cuentan y se reportan si llevan días.
- **Firma:** bloque dentro de `LI-R` (`LIMPIAR_RAMAS_SIN_REMOTAS=1` lo apaga).
- **Implementaciones:** `LI-R` (inline).
- **Quién la usa:** `LI-R`.
- **Sin reimplementar:** `git for-each-ref refs/remotes/<remoto>`, `git ls-remote --heads`, 4.2.

### 7.5 Barrer worktrees de ramas integradas
- **Capacidad:** `worktree prune`; por cada worktree no principal: protegida / recién nacida (4.4) / zombie (4.2) / vivo / detached / indeterminado; borra zombies con `git worktree remove`, y si está sucio no lo toca (o `--force` con `--purgar-sucios`), anotando en la bitácora los pendientes sin repetir; `--dry-run`.
- **Firma:** `limpiar-impl-worktrees.sh [--dry-run] [--purgar-sucios] → stdout resumen`; `_intentar_borrar(wt) → rc 0 si borró` (deja `SUCIO_N`); `es_zombie(rama) → rc`.
- **Implementaciones:** `LI-W` (script + `es_zombie`, `_worktree_recien_nacido`, `_intentar_borrar`).
- **Quién la usa:** `BR`, a mano.
- **Sin reimplementar:** `git worktree list --porcelain`, `git worktree remove`, `git status --porcelain`.

### 7.6 Barrer residuo por edad
- **Capacidad:** borrar por antigüedad: backups de reubicar (90 d), logs y sellos de barrer-ramas (60 d), cachés `acg-mrdest-*` en tmp (7 d); `--dry-run`, `--quiet`, `--dias-*=N`; reporta KB.
- **Firma:** `limpiar-impl-residuo.sh [--dry-run] [--quiet] [--dias-backups=N] [--dias-logs=N] [--dias-tmp=N]`; `barrer_patron(dir, patrón, días, tipo f|d, etiqueta)`; `kb_de(ruta) → stdout KB`; `say(texto)`.
- **Implementaciones:** `LI-X` (script + `barrer_patron`, `kb_de`, `say`; el patrón `acg-mrdest-*` ya no coincide con las cachés reales `acg-mrorigen-*`/`acg-prlist-*`/`acg-protcache-*`).
- **Quién la usa:** `limpiar.sh residuo`, a mano.
- **Sin reimplementar:** `find -mtime`; desaparece con la caché de MRs (3.9).

---

## 8. Cerrar slice

### 8.1 Armar y ejecutar el merge de un slice
- **Capacidad:** `cerrar-slice.sh --id N (--message-file f | --message t) [--forge glab|gh] [--repo slug] [--branch r] [--wait-ci] [--dry-run]`: valida `--id` entero y `--repo` literal; ubica el clon del `--repo`; resuelve forja (3.2/2.6) y verifica que la base del MR sea `develop` (main = release, otro = error, no legible = error); agrega al mensaje las trazas `Rama: <rama>` (y sub-ramas contenidas aún no en develop) y `MR: !N`/`PR: #N` si faltan; avisa si el resumen tiene <12 palabras; corre el gate de secretos (8.2) y el de CI (3.6); ejecuta `glab mr merge N --squash --squash-message "<msg>" --remove-source-branch --yes [-R repo]` o `gh pr merge N --squash --delete-branch --subject <1ª línea> --body <resto> [-R repo]`; rechaza `--auto/--auto-merge`.
- **Firma:** `cerrar-slice.sh [opciones] → rc del merge`; `_uso()`, `_err(msg) → stderr y exit 1`, `_warn(msg) → stderr`.
- **Implementaciones:** `CS` (script, 367 líneas).
- **Quién la usa:** `MDG` (lo reconoce por 1.8), usuario/Claude.
- **Sin reimplementar:** `gh pr merge --squash --delete-branch --subject … --body …` / `glab mr merge --squash --squash-message … --remove-source-branch --yes`; las trazas son texto del mensaje.

### 8.2 Gate local de secretos
- **Capacidad:** `gitleaks git . --log-opts=<base>..<rama del MR> --redact`; la rama sale de `--branch`, de la forja o de HEAD (si está en `develop|main|HEAD` sin saberla, aborta); si `--repo` no es el repo del dir, o no hay gitleaks, omite con aviso.
- **Firma:** `_gitleaks_gate() → rc 0 limpio/omitido; _err si detecta`.
- **Implementaciones:** `CS _gitleaks_gate`.
- **Quién la usa:** `CS`.
- **Sin reimplementar:** `gitleaks git --log-opts="origin/develop..origin/<rama>"`.

### 8.3 Abrir el MR/PR de una ramita a develop
- **Capacidad:** `cerrar-slice.sh --abrir --branch r [--repo slug] [--forge …]`: `gh pr create --base develop --head r --fill` o `glab mr create --source-branch r --target-branch develop --title <último commit> --description <cuerpo> --squash-before-merge --remove-source-branch --yes` (sin `--fill`, que empujaría el HEAD del cwd), desde el clon del repo.
- **Firma:** inline en `CS`.
- **Implementaciones:** `CS` (bloque `--abrir`).
- **Quién la usa:** `CS`.
- **Sin reimplementar:** `gh pr create --base develop --head r --fill` / `glab mr create --target-branch develop --source-branch r …`.

---

## 9. Utilidades de apoyo (sin capacidad propia de git)
- `_uso()` (ayuda): `limpiar.sh`, `cerrar-slice.sh`. `_err`/`_warn`: `cerrar-slice.sh`. `_join(sep, acc, nuevo)`: `LI-R`. `say`, `kb_de`: `LI-X`. `lanzar`: `BR` (7.1). `es_zombie` en `LI-W` y `LI-R` (envoltorios de 4.2). `MDG _recent_intercalado`/`_lexico_release_en_ventana`: envoltorios de `AH` que existen solo para los tests (`_CMD_JUEZ_SOURCE_ONLY=1`).

---

## Duplicados encontrados

Capacidades implementadas más de una vez (ordenadas por cuántas copias vivas hay):

1. **¿Esta rama/MR ya entró a la base?** — 6 copias: `bz_es_zombie`, `bz_remota_integrada` y `_bz_integrada_directa` (misma cadena a/e/d/c con otra referencia), `LI-W es_zombie` (envoltorio), `CS` («sub-ramas contenidas, no en develop» por `merge-base --is-ancestor`), `PA` (vuelve a llamar a `bz_es_zombie`).
2. **Rama de un MR por consulta a la forja (origen/destino/estado/lista/mergeados)** — 5 consultas sobre el mismo MR con caché distinta cada una: `acg__destino_de_mr_full`, `acg_origen_de_mr`, `acg_lista_prs_abiertos`, `bz_pr_mergeado`/`_bz_cargar_prcache`, `bz_pr_estado`/`_bz_cargar_stcache`, más `CS _pr_base_branch` y las 2 consultas inline de rama en `CS`; todas son `gh pr view|list` / `glab mr view|list` con campo distinto.
3. **Slug y host del remoto `origin`** — 6 copias del mismo sed (`acg_slug_de_dir`, `acg_target_remote`, 2 en `MDG`, 2 en `RZ`, `CS _forge_por_origin`/`_gitleaks_gate`).
4. **Forja = gh o glab por host** — `acg_forja_de_dir` (rama), `CS _forge_por_origin`, el case de `host` en `RZ` (×2); y la elección gh/glab por el texto (`acg__destino_de_mr_full`, `acg_origen_de_mr`, `acg_lista_prs_abiertos`, `_tool_es_gh`).
5. **¿Es un merge de MR?** — `acg_es_merge_mr` (regex, develop), `acg_es_merge_mr_regex` (regex, rama), `acg_clasifica_merge` (árbol), `ACG_ES_MERGE_MR_JQ`, y el `grep` de merge en el prólogo de `MDG` (sin jq y lib rota).
6. **Id del MR** — `acg_mrid` (regex), `acg_mrid_regex` (respaldo), `acg_mrid` (árbol), `acg__mrid_de_tokens`; y `MDG` la vuelve a invocar sobre `acg_despoja_comillas`.
7. **Detectar `git push` / comando git en texto** — `acg_es_push` (tokenizador), `acg_push_toca_base` (regex por subcomando), `acg_push_clasifica` (árbol), `acg_push_destino_base`, y el `grep 'git[[:space:]]+push'` del prólogo sin jq.
8. **Directorio del comando** — `acg_target_dir` (regex sobre el texto con `-C`, `--work-tree`, `--git-dir`, `cd`), `acg_dir_opaco` (regex del mismo `cd`), el recorte de 1.11 (árbol) y `acg_expande_home` (usada dentro de las tres búsquedas).
9. **Quitar comillas / heredocs / `-c`** — `acg_segmentos_ejecutables`, `acg_despoja_comillas`, `acg_comillas_a_marca`, el awk heredoc-ciego de `PA` y los 2 `sed` de comillas en `PA`/`acg_push_toca_base`, `ACG_AST_REDUCE_JQ`.
10. **Rama actual** — `acg_rama_actual` + 4 `git symbolic-ref`/`rev-parse --abbrev-ref` inline (`RZ`, `PA`, `LI-R`, `CS`).
11. **Convención de ramas de integración** — `acg_es_rama_integracion`, `bz_protegida`, `bz_resolver_base`, `bz_aviso_base` (distintas listas de patrones: `Develop[A-Z]*|integracion/*|epic/*` vs `Develop*|keep/*|epic/*|epic-*|integracion/*|integracion-*`).
12. **Ejecutar con timeout** — `acg__run_timeout`, `RZ _bz_run`, `LI-R _git_acotado`, `timeout` suelto en `MDG`.
13. **Léxico de release del usuario** — `acg_lexico_release`, `…_para_mr`, `…_afirmativo_para_mr` (misma regex de release en las tres), `acg_lexico_main_amplio`, `_es_release_explicito`, y la regla de gate por destino repetida en el prompt de `_juez_merge_uno` (dos veces) más el post-filtro determinista.
14. **Leer el transcript** — `acg_recent_intercalado`, `acg_user_lineas_hoy_cdmx`, `acg_tiene_user_fechado` (tres jq con el mismo filtro de meta/compact/inyecciones) y el conteo humano inline de `MDG` para «no pude leer».
15. **Squash/borrado de rama con la rama de origen** — flags en `MDG` (squash, `--delete-branch`) y los mismos flags impuestos en `CS` (y su aviso de `--auto`); `MDG` pide `--squash` para cerrar-slice solo por su excepción (1.8).
16. **Aviso de rama de integración / permisos de merge** — marca `repo-compartido` + grant + juez (`MDG`) frente a «solo integra a develop» (`CS`): dos puertas a la misma política.
17. **Barrer ramas** — `limpiar.sh ramas` (`LI-R`) y el barrido de zombies de `LI-W` (mismo `bz_es_zombie`, distinto borrado) más el disparo de `BR`.

Sin claro: `JC _juez_centinela` (`brain/hooks/juez-comun.sh`, línea 92, ningún llamador en los archivos leídos); `LI-X` borra `acg-mrdest-*` (patrón que ya no coincide con las cachés `acg-*` reales).
