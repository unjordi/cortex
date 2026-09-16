# analizar-comando-git.sh — LIB compartida (NO es un hook; se hace `source`). Razona sobre un comando
# git/glab/gh para los git-guards (git-branch-guard · merge-squash-guard · confirmar-merge-develop) →
# UNA sola lógica, dejan de divergir (antídoto al drift H2/H13). bash-3.2-safe. El consumidor verifica
# jq/git si los necesita. Vive junto a los hooks (como delegacion-comun.sh) → viaja en el mismo copy.
# shellcheck shell=bash

# ── PATH-AUGMENT para gh/glab (ROOT CAUSE del #78, corpus 2026-08-25→09-01) ──────────────────────────────
# En un launch GUI de Claude Code el subproceso-hook hereda el PATH MÍNIMO de launchd (/usr/bin:/bin:…),
# donde jq SÍ está (el guard corre) pero gh/glab NO (viven en /opt/homebrew/bin —Apple Silicon— o
# /usr/local/bin —Intel/Linux—) → TODA consulta de destino/lista de MR por API salía VACÍA y el fail-safe
# frenaba merges/releases LEGÍTIMOS ya autorizados ("la consulta de la base falló en el entorno del hook").
# Se AÑADEN (al FINAL, JAMÁS al frente: un gh/glab ya alcanzable —o un MOCK de test en el PATH— SIEMPRE
# gana; solo rescatamos el caso en que NO estaba) los dirs canónicos donde viven estos CLIs. PRECISIÓN
# PURA — NO afloja ningún gate: solo hace RESOLUBLE un destino que antes fallaba por ENTORNO; un destino
# 'main' resuelto sigue disparando el gate estricto de release, y un merge sin OK sigue frenando.
#   · ACG_EXTRA_BIN (colon-sep, opcional) se antepone a la lista canónica → escape hatch de config Y gancho
#     de test (inyectar un dir con un mock sin tocar el sistema).
#   · ACG_PATH_AUGMENT=0 lo DESACTIVA → un test puede simular fielmente "gh/glab genuinamente ausente".
# Idempotente (no re-agrega un dir ya en PATH) · bash-3.2-safe · corre 1× al sourcear la lib.
acg__augmenta_path() {
  [ "${ACG_PATH_AUGMENT:-1}" = 0 ] && return 0
  local d IFS=:
  for d in ${ACG_EXTRA_BIN:-} /opt/homebrew/bin /usr/local/bin "$HOME/.linuxbrew/bin" "$HOME/.local/bin" "$HOME/bin"; do
    [ -n "$d" ] && [ -d "$d" ] || continue
    case ":$PATH:" in *":$d:"*) : ;; *) PATH="$PATH:$d" ;; esac
  done
  export PATH
}
acg__augmenta_path

# ── M1 (auditoría 2026-09-15): SEGMENTACIÓN ejecutor-aware — ENTRADA ÚNICA de los 9 guards que antes
# copiaban a mano "quita lo entrecomillado" (7 sitios, 3 políticas de despoje distintas). Cierra DOS
# huecos OPUESTOS con el MISMO criterio (nunca hay que elegir un lado):
#   (a) FALSO NEGATIVO — `eval "git push origin develop"` / `bash -c "…"` / `sh -c '…'`: el span
#       entrecomillado ES shell que el intérprete va a EJECUTAR, no dato inerte → antes acg_despoja_comillas
#       lo borraba entero y los 5 git-guards quedaban ciegos al comando real. Se REINYECTA sin comillas.
#   (b) el CUERPO de un heredoc (`<<[-]DELIM … DELIM`) es STDIN: dato si alimenta un ESCRITOR (cat/tee/
#       >>archivo/…) — nunca se ejecuta — pero ES CÓDIGO si alimenta un INTÉRPRETE (bash/sh/zsh/dash/ksh/
#       python[3]/perl/ruby/pwsh: `bash <<EOF … EOF`). El filtro viejo de proteger-arbol descartaba TODO
#       heredoc sin mirar el consumidor: cerraba el FP de `cat >> doc.md <<EOF` pero abría el FN simétrico
#       de `bash <<EOF … EOF` (commit invisible). Un solo criterio decide los dos: el TOKEN antes de `<<`.
# acg_segmentos_ejecutables(cmd) → cmd con los heredocs resueltos (cuerpo conservado o descartado según el
# consumidor) y los spans entrecomillados de un EJECUTOR reinyectados; el resto de comillas (dato) las
# quita acg_despoja_comillas (abajo), que ahora es un WRAPPER de esta función — cada caller que ya la usaba
# (16 sitios en esta lib + 3 hooks) hereda el fix sin tocar su propio código.
acg_segmentos_ejecutables() {   # $1=cmd → texto con heredocs resueltos + comillas de EJECUTOR reinyectadas
  local cmd="$1" t
  t=$(printf '%s' "$cmd" | awk -v sq="'" -v dq='"' '
    BEGIN{ inhd=0; keep=0 }
    inhd==1 {
      s=$0; sub(/^[ \t]*/,"",s)
      if (s==delim) { inhd=0; next }
      if (keep==1) print
      next
    }
    {
      re="<<-?[ \t]*[" sq dq "]?[A-Za-z_][A-Za-z0-9_]*[" sq dq "]?"
      if (match($0, re)) {
        pre = substr($0, 1, RSTART-1)
        sub(/[ \t]+$/, "", pre)                        # quita el espacio pegado a "<<" (si no, el gsub de
        tok = pre                                       # abajo se come TODO el token: greedy hasta el ÚLTIMO separador)
        gsub(/^.*[ \t;&|]/, "", tok)                 # último token antes de "<<" (el comando que consume)
        gsub(/\.exe$/, "", tok)                        # tolera el binario Windows (bash.exe, sh.exe)
        d = substr($0, RSTART, RLENGTH); sub(/^<<-?[ \t]*/,"",d); gsub("[" sq dq "]","",d)
        delim = d; inhd = 1
        keep = (tok ~ /^(bash|sh|zsh|dash|ksh|python3?|perl|ruby|pwsh)$/) ? 1 : 0
      }
      print
    }')
  # Spans entrecomillados precedidos de un EJECUTOR (eval "…" · bash/sh/zsh/dash/ksh -c "…") → REINYECTA
  # el contenido SIN comillas (es código). El resto de comillas (dato) las quita acg_despoja_comillas.
  t=$(printf '%s' "$t" | sed -E 's/(^|[[:space:]])(eval|-c)[[:space:]]+"([^"]*)"/\1\2 \3/g')
  t=$(printf '%s' "$t" | sed -E "s/(^|[[:space:]])(eval|-c)[[:space:]]+'([^']*)'/\1\2 \3/g")
  printf '%s\n' "$t"
}

# Quita literales entre comillas simples o dobles → un "git push a develop" dentro de un mensaje de
# commit / dato de un grep / doc NO dispara los guards (Fix #2 · H13), PERO ya no a ciegas: primero pasa
# por acg_segmentos_ejecutables (arriba), que resuelve heredocs y reinyecta lo que un ejecutor SÍ corre.
acg_despoja_comillas() { printf '%s' "$(acg_segmentos_ejecutables "$1")" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g"; }

# ¿el comando contiene un `git commit`? (mismo ancla que acg_es_push — evita el drift de "grep sin
# frontera" que ya divergió en 2 de los hooks que hacían su propia copia a mano, auditoría 2026-09-15).
acg_es_commit() { printf '%s' "$1" | grep -qE 'git[[:space:]]+commit([[:space:]]|$)'; }

# Quita el VALOR de --repo/-R (p. ej. "-R org/develop") para que un repo cuyo nombre termine en
# /develop|/main NO genere un falso positivo de destino. (H11.)
acg_sin_flag_repo() { printf '%s' "$1" | sed -E 's/(--repo|-R)[[:space:]=]+[^[:space:]]+//g'; }

# Colapsa el PREFIJO de opciones globales de git entre `git` y su subcomando → `git --no-pager push …`,
# `git -c http.sslVerify=false push …`, `git --work-tree=/tmp push …` se normalizan a `git push …`. Sin
# esto, la adyacencia `git+push`/`git+commit` que exigen las detecciones se rompía y el comando evadía
# tanto los git-guards como el escaneo de secretos.
#   · A-03 (FMEA r1): cubrió `-c`/`-C`.
#   · A-R4-01/02 (FMEA r4): git acepta MUCHAS más globales (`--no-pager`, `-p`/`-P`, `--work-tree`,
#     `--git-dir`, `--namespace`, `--exec-path`, `--no-replace-objects`, `--literal-pathspecs`, …) → cada
#     una rompía la adyacencia y evadía TODO el guard de flujo (crítico) y el escaneo de secretos. Se generaliza a la CLASE,
#     no a la enumeración: (a) el set que consume un VALOR por espacio o `=` (debe ir 1º en la alternación
#     para comerse ese valor) y (b) CUALQUIER otro token dash-led (flag booleano o `--x=val`), así una
#     global NUEVA de git ya no reabre el hueco. `(…)+` en ERE lo soportan GNU y BSD sed; POSIX
#     leftmost-longest hace que (a) gane sobre (b) cuando puede comerse el valor.
#   · A-R5-01 (FMEA r5): el VALOR de un value-eater puede ir ENTRECOMILLADO con ESPACIOS —
#     `git -C "/Users/unjordi/Mi unidad/repo" push origin develop` (realista: rutas de Google Drive en
#     esta máquina). El `[^[:space:]]+` se cortaba en el 1er espacio → dejaba `Mi unidad/repo" push…`
#     colgando y rompía la adyacencia → evasión TOTAL. El valor se hace QUOTE-AWARE: `"..."` / `'...'`
#     (con espacios adentro) se consume como UNA unidad. IMPORTANTE: este normalizador corre sobre el RAW
#     (comillas intactas) ANTES de cualquier despoje — un consumidor que primero despoje comillas debe
#     invertir el orden (normalizar el raw, luego despojar) o el valor entrecomillado queda vacío.
#   · A-R6-01 (FMEA r6): la comilla puede ir EN MEDIO del valor — `git -c user.name="a b" push …`
#     (shell-válido, cotidiano). r5 cubrió la comilla al INICIO (`-C "/ruta"`) pero el valor MIXTO
#     `key="val con espacio"` no es ni bare-completo ni quoted-completo → el `[^space]+` se cortaba en el
#     espacio interno y volvía a romper la adyacencia → evasión TOTAL. El VALOR se modela como una SECUENCIA
#     de (char que no es espacio ni comilla | run "…" | run '…'): `([^[:space:]"']|"[^"]*"|'[^']*')+` — así
#     `user.name="a b"` = `user.name=` + `"a b"` casa entero, y las comillas donde sea dentro del token se respetan.
#   · A-R7-01 (FMEA r7): el espacio del valor puede ir ESCAPADO CON BACKSLASH en vez de entrecomillado
#     (`git -c a=b\ c push …` — el shell lo tokeniza como `-c "a=b c"`). El `\` se trataba como char normal
#     y la secuencia se cortaba en el espacio real → misma evasión. Se añade `\\.` (backslash+cualquier char)
#     como alternativa de la secuencia → el par escapado se consume como parte del valor.
# Solo casa opciones INMEDIATAMENTE tras `git` y se detiene en el 1er token NO-dash (el subcomando) → el
# `-c` de `git commit -c <commit>` (tras el subcomando) NO se toca, y `git push -u …` (0 globales) queda intacto.
#   · B4 (FMEA r8): en Windows el binario es `git.exe`; `git.exe push origin develop` rompía el `git`+espacio
#     que exigen TODOS los detectores → evasión total en un OS que la plantilla soporta (Git Bash). 1er sed:
#     colapsa `git.exe`→`git` en posición de ejecutable (inicio / tras separador) antes de todo lo demás.
acg_normaliza_git_prefijo() {
  printf '%s' "$1" \
    | sed -E 's/(^|[^[:alnum:]._-])git\.exe([[:space:]])/\1git\2/g' \
    | sed -E "s/git[[:space:]]+((((-c|-C|--exec-path|--git-dir|--work-tree|--namespace|--attr-source|--config-env|--super-prefix)([[:space:]]+|=)([^[:space:]\"']|\"[^\"]*\"|'[^']*'|\\\\.)+)|(--?[a-zA-Z][a-zA-Z-]*(=([^[:space:]\"']|\"[^\"]*\"|'[^']*'|\\\\.)+)?))[[:space:]]+)+/git /g"
}

# Rama actual del repo OBJETIVO. $1=target_dir (opcional). Retro-compat: SIN arg cae a CLAUDE_PROJECT_DIR
# (= conducta de hoy, el repo de la SESIÓN); con arg evalúa la rama del repo que el comando REALMENTE toca.
acg_rama_actual() { git -C "${1:-${CLAUDE_PROJECT_DIR:-.}}" rev-parse --abbrev-ref HEAD 2>/dev/null; }

# ── RESOLVEDOR DE TARGET (cimiento cross-repo, auditoría 2026-08-06) ────────────────────────────────────
# Los git-guards keyeaban el "repo objetivo" desde CLAUDE_PROJECT_DIR (el repo donde ARRANCÓ la sesión), no
# desde el repo que el comando REALMENTE toca (otro cwd, un `-C <dir>`, un `cd <dir>`, un `--repo/-R`). Eso
# producía FN (dejar pasar un push a base en OTRO repo) y FP (gatear/bloquear el repo equivocado). Estos dos
# helpers resuelven el target por PRECEDENCIA explícita, fuente ÚNICA para los tres guards (no divergen).
# El `cwd` del payload es la señal correcta para el caso PELÓN: gh/glab/git sin destino resuelven desde el
# cwd, EXACTAMENTE el dato que la herramienta usaría. bash-3.2-safe · BSD+GNU sed.

# acg_expande_home(ruta) → la ruta con el `~` / `$HOME` INICIAL resuelto a $HOME. El shell expande esos
# prefijos ANTES de que el binario los vea (`cd ~/code/axon` → /home/…/code/axon), pero los guards leen el
# TEXTO del comando, donde el `~` sigue literal → `git -C '~/code/axon'` FALLA y el repo objetivo quedaba
# IRRESOLUBLE. Consecuencia real (FP 2026-09-08, MR 87 de axon y PR 19 de odysseus): TARGET_ROOT no
# resolvía a un repo git ⇒ (a) el slug del remoto salía VACÍO y la consulta de la base corría contra el
# repo del cwd del hook (otro repo, otro foro) → "no pude CONFIRMAR el destino"; (b) el `--repo` explícito
# no casaba con el slug local ⇒ INCIERTO ⇒ gateaba repos PERSONALES que están FUERA del alcance del guard.
# Corrección de DETECCIÓN de target (no afloja nada: solo hace que el dir que el guard inspecciona sea el
# MISMO que el shell usó). Solo el prefijo INICIAL, y solo `~`/`~/…`/`$HOME`/`${HOME}` (no `~otrousuario`,
# que no podemos resolver de forma portable). bash-3.2-safe, sin `eval`.
acg_expande_home() {   # $1=ruta → ruta con ~ / $HOME inicial expandido
  local p="$1"
  case "$p" in
    '~')            printf '%s' "$HOME" ;;
    '~/'*)          printf '%s/%s' "$HOME" "${p#\~/}" ;;
    '$HOME')        printf '%s' "$HOME" ;;
    '${HOME}')      printf '%s' "$HOME" ;;
    '$HOME/'*)      printf '%s/%s' "$HOME" "${p#\$HOME/}" ;;
    '${HOME}/'*)    printf '%s/%s' "$HOME" "${p#\$\{HOME\}/}" ;;
    *)              printf '%s' "$p" ;;
  esac
}

# acg_target_dir(cmd, payload_cwd) → DIRECTORIO del repo objetivo. Precedencia: -C > cd/pushd > payload_cwd
# > CLAUDE_PROJECT_DIR > '.'. Opera sobre el cmd CON comillas INTACTAS (para leer una ruta entrecomillada de
# -C/cd) y ANTES de acg_normaliza_git_prefijo (que DESPOJA el -C) → por eso el consumidor pasa el segmento
# ORIGINAL, no el normalizado. El modelo de valor (bare | "…" | '…' | \escapado) reusa el de normaliza_git_prefijo.
acg_target_dir() {   # $1=cmd  $2=payload_cwd → imprime el dir objetivo
  local cmd="$1" pcwd="${2:-}" d=""
  # (1) -C <dir> del git (quote-aware; el `.*` codicioso toma el ÚLTIMO -C, normalmente el único)
  d=$(printf '%s' "$cmd" | sed -nE "s/.*(^|[^[:alnum:]])-C[[:space:]=]+(\"[^\"]*\"|'[^']*'|([^[:space:]\"']|\\\\.)+).*/\2/p" | head -1)
  d=$(printf '%s' "$d" | sed -E "s/^[\"']//; s/[\"']\$//")
  if [ -n "$d" ]; then acg_expande_home "$d"; return 0; fi
  # (2) cd/pushd <dir> en el segmento (quote-aware; el valor NO cruza ;&|)
  d=$(printf '%s' "$cmd" | sed -nE "s/.*(^|[^[:alnum:]])(cd|pushd)[[:space:]]+(\"[^\"]*\"|'[^']*'|([^[:space:]\"';&|]|\\\\.)+).*/\3/p" | head -1)
  d=$(printf '%s' "$d" | sed -E "s/^[\"']//; s/[\"']\$//")
  if [ -n "$d" ]; then acg_expande_home "$d"; return 0; fi
  # (3) payload cwd  (4) CLAUDE_PROJECT_DIR  (5) '.'
  if [ -n "$pcwd" ]; then printf '%s' "$pcwd"; return 0; fi
  printf '%s' "${CLAUDE_PROJECT_DIR:-.}"
}

# acg_target_remote(cmd, payload_cwd) → slug `org/repo` del remoto objetivo (para gh/glab). Precedencia:
# --repo/-R explícito > remoto `origin` del DIR objetivo (que a su vez sigue -C > cd > cwd > PROJECT_DIR).

# M9 (auditoría 2026-09-15 §2.5/§4.3): extrae el valor de --repo/-R como UNIDAD (bare | "…" | '…'), no con
# `[^[:space:]]+` que se corta en el primer espacio. Antes, con `--repo "$R" --squash` sobre el cmd RAW,
# `[^[:space:]]+` capturaba `"$R"` completo (con comillas) → `acg_target_remote` devolvía el slug CON
# comillas → la consulta fallaba garantizado. Y si el CALLER despojaba comillas ANTES de grep (como hacía
# confirmar-merge-develop) el valor `"$R"` se BORRABA entero, dejando `--repo  --squash`, y el grep se comía
# el FLAG SIGUIENTE (`--squash`) como si fuera el slug — el guard creía que el repo se llamaba "--squash".
# Devuelve el slug LITERAL, o el token "OPACO" si el valor contiene una sustitución de shell ($/`/${) — un
# --repo "$VAR" es OPACO (no sabemos a qué repo apunta), NO "otro repo": el caller debe caer al remoto del
# dir objetivo (lo que el shell habría resuelto), NUNCA tratarlo como "repo ajeno ⇒ incierto ⇒ gatea".
acg_repo_explicito() {   # $1=cmd(RAW, comillas intactas) → slug LITERAL | "OPACO" | vacío
  local cmd="$1" m v
  m=$(printf '%s' "$cmd" | grep -oE "(--repo|-R)[[:space:]=]+(\"[^\"]*\"|'[^']*'|[^[:space:]]+)" | head -1)
  [ -n "$m" ] || { printf ''; return 0; }
  v=$(printf '%s' "$m" | sed -E "s/^(--repo|-R)[[:space:]=]+//")
  case "$v" in
    \"*\") v="${v#\"}"; v="${v%\"}" ;;
    \'*\') v="${v#\'}"; v="${v%\'}" ;;
  esac
  case "$v" in *'$'*|*'`'*) printf 'OPACO'; return 0 ;; esac
  printf '%s' "$v"
}

acg_target_remote() {   # $1=cmd  $2=payload_cwd → imprime "org/repo" | vacío
  local cmd="$1" pcwd="${2:-}" repo dir
  repo=$(acg_repo_explicito "$cmd")
  # OPACO (--repo "$VAR": no sabemos a qué repo apunta) → NO es un slug usable; cae al remoto del dir
  # objetivo, igual que si no hubiera --repo (M9: opaco ≠ ajeno).
  if [ -n "$repo" ] && [ "$repo" != "OPACO" ]; then printf '%s' "$repo"; return 0; fi
  dir=$(acg_target_dir "$cmd" "$pcwd")
  git -C "$dir" remote get-url origin 2>/dev/null | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##'
}

# ¿el comando contiene un `git push`?
acg_es_push() { printf '%s' "$1" | grep -qE 'git[[:space:]]+push([[:space:]]|$)'; }

# Extrae el MR-id del comando: el 1er entero "suelto" (opcional #) tras `mr merge`/`pr merge`, TOLERANTE a
# flags intermedios (`glab mr merge --yes 9` → 9). Antes se exigía el id ADYACENTE al subcomando (A-04, FMEA).
# MULTI-COMANDO (fix 2026-08): primero AÍSLA el SEGMENTO del ÚLTIMO subcomando de merge (parte por ; & |
# y newline con awk gsub→\n real, portable BSD+GNU, igual que acg_push_toca_base) y extrae el id de ESE
# segmento. Antes tomaba el 1er entero del BLOB completo → `gh pr view 272 …; gh pr merge 273 …` devolvía
# 272 (el id EQUIVOCADO, del `view`), no 273 (el `merge` real) → el DENY citaba el MR erróneo.
acg_mrid() {
  local seg
  seg=$(printf '%s' "$1" | awk '{gsub(/[;&|]/,"\n")}1' \
    | grep -E '(mr[[:space:]]+(merge|accept)|pr[[:space:]]+merge)' | tail -1)
  [ -n "$seg" ] || seg="$1"
  printf '%s' "$seg" | sed -E 's/.*(mr[[:space:]]+(merge|accept)|pr[[:space:]]+merge)[[:space:]]+//' | tr ' ' '\n' | grep -m1 -E '^#?[0-9]+$' | tr -d '#'
}

# ¿nombra develop/main como DESTINO explícito del push, en el MISMO segmento (no cruza ; && ||),
# precedido por espacio/:/'/'/'+' (no matchea feat/develop-x)? El '+' cubre el FORCE-REFSPEC
# (`git push origin +develop`, `git push -f origin +develop`) — el push FORZADO a base, el más
# peligroso, que sin el '+' en el set de separadores se colaba (A2, FMEA 2026-07-30).
#   · G3/G4 (auditoría 2026-08-06): la FRONTERA posterior era demasiado estricta (`[[:space:]]|$`) → un
#     metacarácter de shell PEGADO a la base la evadía: `(git push origin develop)` (subshell, `)` pegado)
#     y `git push origin develop>log` (redirect `>` pegado). Se amplía a `([[:space:]]|$|[)>&|;])` — cierra
#     ambos. VERIFICADO: casa `develop)`/`develop>` y NO casa `develop-feature`/`feat/develop-x` (cero FP).
acg_push_destino_base() {
  printf '%s' "$1" | grep -qE 'git[[:space:]]+push[^;&|]*[[:space:]:/+](main|master|develop)([[:space:]]|$|[)>&|;])'
}

# H2 (auditoría de ejecución 2026-09-16, MEDIO, CONFIRMADO): ¿el push nombra un destino OPACO (sustitución
# de shell: $VAR, ${VAR}, `cmd`, $(cmd)) en vez de un literal? Mismo criterio que acg_repo_explicito con
# --repo "$VAR" (M9): la incertidumbre GATEA, nunca se asume "no es la base" solo porque el TEXTO no la
# nombra literal — `git push origin "$RAMA"` podría resolver a develop/main en tiempo de shell y el guard
# quedaría CIEGO (medido: acg_push_destino_base no lo detecta, acg_push_sin_refspec tampoco porque SÍ hay
# un refspec, solo que es opaco). Opera sobre el segmento CON comillas intactas (acg_despoja_comillas
# borraría el '$'/backtick junto con el contenido).
acg_push_destino_opaco() {
  local seg rest tok
  seg=$(printf '%s' "$1" | grep -oE 'git[[:space:]]+push[^;&|]*' | head -1)
  [ -n "$seg" ] || return 1
  rest=$(printf '%s' "$seg" | sed -E 's/^git[[:space:]]+push[[:space:]]*//')
  for tok in $rest; do
    case "$tok" in
      -*) : ;;
      *'$'*|*'`'*) return 0 ;;
    esac
  done
  return 1
}

# ¿el push va SIN un refspec de rama explícito? (pelón, o solo remoto, o `HEAD` → empuja la RAMA
# ACTUAL). Heurística: tras `git push`, quitando opciones (-x/--x/--x=val) y `HEAD`, quedan ≤1
# posicionales (a lo más el remoto). (H1.)
acg_push_sin_refspec() {
  local seg rest tok posargs=0
  seg=$(printf '%s' "$1" | grep -oE 'git[[:space:]]+push[^;&|]*' | head -1)
  [ -n "$seg" ] || return 1
  rest=$(printf '%s' "$seg" | sed -E 's/^git[[:space:]]+push[[:space:]]*//; s/(-o|--push-option)[[:space:]=]+[^[:space:]]+//g')
  for tok in $rest; do
    case "$tok" in
      -*)   : ;;                       # opción → ignora
      HEAD) : ;;                       # HEAD = la rama actual, no un destino explícito
      *)    posargs=$((posargs+1)) ;;  # posicional (remoto o refspec de rama)
    esac
  done
  [ "$posargs" -le 1 ]
}

# ¿un `git checkout/switch` de un segmento PREVIO cambia a QUÉ rama? Imprime "NUEVA <r>" (creada con
# -b/-B/-c/--create → es rama por definición, aunque aún no exista como ref) · "POSIC <r>" (checkout/switch
# a un nombre que PODRÍA ser rama o archivo → el consumidor verifica refs/heads) · vacío (no aplica). Opera
# sobre un segmento YA despojado/normalizado. bash-3.2-safe. (FP corpus L109, 2026-09-03 ×2: un compuesto
# `git checkout fix/x && git push` resolvía la rama contra el HEAD ANTERIOR —develop— en vez de fix/x.)
acg_checkout_rama() {   # $1=segmento(despojado) → "NUEVA <r>" | "POSIC <r>" | vacío
  local s="$1" rest tok want_new=0 posname=""
  printf '%s' "$s" | grep -qE 'git[[:space:]]+(checkout|switch)([[:space:]]|$)' || return 0
  rest=$(printf '%s' "$s" | sed -E 's/.*git[[:space:]]+(checkout|switch)[[:space:]]*//')
  # Recorre los tokens tras checkout/switch: -b/-B/-c/--create ⇒ el SIGUIENTE token es la rama NUEVA; si no,
  # el 1er posicional (no-flag) es la rama/archivo destino. Parseo por tokens (sin glob): bash-3.2-safe.
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    if [ "$want_new" = 1 ]; then printf 'NUEVA %s' "$tok"; return 0; fi
    case "$tok" in
      -b|-B|-c|--create) want_new=1 ;;
      -*)                : ;;
      *)                 [ -z "$posname" ] && posname="$tok" ;;
    esac
  done <<EOF
$(printf '%s' "$rest" | tr ' ' '\n')
EOF
  [ -n "$posname" ] && printf 'POSIC %s' "$posname"
}

# ¿el comando EMPUJARÍA a develop/main? — explícito (nombra la rama) O pelón cuando el repo OBJETIVO está
# en develop/main. Opera sobre el cmd SIN comillas ni --repo para la detección; el dir objetivo se resuelve
# CON comillas (acg_target_dir). Cierra H1 (+ H11/H13) y el FN cross-repo (pelón a OTRO repo en base).
# FAIL-SAFE del pelón: si la rama del repo objetivo es IRRESOLUBLE (sin git / dir inexistente / no-git),
# BLOQUEA (nunca fail-open) — backstop adicional = ramas protegidas server-side.
acg_push_toca_base() {   # $1=cmd  $2=payload_cwd(opcional)
  local pcwd="${2:-}" orig sub subu subq cd_prefix="" dir rama co_spec="" _cob
  # A-R3-01 (FMEA r3): recorre CADA subcomando (separado por ; && || & |). Un push a base en CUALQUIERA
  # cuenta — un `git push origin feat/x ; git push origin develop` ya no se cuela por el 2º (el head -1
  # anterior solo miraba el 1º). Cada subcomando se evalúa AISLADO: un "git push …develop" DENTRO del
  # mensaje de un commit entrecomillado NO cuenta (ese subcomando es el commit; su despoja borra el mensaje
  # → es_push=no → se salta; preserva H13). En un subcomando que SÍ es push real evaluamos: A-02
  # (--all/--mirror), destino ENTRECOMILLADO/refspec (A-01/N-01: desquotando ESE subcomando), y el
  # pelón/HEAD por la rama actual DEL REPO OBJETIVO.
  # RESOLVEDOR CROSS-REPO (2026-08-06): se itera sobre el cmd ORIGINAL (con -C intacto) y se normaliza
  # CADA segmento (equivalente a normalizar el todo — el prefijo global no cruza ;&|). Para el caso PELÓN,
  # el dir objetivo se resuelve PER-SEGMENTO (el `-C` del propio segmento, o un `cd <dir>` de un segmento
  # PREVIO de la cadena) → la rama se evalúa contra el repo que el push REALMENTE toca, no el de la sesión.
  while IFS= read -r orig; do
    [ -n "$orig" ] || continue
    sub=$(acg_normaliza_git_prefijo "$orig")   # A-03: colapsa `git -c/-C …` para no romper la adyacencia git+push
    subu=$(acg_sin_flag_repo "$(acg_despoja_comillas "$sub")")
    # rastrea un `cd/pushd <dir>` para los segmentos POSTERIORES de la cadena (aplica al push que le sigue)
    if printf '%s' "$subu" | grep -qE '^[[:space:]]*(cd|pushd)[[:space:]]'; then cd_prefix="$orig"; fi
    # rastrea un `git checkout/switch <rama>` PREVIO: un pelón posterior empuja a ESA rama, no a la de HEAD
    # antes del comando (FP corpus L109). Se guarda el spec; se resuelve contra el repo objetivo en el pelón.
    _cob=$(acg_checkout_rama "$subu"); [ -n "$_cob" ] && co_spec="$_cob"
    acg_es_push "$subu" || continue
    printf '%s' "$subu" | grep -qE 'git[[:space:]]+push[^;&|]*[[:space:]](--all|--mirror)([[:space:]]|$)' && return 0
    subq=$(acg_sin_flag_repo "$(printf '%s' "$sub" | tr -d "'\"")")
    acg_push_destino_base "$subq" && return 0
    # H2 (auditoría de ejecución 2026-09-16 §2, MEDIO): destino OPACO (sustitución de shell) → incertidumbre,
    # GATEA (no se asume "no es la base" solo porque el texto no la nombra literal). Se evalúa sobre `$sub`
    # (comillas intactas) ANTES de `acg_push_sin_refspec` porque un refspec opaco SÍ cuenta como refspec
    # (posargs=1) y nunca entraría a la rama pelón de abajo — quedaría silenciosamente sin cubrir.
    acg_push_destino_opaco "$sub" && return 0
    if acg_push_sin_refspec "$subu"; then
      dir=$(acg_target_dir "$cd_prefix $orig" "$pcwd")   # -C del segmento > cd previo > cwd > PROJECT_DIR
      # Si un checkout/switch PREVIO cambió de rama, el pelón empuja a ESA rama (no a la de HEAD antes del
      # comando). NUEVA (-b/-c) es rama por definición; POSIC solo se cree si es una rama LOCAL real (si no
      # —un archivo, un typo— cae a acg_rama_actual: fail-safe, si HEAD es base sigue bloqueando).
      rama=""
      case "$co_spec" in
        "NUEVA "*) rama="${co_spec#NUEVA }" ;;
        "POSIC "*) _cob="${co_spec#POSIC }"
                   git -C "$dir" rev-parse --verify --quiet "refs/heads/$_cob" >/dev/null 2>&1 && rama="$_cob" ;;
      esac
      [ -n "$rama" ] || rama=$(acg_rama_actual "$dir")
      case "$rama" in
        main|master|develop) return 0 ;;
        "")           return 0 ;;   # FAIL-SAFE: rama IRRESOLUBLE en un pelón ⇒ BLOQUEA (nunca fail-open)
      esac
    fi
  done <<EOF
$(acg_segmentos_ejecutables "$1" | awk '{gsub(/[;&|]/,"\n")}1')
EOF
  return 1
}
# M1 (nota de orden, no repetir el bug): el heredoc se resuelve SOBRE EL TODO, ANTES de partir en líneas/
# subcomandos — un cmd con newlines REALES ya llega partido en registros al loop de arriba, así que si el
# split ocurriera antes, cada línea del CUERPO de un heredoc (p. ej. "git push origin develop" dentro de un
# `cat > d.md <<EOF`) se evaluaría COMO SI fuera su propio subcomando, sin que el consumidor (`cat` vs
# `bash`) fuera visible ya — el contexto de "a quién alimenta" se pierde en cuanto se parte por línea.

# ¿el comando mergea un MR/PR nombrando develop·main como destino? (para el bloqueo de release-a-main
# de git-branch-guard: mismo comportamiento de antes, pero sobre cmd sin comillas ni --repo → H11/H13).
acg_merge_menciona_base() {
  local u; u=$(acg_sin_flag_repo "$(acg_despoja_comillas "$1")")
  # G6 (auditoría 2026-08-06): el 1er POSICIONAL de `gh pr merge <arg>` / `glab mr merge <arg>` es el #/rama
  # de ORIGEN del MR, NUNCA el destino — un `gh pr merge develop` de un release develop→main NO nombra base
  # como destino. Antes se trataba CUALQUIER `develop`/`main` tras el subcomando como destino → FP que
  # bloqueaba el release por CLI. El destino REAL lo resuelve acg_destino_de_mr (target-aware). Aquí solo
  # cuenta un destino EXPLÍCITO por flag (--base/--target[-branch]/-B). Alineado con acg_es_merge_mr
  # ((\.exe)? Windows + merge|accept).
  printf '%s' "$u" | grep -qE '(glab(\.exe)?[[:space:]]+mr[[:space:]]+(merge|accept)|gh(\.exe)?[[:space:]]+pr[[:space:]]+merge)[^;&|]*[[:space:]](--base|--target|--target-branch|-B)[[:space:]=]+(main|master|develop)([[:space:]]|$|[)>&|;])'
}

# ¿el comando EJECUTA una integración REAL de MR/PR (server-side), no ayuda/inspección? Reconoce el
# subcomando REAL `glab mr (merge|accept)` / `gh pr merge`. Antídoto a H3: el viejo escape de
# confirmar-merge-develop casaba `status|list|view` como TOKEN SUELTO en CUALQUIER parte del comando,
# así que `glab mr merge 5 --yes && git status` evadía el gate (el `status` del OTRO comando encadenado
# disparaba el escape). Aquí solo `--help`/`-h`/`--dry-run` (inspección genuina) NO cuentan como merge;
# `glab mr list|view`/`gh pr view` tampoco disparan porque no matchean merge|accept. Sobre cmd sin
# comillas ni --repo (H11/H13). Un `git merge` LOCAL no matchea → sigue libre.
acg_es_merge_mr() {
  local u; u=$(acg_sin_flag_repo "$(acg_despoja_comillas "$1")")
  # `(\.exe)?`: en Windows el binario es `glab.exe`/`gh.exe` — sin esto el `.exe` rompía el
  # `glab`/`gh`+espacio y ambos guards de merge (squash + confirmar-merge) quedaban ciegos (H-R9-01, hermano de B4).
  printf '%s' "$u" | grep -qE '(glab(\.exe)?[[:space:]]+mr[[:space:]]+(merge|accept)|gh(\.exe)?[[:space:]]+pr[[:space:]]+merge)([[:space:]]|$)' || return 1
  printf '%s' "$u" | grep -qE '(^|[[:space:]])(--help|-h|--dry-run)([[:space:]]|$)' && return 1
  return 0
}

# Corre un comando acotado por TIMEOUT (segundos). Usa timeout/gtimeout si existen (Linux, Git Bash,
# macOS con coreutils); si no, un fallback bash puro (corre en bg, un watcher lo mata si excede). Meta:
# que la consulta de red NUNCA cuelgue al hook hasta que el CLI lo mate → evita el fail-open por MUERTE
# del proceso (H5). El watcher redirige su stdout a /dev/null para no retener el pipe hacia jq.
acg__run_timeout() {
  local secs="$1"; shift
  if command -v timeout  >/dev/null 2>&1; then timeout  "$secs" "$@"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return $?; fi
  local pid w rc
  "$@" & pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 & w=$!
  wait "$pid" 2>/dev/null; rc=$?
  kill -TERM "$w" 2>/dev/null; wait "$w" 2>/dev/null
  return "$rc"
}

# Corre un comando acotado por timeout DESDE el directorio objetivo del comando original. Por qué:
# `gh`/`glab` resuelven el repo del CWD cuando no reciben `-R`, y el hook corre en SU propio cwd (el de la
# sesión), que puede ser OTRO repo — incluso de otro foro (GitLab vs GitHub). Así, un `cd <repo> && gh pr
# merge N` con slug irresoluble consultaba la base en el repo EQUIVOCADO → o fallaba ("no pude CONFIRMAR el
# destino", FP 2026-09-08 del MR 87) o —peor— podía devolver la base de otro repo. Corriendo la consulta en
# el dir objetivo, la herramienta resuelve EXACTAMENTE lo que resolvería el comando del usuario. Si el dir
# no existe/no es accesible, se queda en el cwd actual (conducta de antes, nunca peor).
acg__run_en_dir() {   # $1=dir  $2=segundos  $3.. = comando
  local d="$1"; shift
  ( if [ -n "$d" ] && [ -d "$d" ]; then cd "$d" 2>/dev/null || :; fi
    acg__run_timeout "$@" )
}

# Extrae el destino EXPLÍCITO del PROPIO comando de merge, si viene por flag de base
# (gh: --base/-B · glab: --target-branch/--target). Es la fuente MÁS confiable del destino y NO cuesta
# red, ni gh/glab, ni jq: el destino ya está TIPEADO en el comando que disparó el hook. Devuelve la rama
# por stdout (vacío si el comando no trae flag de base → el caller cae al lookup por API). Trabaja sobre
# el comando SIN comillas ni --repo (para no confundir un `--repo x/y` con el destino). bash-3.2-safe.
acg_destino_explicito_del_comando() {   # $1=comando → rama destino | vacío
  local u m
  u=$(acg_sin_flag_repo "$(acg_despoja_comillas "$1")")
  # `grep -oE … | head -1`: el 1er flag de destino con su valor (nombre de rama: letras/dígitos/._/-).
  # --target-branch va ANTES de --target en la alternación (leftmost-longest de ERE igual lo tomaría, pero
  # ser explícito es a prueba de balas). Luego se recorta el nombre del flag para dejar solo la rama.
  m=$(printf '%s' "$u" | grep -oE '(--target-branch|--target|--base|-B)[[:space:]=]+[A-Za-z0-9._/-]+' | head -1)
  [ -n "$m" ] || return 0
  printf '%s' "$m" | sed -E 's/^(--target-branch|--target|--base|-B)[[:space:]=]+//'
}

# Resuelve el target_branch de un MR/PR (glab/gh) para decidir el destino del merge, con:
#  - CACHÉ por (repo,herramienta,mr-id) en TMPDIR → COMPARTIDA entre merge-squash-guard y
#    confirmar-merge-develop: el MISMO `glab mr merge` los dispara a AMBOS ⇒ misma clave. Si un hook
#    corre ANTES que el otro (el caso normal), el 2º relee el caché ⇒ 1 llamada de red, no 2. Ojo: NO
#    es un lock — bajo ejecución REALMENTE simultánea ambos podrían leer el caché vacío y llamar los
#    dos (2 llamadas idénticas, inocuo). Solo cachea un resultado NO vacío (un vacío por timeout/error
#    se reintenta la próxima).
#  - TIMEOUT interno corto (ACG_MR_TIMEOUT, default 6s) para que el proceso SIEMPRE termine y EMITA su
#    decisión, en vez de que el CLI lo mate por colgarse y trate el merge como "sin deny" (fail-open por
#    muerte del proceso, H5). M11 (auditoría 2026-09-15 §3.12, doc=realidad): esto YA NO se compara contra
#    "el timeout del hook en settings.json" — install-brain.sh cablea los hooks SIN clave `timeout`
#    (verificado: `ev_de()`/el registrador de hooks no emite ese campo), así que NINGÚN hook de esta
#    familia tiene un timeout EXTERNO que lo mate — la única protección real es este timeout INTERNO.

# ── M3 (auditoría 2026-09-15 §3.3/§4.2/§4.3): ACG_DEST_CONF — el destino deja de ser "rana o vacío" y pasa
# a traer, además, la CONFIANZA con que se resolvió. Antes "fuera de alcance" (rama personal, repo
# personal) y "no pude resolver" (parseo/red/PATH/dir) colapsaban en el MISMO vacío silencioso (§4.2) →
# de ahí salían a la vez el FP dominante (gate que frena por fallo de entorno, §3.3) y el FN dominante
# (guard que asume mal, §3.4). Ahora TODO consumidor puede distinguir "no aplica" (rama resuelta que no es
# develop/main) de "sí aplica pero no sé cuál" (DESCONOCIDO:<motivo>), y M4/M5/M6/M8 leen ese motivo en vez
# de adivinarlo. Motivos declarados: SIN-CLI (no jq) · DIR-IRRESOLUBLE (target_dir no existe) · SIN-MRID
# (no se ancló ningún id de MR/PR) · SLUG-OPACO (--repo "$VAR" Y el remoto local tampoco resuelve, M9) ·
# SIN-RED (ni gh ni glab alcanzables en el PATH) · TIMEOUT (la consulta corrió y no volvió a tiempo/vacía).
# acg__destino_de_mr_full(cmd, pcwd) → DOS líneas por stdout: (1) destino | vacío  (2) CONF, uno de
# EXPLICITO|API|CACHE-DE-CREACION|DESCONOCIDO:<motivo>. Único sitio que TOCA la caché (evita que el
# resolvedor de destino y el de confianza diverjan, el mismo defecto de sustrato que motivó este dictamen).
# Cachea las DOS líneas juntas: recomputar la confianza de un resultado YA resuelto es un cache-hit (no
# cuesta una 2ª llamada de red) — así `acg_destino_de_mr` (retro-compat, 1 línea) y `acg_destino_conf`
# (nueva) pueden llamarse por separado sin duplicar trabajo ni divergir.
ACG_MR_TIMEOUT="${ACG_MR_TIMEOUT:-6}"
# H1 (auditoría de ejecución 2026-09-16, ALTO, CONFIRMADO): el caché REGULAR (acg-mrdest-<key>, y sus
# hermanos acg-mrmsg-*/acg-prlist-*) se leía SIN NINGUNA verificación — ni dueño, ni permisos, ni EDAD. El
# fix MEDIO original (acg__cache_creacion_es_mia) endureció SOLO al hermano -creacion-* y dejó a ÉSTE, el que
# de verdad gatea confirmar-merge-develop Y merge-squash-guard, intacto: un archivo plantado con destino
# 'DevelopUnjordi' (o simplemente VIEJO — un MR re-apuntado de develop a main, operación normal en GitLab/
# GitHub) se servía como si fuera la respuesta de la API de HACE UN SEGUNDO. Generalizado a
# acg__cache_confiable (reemplaza acg__cache_creacion_es_mia, mismo criterio + TTL): mismo UID, sin permisos
# de grupo/otros, Y no más viejo que ACG_CACHE_TTL_DIAS (default: el MISMO `CLAUDE_RESIDUO_DIAS_TMP` que ya
# declara limpiar-residuo.sh para esta familia de archivos, 7 días — aquí se HACE CUMPLIR en LECTURA, no
# solo en el barrido periódico manual). portable BSD `stat -f` / GNU `stat -c`; sin `stat`/`date`, fail
# CERRADO (no confiar es lo seguro; la peor consecuencia es un cache-miss que cae al lookup por API).
acg__cache_confiable() {   # $1=path → 0=confiable (uid+perm+TTL) · 1=no
  local f="$1" uid perm mtime now ttl_dias
  uid=$(stat -f '%u' "$f" 2>/dev/null || stat -c '%u' "$f" 2>/dev/null) || return 1
  perm=$(stat -f '%Lp' "$f" 2>/dev/null || stat -c '%a' "$f" 2>/dev/null) || return 1
  mtime=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null) || return 1
  now=$(date +%s) || return 1
  [ "$uid" = "$(id -u)" ] || return 1
  case "$perm" in *00) : ;; *) return 1 ;; esac
  ttl_dias="${ACG_CACHE_TTL_DIAS:-${CLAUDE_RESIDUO_DIAS_TMP:-7}}"
  case "$ttl_dias" in ''|*[!0-9]*) ttl_dias=7 ;; esac
  [ $(( (now - mtime) / 86400 )) -lt "$ttl_dias" ]
}
acg__destino_de_mr_full() {   # $1=comando  $2=payload_cwd(opcional) → 2 líneas: destino \n CONF
  local raw="$1" pcwd="${2:-}" u tool repo mrid key cache cache_c dest dir out
  # (b) PREFERIDO — destino EXPLÍCITO del PROPIO comando (--base/--target-branch): SIN red, SIN gh/glab,
  # SIN jq. Sortea el modo de falla (a): en un launch GUI de Claude Code el subproceso-hook hereda el PATH
  # MÍNIMO de launchd (/usr/bin:/bin:…), donde jq SÍ está (/usr/bin/jq → el guard corre y gatea) pero gh/glab
  # NO (viven solo en /opt/homebrew/bin) → la consulta a la API salía VACÍA y el fail-safe frenaba merges
  # legítimos. (Auth NO es la causa: gh-keyring y glab-file autentican bien desde un subproceso CUANDO están
  # en el PATH.) Si el destino NO viene en el comando, se cae al lookup por API de abajo (requiere jq + CLI).
  dest=$(acg_destino_explicito_del_comando "$raw")
  if [ -n "$dest" ]; then printf '%s\nEXPLICITO\n' "$dest"; return 0; fi
  if ! command -v jq >/dev/null 2>&1; then printf '\nDESCONOCIDO:SIN-CLI\n'; return 0; fi
  dir=$(acg_target_dir "$raw" "$pcwd")   # cwd de la consulta: el dir que el comando REALMENTE toca
  if [ -z "$dir" ] || [ ! -d "$dir" ]; then printf '\nDESCONOCIDO:DIR-IRRESOLUBLE\n'; return 0; fi
  u=$(acg_despoja_comillas "$raw")
  if printf '%s' "$u" | grep -qE 'glab(\.exe)?[[:space:]]+mr'; then tool=glab; else tool=gh; fi  # (\.exe)?: binario Windows (H-R9-01)
  mrid=$(acg_mrid "$u")
  if [ -z "$mrid" ]; then printf '\nDESCONOCIDO:SIN-MRID\n'; return 0; fi
  # Repo objetivo por PRECEDENCIA (--repo/-R > remoto del dir objetivo: -C > cd > cwd > PROJECT_DIR). Antes
  # el fallback leía SIEMPRE el remoto de CLAUDE_PROJECT_DIR → resolvía el destino del repo equivocado.
  repo=$(acg_target_remote "$raw" "$pcwd")
  # M9: un --repo OPACO ($VAR) que ADEMÁS no resuelve al remoto local (repo git sin 'origin', o el dir no es
  # un repo) es SLUG-OPACO de verdad — no "otro repo", pero tampoco uno que podamos consultar.
  if [ -z "$repo" ] && [ "$(acg_repo_explicito "$raw")" = "OPACO" ]; then printf '\nDESCONOCIDO:SLUG-OPACO\n'; return 0; fi
  # La clave del caché incluye el DIR cuando el slug del remoto sale vacío: si no, dos repos distintos con
  # slug irresoluble compartían la MISMA entrada de caché y uno heredaba la base del otro.
  key=$(printf '%s' "${repo:-$dir}|${tool}|${mrid}" | sed 's/[^A-Za-z0-9]/_/g')
  cache="${TMPDIR:-/tmp}/acg-mrdest-${key}"
  # H1: el caché regular SOLO se sirve si es confiable (uid+perm+TTL, ver acg__cache_confiable arriba). Si
  # existe pero NO es confiable (plantado, o simplemente viejo — p. ej. un MR re-apuntado develop→main), se
  # trata EXACTO como un cache-miss: cae al lookup por API de abajo, que lo REESCRIBE con la respuesta fresca.
  if [ -f "$cache" ] && acg__cache_confiable "$cache"; then cat "$cache"; return 0; fi
  # CACHE-DE-CREACION (§4.3, "el hallazgo que desatora todo"): si un `pr create --base X`/`mr create
  # --target-branch X` de ESTE MR quedó cacheado por (repo,tool,mrid) — lo escribe otro proceso al crear el
  # MR, cuando el id YA es conocido — se consume SIN red.
  # H3 (auditoría semántica 2026-09-16, MEDIO, CONFIRMADO): hoy NO existe el escritor legítimo (pendiente ya
  # declarado en la bitácora) — la propia premisa del fix MEDIO ("cualquier archivo aquí es NO-genuino") vale
  # para CUALQUIER uid, incluido el propio: el chequeo de uid+perm(+TTL) protege del VECINO, no del actor que
  # este guard vigila (un agente del propio usuario, a punto de correr el merge, puede escribir un 0600
  # propio). Canal ENTERO apagado por default (ACG_CACHE_CREACION=1 para encenderlo) hasta que exista el
  # escritor real con su atadura (session_id/HMAC) — cuesta una línea, cierra el hueco completo. El chequeo
  # uid+perm+TTL se conserva como defensa en profundidad para cuando se encienda.
  cache_c="${TMPDIR:-/tmp}/acg-mrdest-creacion-${key}"
  if [ "${ACG_CACHE_CREACION:-0}" = "1" ] && [ -f "$cache_c" ] && acg__cache_confiable "$cache_c"; then
    dest=$(cat "$cache_c" 2>/dev/null)
    if [ -n "$dest" ]; then
      printf '%s\nCACHE-DE-CREACION\n' "$dest" > "$cache" 2>/dev/null; chmod 600 "$cache" 2>/dev/null
      cat "$cache"; return 0
    fi
  fi
  command -v "$tool" >/dev/null 2>&1 || { printf '\nDESCONOCIDO:SIN-RED\n'; return 0; }
  if [ "$tool" = glab ]; then
    out=$(acg__run_en_dir "$dir" "$ACG_MR_TIMEOUT" glab api "projects/:id/merge_requests/$mrid" ${repo:+-R "$repo"} 2>/dev/null | jq -r '.target_branch // empty' 2>/dev/null)
  else
    out=$(acg__run_en_dir "$dir" "$ACG_MR_TIMEOUT" gh pr view "$mrid" ${repo:+-R "$repo"} --json baseRefName -q .baseRefName 2>/dev/null)
  fi
  if [ -n "$out" ]; then
    # H1: perm 600 en la ESCRITURA -- si no, el `>` normal (644 con umask 022 típico) haría que la PROPIA
    # relectura de este caché fallara acg__cache_confiable (permisos de grupo/otros) y anulara el caché entero.
    printf '%s\nAPI\n' "$out" > "$cache" 2>/dev/null; chmod 600 "$cache" 2>/dev/null
    cat "$cache"; return 0
  fi
  printf '\nDESCONOCIDO:TIMEOUT\n'
  return 0
}

# Devuelve el destino por stdout (vacío si no se pudo resolver → el consumidor aplica SU fail-policy:
# confirmar trata vacío como develop = pide OK; squash trata !develop = no fuerza, para no aplastar un
# release por no resolver). Requiere jq (sin jq devuelve vacío). RETRO-COMPAT: mismo contrato de SIEMPRE
# (1 línea, sin newline final) — es un wrapper de acg__destino_de_mr_full que descarta la CONF.
acg_destino_de_mr() { acg__destino_de_mr_full "$1" "${2:-}" | sed -n '1p'; }

# M3: la CONFIANZA con que se resolvió el ÚLTIMO acg_destino_de_mr del MISMO (cmd,pcwd) — EXPLICITO | API |
# CACHE-DE-CREACION | DESCONOCIDO:<motivo>. Comparte caché con acg_destino_de_mr (cache-hit, sin 2ª llamada
# de red). El consumidor la usa para decidir POLÍTICA (M4), no solo el valor del destino.
acg_destino_conf() { acg__destino_de_mr_full "$1" "${2:-}" | sed -n '2p'; }

# ── VALIDACIÓN DE LA CALIDAD DEL MENSAJE DE SQUASH (merge-squash-guard) ──────────────────────────────────
# El squash-guard fuerza `--squash`, pero un squash con mensaje POBRE (título default de la plataforma
# "Merge pull request #N", vacío o placeholder de una palabra) igual pierde el RESUMEN CURADO que exige
# cerrar-slice. Estos helpers razonan sobre la FUENTE y la SUSTANCIA del mensaje. Pieza PURA/DETERMINISTA
# (testeable sin red) salvo acg_mensaje_de_mr (API, mismo patrón que acg_destino_de_mr). bash-3.2-safe.

# ¿De dónde sale el SUBJECT del squash? El mensaje puede venir EXPLÍCITO en el comando (verificable directo)
# o AUTO-generarse server-side del título del MR/PR (verificable vía API). Clasifica en:
#   LITERAL       — hay un flag de subject con un valor LITERAL en el comando (glab: --squash-message ·
#                   gh: --subject/-t) → se valida directo (acg_msg_valor).
#   UNVERIFICABLE — el valor del flag es una sustitución/variable ($(...)/`...`/${...}/$VAR) o el comando usa
#                   gh --fill*/--body-file (subject derivado de commits/archivo) → NO verificable en
#                   PreToolUse → el consumidor PASA (no forzamos, fail-open).
#   AUTO          — no hay flag de subject → el squash tomará el TÍTULO del MR/PR → validable vía API.
acg_msg_clasificar() {   # $1=cmd(RAW) → LITERAL | UNVERIFICABLE | AUTO
  local raw="$1" u tool val
  u=$(acg_sin_flag_repo "$(acg_despoja_comillas "$raw")")
  if printf '%s' "$u" | grep -qE 'glab(\.exe)?[[:space:]]+mr'; then tool=glab; else tool=gh; fi
  # gh --fill*/--body-file → subject/cuerpo derivado de commits o de un ARCHIVO → no verificable aquí.
  if [ "$tool" = gh ] && printf '%s' "$u" | grep -qE '(^|[[:space:]])(--fill(-first|-verbose)?|--body-file|-F)([[:space:]]|=|$)'; then
    printf 'UNVERIFICABLE'; return 0
  fi
  if [ "$tool" = glab ]; then
    printf '%s' "$u" | grep -qE '(^|[[:space:]])--squash-message([[:space:]]|=)' || { printf 'AUTO'; return 0; }
  else
    printf '%s' "$u" | grep -qE '(^|[[:space:]])(--subject|-t)([[:space:]]|=)' || { printf 'AUTO'; return 0; }
  fi
  val=$(acg_msg_valor "$raw")
  case "$val" in *'$('*|*'`'*|*'${'*|'$'*) printf 'UNVERIFICABLE'; return 0 ;; esac
  printf 'LITERAL'; return 0
}

# Extrae el VALOR LITERAL del flag de subject del comando (quote-aware; comillas de envoltura removidas).
# Opera sobre el RAW (comillas INTACTAS) para leer un valor entrecomillado con espacios. glab: --squash-message
# · gh: --subject/-t. Devuelve vacío si no hay flag.
acg_msg_valor() {   # $1=cmd(RAW) → valor literal | vacío
  local raw tool v
  # SLURP MULTILÍNEA (fix #42/#46, corpus 2026-08-19/24): un `--squash-message "resumen\ncurado\ninline"`
  # con SALTOS DE LÍNEA reales rompía el sed line-based — al ver solo la 1ª línea, el `"[^\"]*"` no hallaba la
  # comilla de cierre y caía al bareword → truncaba el valor al 1er token → FP "superficial"/"pobre" que
  # exigía la forma `$(cat archivo)`. Se colapsan los newlines a \001 (SOH, jamás en un mensaje real) para que
  # sed vea UNA línea y case el valor entrecomillado COMPLETO; los \n se restauran al final. Un inline
  # multilínea con SUSTANCIA pasa igual que uno de una línea.
  raw=$(printf '%s' "$1" | tr '\n' '\001')
  if printf '%s' "$(acg_despoja_comillas "$raw")" | grep -qE 'glab(\.exe)?[[:space:]]+mr'; then tool=glab; else tool=gh; fi
  if [ "$tool" = glab ]; then
    v=$(printf '%s' "$raw" | sed -nE "s/.*(^|[[:space:]])--squash-message([[:space:]]+|=)(\"[^\"]*\"|'[^']*'|([^[:space:]\"'])+).*/\3/p" | head -1)
  else
    v=$(printf '%s' "$raw" | sed -nE "s/.*(^|[[:space:]])(--subject|-t)([[:space:]]+|=)(\"[^\"]*\"|'[^']*'|([^[:space:]\"'])+).*/\4/p" | head -1)
  fi
  printf '%s' "$v" | sed -E "s/^[\"']//; s/[\"']\$//" | tr '\001' '\n'
}

# ¿el mensaje/subject de un squash es POBRE (sin sustancia) → hay que BLOQUEAR? Mide el SUBJECT (1ª línea).
# POBRE (return 0 = "sí, bloquéalo") si:
#   (a) el mensaje NO tiene NINGÚN carácter alfanumérico (vacío / solo espacios / solo puntuación);
#   (b) el subject es un DEFAULT de plataforma: "Merge pull request …" (el caso NOMBRADO), "Merge branch …",
#       "Merge remote-tracking branch …", "Merge request …", o "Merge #N"/"Merge !N";
#   (c) el subject es UN SOLO TOKEN y mide < 12 caracteres no-espacio (placeholder: "wip"/"fix"/"update"/
#       "hotfix"/"#5"). Un subject de ≥2 palabras NUNCA cae por (c) — solo (a)/(b).
# En cualquier otro caso NO es pobre (return 1) → PASA. Umbrales DEFENDIBLES y de BAJO FP: (b) es near-zero
# FP (nadie escribe eso como su resumen curado); (c) apunta SOLO a placeholders de una palabra (un resumen
# real "el cambio neto y su porqué" es multi-palabra). Es un PISO anti-basura, NO una vara de calidad
# (auditor=piso-no-meta): que el mensaje pase NO significa que sea bueno, solo que no es basura evidente.
acg_msg_es_pobre() {   # $1=mensaje → 0=pobre(bloquear) · 1=ok(pasar)
  local msg="$1" subject alnum words nonspace
  subject=$(printf '%s\n' "$msg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -m1 -v '^$')
  alnum=$(printf '%s' "$msg" | tr -cd '[:alnum:]' | wc -c | tr -d '[:space:]')
  [ "${alnum:-0}" -eq 0 ] && return 0                                                                   # (a)
  printf '%s' "$subject" | grep -qiE '^merge (pull request|branch|remote-tracking branch|request)([[:space:]]|$)' && return 0   # (b)
  printf '%s' "$subject" | grep -qiE '^merge [!#]?[0-9]+([[:space:]]|$)' && return 0                     # (b')
  words=$(printf '%s' "$subject" | wc -w | tr -d '[:space:]')
  nonspace=$(printf '%s' "$subject" | tr -d '[:space:]' | wc -c | tr -d '[:space:]')
  [ "${words:-0}" -le 1 ] && [ "${nonspace:-0}" -lt 12 ] && return 0                                    # (c)
  return 1
}

# ── VARA DE PROFUNDIDAD/TRAZABILIDAD/ANTI-EDITORIALIZACIÓN (solo el consumidor decide a qué FUENTE aplicar) ──
# acg_msg_es_pobre es el PISO anti-basura (aplica a LITERAL y AUTO). Las funciones de ABAJO son la VARA
# más alta que merge-squash-guard aplica SOLO al mensaje LITERAL (el que el agente TIPEÓ inline): un título
# AUTO del MR es corto por naturaleza y no lo redactó el agente aquí → no se le exige rama ni ≥12 palabras.
# El caso `--squash-message "$(cat resumen.md)"` es UNVERIFICABLE aguas arriba → nunca llega a estas varas
# (fail-open ya documentado): por eso endurecen SOLO el literal inline, que es el camino desaconsejado.

# (3a) ¿el resumen LITERAL es DEMASIADO SUPERFICIAL para describir un slice? Piso de PROFUNDIDAD: < 12
# PALABRAS (un resumen del "cambio neto y su porqué" es multi-cláusula; un placeholder de 3-4 palabras no
# lo es). Mide el mensaje COMPLETO (no solo el subject). return 0 = superficial (bloquear).
acg_msg_es_superficial() {   # $1=mensaje → 0=superficial(bloquear) · 1=ok
  local words
  words=$(printf '%s' "$1" | wc -w | tr -d '[:space:]')
  [ "${words:-0}" -lt 12 ]
}

# (2a) ¿al resumen LITERAL le falta TODO rastro de TRAZABILIDAD rama→commit? El squash BORRA el merge-commit
# de la plataforma (que traía el #id del MR/PR) → sin un rastro en el propio mensaje, `git log develop` no
# dice de qué ramita salió el commit. "Rastro" = un patrón de RAMA (feat/ fix/ chore/ hotfix/ docs/ seguido
# del nombre) O un id de MR/PR (!123 / #456). return 0 = falta traza (bloquear).
#   Precisión: solo se INVOCA sobre el LITERAL (el agente lo tipeó, puede añadir la línea `Rama:`/`MR:`); el
#   patrón de rama exige la barra + ≥1 char de nombre (no casa un "fix" suelto), y el id exige [!#]+dígitos.
# H8 (auditoría semántica 2026-09-16, BAJO, CONFIRMADO): el set de prefijos era demasiado angosto —
# "Rama: refactor/sustrato - …"/"test/…"/"perf/…"/"ci/…" SÍ traen la rama (trazabilidad real) pero el
# mensaje decía "falta TRAZABILIDAD" sobre un resumen que la tenía. Ampliado a los prefijos de
# conventional-commit de uso real en este repo (esta misma rama trae commits `test(brain):`).
acg_msg_falta_traza() {   # $1=mensaje → 0=falta traza(bloquear) · 1=trae traza(pasar)
  printf '%s' "$1" | grep -qE '(^|[^A-Za-z0-9/])(feat|fix|chore|hotfix|docs|refactor|test|perf|ci|build|style|audit|revert)/[A-Za-z0-9._-]' && return 1
  printf '%s' "$1" | grep -qE '[!#][0-9]+' && return 1
  return 0
}

# (3b-DENY) ¿el mensaje EDITORIALIZA con marcadores INEQUÍVOCOS de proceso / memoria interna del asistente?
# Estos hablan de CÓMO se llegó al código (deliberación, análisis, la sesión), no de QUÉ hace el código.
# CRITERIO deny (near-zero FP): patrones que SOLO aparecen narrando el PROCESO — nadie los usa en un resumen
# curado del cambio neto. Los AMBIGUOS ("se cambió/actualizó/corrigió" — pueden ser prosa legítima) NO van
# aquí: se ADVIERTEN aparte (acg_msg_narra_acciones), no se bloquean. Stems ASCII (sin clases multibyte,
# robusto BSD/GNU/locale): `decidi` casa "decidió"/"decidio"; `identific` "identificó"; `procedi` "procedió".
acg_msg_editorializa() {   # $1=mensaje → 0=editorializa(bloquear) · 1=limpio
  printf '%s' "$1" | grep -qiE 'tras[[:space:]]+analiz|se[[:space:]]+decidi|se[[:space:]]+identific|el[[:space:]]+asistente|en[[:space:]]+esta[[:space:]]+sesi|se[[:space:]]+procedi'
}

# (3a-ii/3b-WARN) ¿el mensaje NARRA una LISTA DE ACCIONES (pasado pasivo "se <verbo>") en vez del cambio
# neto y su porqué? Señal: ≥2 cláusulas "se <verbo-de-acción>" (se cambió, se actualizó, se corrigió, se
# agregó…). Es AMBIGUO — UNA sola cláusula así puede ser prosa legítima → NO se bloquea; ≥2 sugiere el
# pegote de commits que el squash debía RESUMIR. El consumidor lo ADVIERTE (additionalContext), NUNCA deny:
# precisión > agresividad. Stems ASCII + `-i`; grep -o cuenta cada ocurrencia.
acg_msg_narra_acciones() {   # $1=mensaje → 0=parece lista de acciones(advertir) · 1=no
  local n
  n=$(printf '%s\n' "$1" | grep -oiE 'se[[:space:]]+(cambi|actualiz|corrig|agreg|elimin|modific|refactoriz|reemplaz|implement|ajust|arregl|borr|cre|mov|quit)[a-z]*' | grep -c . )
  [ "${n:-0}" -ge 2 ]
}

# Resuelve el SUBJECT que el squash AUTO-generará server-side (caso AUTO): GitLab usa el TÍTULO del MR como
# mensaje del squash; GitHub usa el TÍTULO del PR como subject. Mismo patrón que acg_destino_de_mr
# (repo/tool/mrid por precedencia + timeout + caché por MR-id, con clave PROPIA "|msg" distinta a la de
# destino). Devuelve el título por stdout (vacío si no se pudo resolver → el consumidor FAIL-OPEN: sin
# título CONFIRMADO no bloquea). Requiere jq (sin jq devuelve vacío).
acg_mensaje_de_mr() {   # $1=comando  $2=payload_cwd(opcional) → título del MR/PR | vacío
  command -v jq >/dev/null 2>&1 || return 0
  local raw="$1" pcwd="${2:-}" u tool repo mrid key cache titulo dir
  u=$(acg_despoja_comillas "$raw")
  if printf '%s' "$u" | grep -qE 'glab(\.exe)?[[:space:]]+mr'; then tool=glab; else tool=gh; fi
  repo=$(acg_target_remote "$raw" "$pcwd")
  dir=$(acg_target_dir "$raw" "$pcwd")   # mismo criterio que acg_destino_de_mr: consultar EN el dir objetivo
  mrid=$(acg_mrid "$u")
  [ -n "$mrid" ] || return 0
  key=$(printf '%s' "${repo:-$dir}|${tool}|${mrid}|msg" | sed 's/[^A-Za-z0-9]/_/g')
  cache="${TMPDIR:-/tmp}/acg-mrmsg-${key}"
  # H1 (auditoría de ejecución 2026-09-16, ALTO): mismo patrón sin-validar que el de destino -- misma
  # defensa (uid+perm+TTL, acg__cache_confiable).
  if [ -f "$cache" ] && acg__cache_confiable "$cache"; then cat "$cache"; return 0; fi
  if [ "$tool" = glab ]; then
    titulo=$(acg__run_en_dir "$dir" "$ACG_MR_TIMEOUT" glab api "projects/:id/merge_requests/$mrid" ${repo:+-R "$repo"} 2>/dev/null | jq -r '.title // empty' 2>/dev/null)
  else
    titulo=$(acg__run_en_dir "$dir" "$ACG_MR_TIMEOUT" gh pr view "$mrid" ${repo:+-R "$repo"} --json title -q .title 2>/dev/null)
  fi
  if [ -n "$titulo" ]; then
    printf '%s' "$titulo" > "$cache" 2>/dev/null; chmod 600 "$cache" 2>/dev/null
    printf '%s' "$titulo"
  fi
  return 0
}

# Lista de MR/PR ABIERTOS del repo, DIGERIBLE a un HINT de candidatos para el juez de merge (capa 3
# "contexto de identificación"). UNA sola consulta (`glab mr list` / `gh pr list` según el remoto),
# acotada por timeout y CACHEADA por repo en TMPDIR (clave distinta a la de acg_destino_de_mr). Sirve
# para IDENTIFICAR el target de una referencia vaga ("el release", "de todo esto") cuando hay UN solo
# candidato — NUNCA como autorización (eso lo decide el juez leyendo líneas USUARIO:). Fail-safe: sin
# jq/binario/red/timeout → imprime vacío → el consumidor degrada a "como hoy" (destino por acg + charla).
# Devuelve un JSON array normalizado [{number,title,baseRefName,headRefName,isDraft}] o vacío.
acg_lista_prs_abiertos() {   # $1=comando (para derivar repo/herramienta)  $2=payload_cwd(opcional) → JSON array | vacío
  command -v jq >/dev/null 2>&1 || return 0
  local raw="$1" pcwd="${2:-}" u tool repo key cache out dir
  u=$(acg_despoja_comillas "$raw")
  if printf '%s' "$u" | grep -qE 'glab(\.exe)?[[:space:]]+mr'; then tool=glab; else tool=gh; fi
  repo=$(acg_target_remote "$raw" "$pcwd")   # --repo/-R > remoto del dir objetivo (no siempre PROJECT_DIR)
  dir=$(acg_target_dir "$raw" "$pcwd")       # mismo criterio: la lista se pide EN el dir objetivo
  key=$(printf '%s' "${repo:-$dir}|${tool}|prlist" | sed 's/[^A-Za-z0-9]/_/g')
  cache="${TMPDIR:-/tmp}/acg-prlist-${key}"
  # H1 (auditoría de ejecución 2026-09-16, ALTO): mismo patrón sin-validar que el de destino -- misma
  # defensa (uid+perm+TTL, acg__cache_confiable). Esta lista es solo HINT factual (nunca autorización), pero
  # comparte el defecto de fondo del canal.
  if [ -f "$cache" ] && acg__cache_confiable "$cache"; then cat "$cache"; return 0; fi
  if [ "$tool" = glab ]; then
    # glab mr list --output json → array con iid/title/target_branch/source_branch/draft. Normalizo al
    # mismo shape que gh (number,title,baseRefName,headRefName,isDraft) para un solo digestor aguas abajo.
    out=$(acg__run_en_dir "$dir" "$ACG_MR_TIMEOUT" glab mr list ${repo:+-R "$repo"} --output json 2>/dev/null \
          | jq -c '[.[] | {number:(.iid // .number), title:(.title // ""), baseRefName:(.target_branch // ""), headRefName:(.source_branch // ""), isDraft:((.draft // .work_in_progress) // false)}]' 2>/dev/null)
  else
    out=$(acg__run_en_dir "$dir" "$ACG_MR_TIMEOUT" gh pr list ${repo:+-R "$repo"} --state open --limit 50 --json number,title,baseRefName,headRefName,isDraft 2>/dev/null)
  fi
  # Solo cachea un ARRAY no vacío válido (un fallo/timeout → vacío → se reintenta la próxima).
  if [ -n "$out" ] && printf '%s' "$out" | jq -e 'type=="array" and length>0' >/dev/null 2>&1; then
    printf '%s' "$out" > "$cache" 2>/dev/null; chmod 600 "$cache" 2>/dev/null
    printf '%s' "$out"
  fi
  return 0
}

# Digiere el array de acg_lista_prs_abiertos a un BLOQUE de texto plano (HECHOS, no autorización) que
# ayuda al juez a IDENTIFICAR a qué MR se refiere una autorización vaga del USUARIO. Determinista y
# testeable con un array mock (sin red). El conteo "hacia esta base hay exactamente 1" es un HECHO
# computado aquí, no algo que el LLM deba adivinar. Variantes: 1 candidato (INEQUÍVOCO) · ≥2 (exige que
# el USUARIO nombre) · mrid ausente (¿ya mergeado?) · lista no disponible (resuelve solo con la charla).
acg_hint_candidatos() {   # $1=json array(o vacío) $2=destino $3=mrid → bloque de texto | vacío
  command -v jq >/dev/null 2>&1 || return 0
  local arr="$1" destino="$2" mrid="$3" base cnt cands title head b mrline
  local head_ln="--- CONTEXTO FACTUAL DE GIT (no es autorización, solo para IDENTIFICAR el MR) ---"
  local foot_ln="--- fin contexto ---"
  if [ -z "$arr" ] || ! printf '%s' "$arr" | jq -e 'type=="array"' >/dev/null 2>&1; then
    printf '%s\nLista de MRs abiertos: NO DISPONIBLE. Resuelve el referente SOLO con la conversación; ante duda, DENY.\n%s' "$head_ln" "$foot_ln"
    return 0
  fi
  # metadatos del MR juzgado (si figura entre los abiertos)
  title=$(printf '%s' "$arr" | jq -r --arg id "$mrid" 'map(select((.number|tostring)==$id))[0].title // empty' 2>/dev/null | cut -c1-80)
  head=$(printf '%s' "$arr"  | jq -r --arg id "$mrid" 'map(select((.number|tostring)==$id))[0].headRefName // empty' 2>/dev/null)
  b=$(printf '%s' "$arr"     | jq -r --arg id "$mrid" 'map(select((.number|tostring)==$id))[0].baseRefName // empty' 2>/dev/null)
  # base a considerar: el destino resuelto, o (si vacío) el baseRefName del propio MR según la lista
  base="$destino"; [ -z "$base" ] && base="$b"
  if [ -n "$title" ]; then
    mrline="MR juzgado: #$mrid · titulo: \"$title\" · rama: ${head:-?} -> ${b:-?}"
  else
    mrline="MR juzgado: #$mrid · NO figura entre los MRs abiertos (¿ya mergeado/cerrado, o id equivocado?) — no asumas nada sobre el; resuelve solo con la conversacion."
  fi
  if [ -n "$base" ]; then
    cnt=$(printf '%s' "$arr" | jq --arg bs "$base" '[.[]|select(.baseRefName==$bs)]|length' 2>/dev/null)
    cands=$(printf '%s' "$arr" | jq -r --arg bs "$base" '[.[]|select(.baseRefName==$bs)|"#\(.number)"]|join(", ")' 2>/dev/null)
    if [ "${cnt:-0}" = 1 ]; then
      printf '%s\n%s\nMRs abiertos hacia %s ahora mismo: 1 (SOLO %s) => una referencia vaga del USUARIO ("el release","esto","todo esto","de todo esto") hacia esa base es INEQUIVOCA: es %s. (Sigue exigiendo que sea el USUARIO quien autorice; el conteo solo identifica, no autoriza.)\n%s' \
        "$head_ln" "$mrline" "$base" "$cands" "$cands" "$foot_ln"
    elif [ "${cnt:-0}" -ge 2 ] 2>/dev/null; then
      printf '%s\n%s\nMRs abiertos hacia %s ahora mismo: %s (%s) => hay VARIOS candidatos: un OK VAGO del USUARIO NO basta, debe nombrar cual (si no, DENY).\n%s' \
        "$head_ln" "$mrline" "$base" "$cnt" "$cands" "$foot_ln"
    else
      printf '%s\n%s\nMRs abiertos hacia %s ahora mismo: 0 (ninguno figura). No asumas un candidato; resuelve solo con la conversacion.\n%s' \
        "$head_ln" "$mrline" "$base" "$foot_ln"
    fi
  else
    printf '%s\n%s\nNo se pudo determinar la base del MR. Resuelve el referente con la conversacion; ante duda, DENY.\n%s' \
      "$head_ln" "$mrline" "$foot_ln"
  fi
}

# ── M4 (auditoría 2026-09-15 §2.3/§3.4): UNA sola fuente para "¿hay lenguaje de release / qué dijo el
# usuario recientemente?" — antes vivía SOLO dentro de confirmar-merge-develop.sh, así que merge-squash-guard
# (el otro guard que decide sobre el MISMO destino desconocido) no tenía forma de ver la MISMA señal y
# discrepaba: con un destino IRRESOLUBLE, confirmar-merge-develop podía reconocer un release legítimo por la
# CONVERSACIÓN mientras merge-squash-guard, ciego a ella, forzaba squash sobre ESE MISMO release (§3.4,
# "dos guards, el MISMO comando, la MISMA incógnita, CONCLUSIONES OPUESTAS"). Moverlas aquí no cambia su
# comportamiento (son wrappers 1:1 en el consumidor original) — solo las vuelve CONSULTABLES por cualquier
# guard de la familia, para que la incertidumbre se resuelva con la MISMA información en todos lados.

# acg_recent_intercalado($tpath) → arma la CONVERSACIÓN reciente intercalada (USUARIO:/ASISTENTE:), del más
# viejo al más nuevo. Ancla en el 10º mensaje de USUARIO desde el final + 4 turnos de arranque (contexto del
# asistente); filtra meta/system-reminder/tool-result puro; surfacea AskUserQuestion (.toolUseResult.answers/
# .annotations) y el mensaje MID-TURN absorbido (queue-operation reason=absorbed_mid_turn →
# {"type":"attachment","attachment":{"type":"queued_command","origin":{"kind":"human"}}}) como turno USUARIO
# — con AUTORIDAD estricta (origin.kind=="human" exacto; cualquier otro valor/ausente NO se surfacea).
acg_recent_intercalado() {  # $1=ruta del transcript .jsonl → imprime la conversación intercalada, o vacío
  [ -n "${1:-}" ] && [ -f "$1" ] || return 0
  tail -n 6000 "$1" 2>/dev/null | jq -rs '
    [ .[]
      | select((.isMeta // false) != true)                # descarta META/inyectados (no son del usuario)
      | ( if (.type == "attachment")
             and ((.attachment.type? // "") == "queued_command")
             and ((.attachment.origin.kind? // "") == "human")
          then (.attachment.prompt? // "") else "" end ) as $qc
      | { role: (if $qc != "" then "user" else (.message.role // .type) end),
          text: ( if $qc != "" then $qc else
                  ( (try ([ .toolUseResult.answers[]
                          | select(type=="string" and . != "" and . != "(no option selected)" and . != "(notes only)") ]
                       + [ .toolUseResult.annotations[]?.notes | select(type=="string" and . != "") ]
                       | join(" · ")) catch "") as $aq
                | if $aq != "" then $aq
                  else ((.message.content // [.message])
                        | if type=="array"
                          then (map(if type=="string" then . elif (.type? == "text") then .text else "" end) | join(" "))
                          else (. // "") end)
                  end ) end ) }
      | select(.role=="user" or .role=="assistant")       # solo turnos de conversación (no tool-result puro)
      | select(.text != "")
      | select(.text | test("<system-reminder>") | not)   # descarta bloques con marca de inyección (CLAUDE.md/recordatorios)
      | { role, text: (.text | gsub("\\s+";" ")) } ] as $t
    | ([ range(0; ($t|length)) | select($t[.].role=="user") ]) as $u
    | (if ($u|length) >= 10 then $u[-10] else ($u[0] // 0) end) as $a
    | (if $a >= 4 then $a-4 else 0 end) as $s
    | $t[$s:]
    | map( if .role=="user" then "USUARIO: " + .text
           else "ASISTENTE: " + (.text[0:700]) end )
    | join("\n")' 2>/dev/null   # conversación intercalada, del más viejo al más nuevo, marcada por rol
}

# ¿Hay lenguaje EXPLÍCITO de release (release/libera/a main/a master) en ALGUNA línea 'USUARIO:' de la
# ventana? Tokens ANCLADOS a límite de palabra (portable BSD+GNU): 'liber' no casa en "deliberada"/
# "libertad", 'a main' no casa en "a maintenance". Fuente ÚNICA para el PISO de main de confirmar-merge-
# develop Y (M4) para el fail-safe de destino-irresoluble de merge-squash-guard — misma pregunta, misma
# respuesta, en vez de que cada guard la conteste con su propia heurística.
acg_lexico_release() {   # $1=mensajes(intercalados USUARIO:/ASISTENTE:) → 0=SÍ hay release · 1=no
  printf '%s\n' "$1" | grep -iE '^[[:space:]]*USUARIO:' | grep -iqE '(^|[^[:alpha:]])(release|(liberar?|liberado|liberaci[oó]n|liber[eé]n?|liber[oó])([^[:alpha:]]|$)|(a|hacia) (main|master)([^[:alpha:]]|$))'
}

# H4 (auditoría de ejecución 2026-09-16, MEDIO, CONFIRMADO): acg_lexico_release mira TODA la ventana, sin
# anclarla al MR de ESTE comando — un "libera a main el PR 390" (OTRO MR) le prestaba su señal al merge del
# PR 391, desactivando la exigencia de --squash de un merge a develop genuino. Ancla la señal a $2 (el mrid
# de ESTE comando, si lo hay): una línea USUARIO con lenguaje de release cuenta SOLO si (a) no nombra NINGÚN
# id de MR/PR (genérico, "libera esto" — sigue aplicando igual que hoy, no se puede anclar lo que no se
# nombra) o (b) nombra justo $2. Si nombra otro id distinto, esa línea NO cuenta. Sin $2 (mrid vacío, p. ej.
# un merge de MR SIN id que integra la rama actual) se comporta EXACTO como acg_lexico_release (no hay a qué
# anclar). No se usa en el piso de main de confirmar-merge-develop (ese ya recibe el mrid vía $2 del propio
# _juez_merge_uno con otra semántica) — es específico del fail-safe de destino-irresoluble de squash-guard.
acg_lexico_release_para_mr() {   # $1=mensajes  $2=mrid(opcional) → 0=SÍ aplica a este MR · 1=no
  local mrid="${2:-}" linea
  [ -z "$mrid" ] && { acg_lexico_release "$1"; return $?; }
  while IFS= read -r linea; do
    printf '%s' "$linea" | grep -iqE '^[[:space:]]*USUARIO:' || continue
    printf '%s' "$linea" | grep -iqE '(^|[^[:alpha:]])(release|(liberar?|liberado|liberaci[oó]n|liber[eé]n?|liber[oó])([^[:alpha:]]|$)|(a|hacia) (main|master)([^[:alpha:]]|$))' || continue
    if printf '%s' "$linea" | grep -qE '#?[0-9]+'; then
      printf '%s' "$linea" | grep -qE "(^|[^0-9])#?${mrid}([^0-9]|\$)" && return 0
    else
      return 0
    fi
  done <<EOF
$(printf '%s\n' "$1")
EOF
  return 1
}

# H2 (auditoría semántica 2026-09-16, ALTO, CONFIRMADO): señal de RIESGO amplia para el piso M5-bis de
# confirmar-merge-develop — a diferencia de acg_lexico_release (que exige la señal en una línea USUARIO real,
# porque SOLO el usuario autoriza), esta mira CUALQUIER rol (USUARIO o ASISTENTE): incluso el propio
# asistente proponiendo un release, o una mención de pasada de 'main'/'master', basta para NO tratar un
# destino DESCONOCIDO como "inequívocamente develop". El piso M5-bis solo se salta cuando esta función NO
# encuentra NINGUNA señal en TODA la ventana — nunca cuando el LLM lo "declara" de sí mismo (el juez es
# probabilístico; esta señal es determinista, verificada en bash, la MISMA doctrina del veto de cita).
acg_lexico_main_amplio() {   # $1=mensajes(CUALQUIER rol) → 0=hay señal de main/release/promover
  printf '%s\n' "$1" | grep -iqE '(^|[^[:alpha:]])(release|liberar?|liberado|liberaci[oó]n|liber[eé]n?|liber[oó]|main|master|promov(er|ida|ido|iendo)?)([^[:alpha:]]|$)'
}

# H2 (auditoría semántica 2026-09-16, ALTO): la MITAD positiva del piso M5-bis. NO basta con "ninguna señal
# de main" (acg_lexico_main_amplio arriba) para saltar el piso — una ventana MUDA que no menciona NI
# main NI develop ("perfecto, mergealo") también pasa esa prueba, y es precisamente el caso peligroso que
# M5 existía para cubrir (destino real podría ser main, la consulta falló, nadie lo dijo). El salto del piso
# exige EVIDENCIA POSITIVA: una línea USUARIO que nombre 'develop' explícitamente como destino — sin eso, el
# silencio NO cuenta como "inequívocamente develop", cuenta como "no sé", y el piso se queda.
acg_lexico_develop_explicito() {   # $1=mensajes → 0=alguna línea USUARIO nombra 'develop' explícitamente
  printf '%s\n' "$1" | grep -iE '^[[:space:]]*USUARIO:' | grep -iqE '(^|[^[:alpha:]])develop([^[:alpha:]]|$)'
}
