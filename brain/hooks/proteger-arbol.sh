#!/usr/bin/env bash
# proteger-arbol.sh — PreToolUse/Bash: AVISA (NO bloquea) antes de un git DESTRUCTIVO que podría
# ORFANAR commits sin pushear en el árbol de trabajo actual (un reset/rebase/checkout -f en el árbol
# COMPARTIDO puede dejar huérfano un commit del orquestador). Solo avisa cuando REALMENTE hay commits
# en riesgo (bajo ruido). Fail-open. Ignora comandos entrecomillados (dato de un grep / mensaje / doc).
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0
# cwd del payload = working dir REAL del comando: se resuelve el target por la MISMA lib compartida
# (acg_target_dir/acg_normaliza_git_prefijo/acg_despoja_comillas), no contra CLAUDE_PROJECT_DIR — así un
# `git -C <otro>`/`cd <otro> && git reset --hard` y `git.exe`/`git -c k=v` no quedan ciegos.
pcwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
# PRE-FILTRO barato (en-proceso): todo lo que este hook vigila (git reset/checkout/rebase/branch -D)
# contiene 'git' → sin 'git' en el comando, no hay nada que vigilar → early-exit ANTES de sourcear la lib
# y de sed/grep en el camino COMÚN. Conservador: un git destructivo SIEMPRE contiene 'git' → jamás se
# salta un caso real.
case "$cmd" in *git*) : ;; *) exit 0 ;; esac

# Sourcear un archivo con error de SINTAXIS mata el proceso ENTERO con exit 1 (y el harness lo trata como
# no-bloqueante) → este hook ni llegaría a su propio fallback heredoc-ciego. `bash -n` es el veredicto de
# sintaxis (solo parsea, no ejecuta; inmune a que la lib termine en un comando ≠0): si pasa, sourcea de
# verdad; si no, DEGRADA a su fallback propio en vez de desaparecer sin avisar. Snippet IDÉNTICO en los 5
# guards, a propósito FUERA de la lib.
_ACGLIB="$(dirname "$0")/analizar-comando-git.sh"
if [ -f "$_ACGLIB" ] && bash -n "$_ACGLIB" >/dev/null 2>&1; then
  # shellcheck source=analizar-comando-git.sh
  . "$_ACGLIB"
else
  [ -f "$_ACGLIB" ] && printf '%s: analizar-comando-git.sh existe pero no cargó (error de sintaxis) -- usando el fallback heredoc-ciego propio. `bash -n "%s"` localiza el error.\n' "$(basename "$0")" "$_ACGLIB" >&2
fi

# El cuerpo de un heredoc se conserva SOLO si el `<<` alimenta un intérprete (bash/sh/zsh/…) —ahí un
# `git reset --hard` REAL vive adentro— y se descarta si alimenta un escritor (cat/tee/…, dato/doc). Usa
# la MISMA segmentación ejecutor-aware de la lib (acg_segmentos_ejecutables/acg_despoja_comillas), que
# resuelve las dos direcciones con un solo criterio. Sin lib (clon roto) cae al filtro heredoc-ciego de
# siempre (fail-safe: a lo más re-abre el FN viejo, nunca pierde un caso por sobre-quitar).
if command -v acg_despoja_comillas >/dev/null 2>&1; then
  # ORDEN: normaliza el RAW (comillas intactas, para no cegar un `-C "/ruta"`) → LUEGO despoja/heredoc.
  unquoted=$(acg_despoja_comillas "$(acg_normaliza_git_prefijo "$cmd")")
else
  noheredoc=$(printf '%s' "$cmd" | awk -v sq="'" -v dq='"' '
    BEGIN{ inhd=0 }
    inhd==1 { s=$0; sub(/^[ \t]*/,"",s); if (s==delim) inhd=0; next }
    {
      re="<<-?[ \t]*[" sq dq "]?[A-Za-z_][A-Za-z0-9_]*[" sq dq "]?"
      if (match($0, re)) {
        d=substr($0, RSTART, RLENGTH); sub(/^<<-?[ \t]*/,"",d); gsub("[" sq dq "]","",d)
        delim=d; inhd=1
      }
      print
    }')
  unquoted=$(printf '%s' "$noheredoc" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g")
fi
# ¿git DESTRUCTIVO que mueve HEAD / descarta commits?
# `_bdel_re` reconoce un `git branch` de BORRADO en TODAS sus formas: short cluster con d/D en cualquier
# posición (`-D`·`-d`·`-df`·`-fd`·`-Df`·`-Dq`…) o el largo `--delete` (con/ sin `--force`). ANCLADO a que el
# flag vaya JUSTO tras `branch ` (no un `-d` incrustado en otro flag largo tipo `--edit-description`) → lo que
# admite el pre-filtro es EXACTAMENTE lo que el bloque de branch-delete abajo maneja-y-sale, sin caer al path
# de orfandad (que avisaría en falso por los commits sin pushear de HEAD, ajenos a la rama borrada).
_bdel_re='branch[[:space:]]+(-[A-Za-z]*[dD]|--delete)'
printf '%s' "$unquoted" | grep -qE "git[[:space:]]+(reset[[:space:]]+(--hard|--merge|--keep)|checkout[[:space:]]+(-f|--force)|rebase([[:space:]]|\$)|$_bdel_re)" || exit 0

# M2: DIR objetivo por la lib (-C > cd/pushd > cwd del payload > CLAUDE_PROJECT_DIR > '.'); antes las DOS
# resoluciones de abajo iban siempre contra CLAUDE_PROJECT_DIR (el repo de la SESIÓN), ciego a un
# `git -C <otro>`/`cd <otro> && …` — este hook avisaba (o callaba) sobre el árbol EQUIVOCADO.
if command -v acg_target_dir >/dev/null 2>&1; then
  TDIR=$(acg_target_dir "$cmd" "$pcwd")
else
  TDIR="${pcwd:-${CLAUDE_PROJECT_DIR:-.}}"
fi

# --- PRECISIÓN: `git branch -d/-D <ramas>` (patrón DOMINANTE del corpus de FP, 10+ casos) --------------
# `git branch -D <rama>` borra LA RAMA NOMBRADA, no HEAD → su único riesgo son los commits PROPIOS de esa
# rama no integrados a la base; NO los commits sin pushear de la rama ACTUAL. El guard, abajo, cuenta
# `@{u}..HEAD` (ajeno a la rama borrada) → avisaba en falso en TODA limpieza de ramas ya integradas por
# SQUASH/cherry-pick estando en una mini-develop con trabajo local. Aquí decidimos el riesgo REAL con
# ramas-zombie.sh (misma "mergeada" TRIPLE que los barredores limpiar.sh ramas/worktrees: ancestro de la base
# | equivalencia de parche squash/cherry | remota-gone sin commits únicos) → sin divergencia. Solo aplica
# si el comando es SOLO branch -d/-D/-df/--delete… (sin reset/checkout/rebase, que sí mueven HEAD → peligro
# real abajo). El gate usa el MISMO `_bdel_re` que el pre-filtro → toda forma de borrado entra y se maneja aquí.
if printf '%s' "$unquoted" | grep -qE "git[[:space:]]+$_bdel_re" \
   && ! printf '%s' "$unquoted" | grep -qE 'git[[:space:]]+(reset[[:space:]]+--(hard|merge|keep)|checkout[[:space:]]+(-f|--force)|rebase([[:space:]]|$))'; then
  root=$(git -C "$TDIR" rev-parse --show-toplevel 2>/dev/null || true)
  zlib="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/ramas-zombie.sh"
  if [ -n "$root" ] && [ -f "$zlib" ]; then
    # shellcheck source=/dev/null
    . "$zlib"
    base=$(bz_resolver_base "$root")
    # Los nombres de rama = todos los tokens tras `git branch` (hasta pipe/;/&) que NO son flags. Quitar TODO
    # token que empieza con `-` deja los nombres sin importar la FORMA del borrado: `-D`/`-df`/`-fd`/`--delete`/
    # `--delete --force`/`-d --force` (los flags `--force`/`-f` sueltos también caen). Cada token puede ser un
    # nombre exacto o un glob → se expande contra las ramas LOCALES reales con `git branch --list`.
    toks=$(printf '%s' "$unquoted" \
      | grep -oE 'git[[:space:]]+branch[[:space:]]+[^|;&]+' \
      | sed -E 's/^git[[:space:]]+branch[[:space:]]+//' \
      | tr ' ' '\n' | grep -vE '^-')
    # (c) compound `git merge <X> && … && git branch -D <X>`: una rama que ESTE MISMO comando acaba de
    # mergear (a la rama actual) queda integrada en el acto → borrarla es seguro. SOLO cuenta si el merge va
    # encadenado por `&&` (que exige el ÉXITO del merge antes del -D). Con `;`/`||`/`&`/`|` el `-D` correría
    # AUNQUE el merge CHOCARA (el `;`/`&` corren igual; el `||` corre JUSTO si falló) → borraría la rama sin
    # integrar = PÉRDIDA DE DATOS (H7, revisión-4). Por eso el target de merge se captura SOLO si lo sigue un
    # `&&`. (El merge aún no corrió —es PreToolUse—, pero el `&&` SÍ garantiza la condición en tiempo de shell.)
    merged=$(printf '%s' "$unquoted" \
      | grep -oE 'git[[:space:]]+merge([[:space:]]+(--[A-Za-z][A-Za-z-]*|-[A-Za-z]))*[[:space:]]+[^|;&]+&&' \
      | sed -E 's/.*merge([[:space:]]+(--[A-Za-z][A-Za-z-]*|-[A-Za-z]))*[[:space:]]+//; s/[[:space:]]*&&$//' \
      | tr ' ' '\n' | grep -vE '^-')
    riesgo=""
    while IFS= read -r tok; do
      [ -z "$tok" ] && continue
      while IFS= read -r br; do
        [ -z "$br" ] && continue
        if printf '%s\n' "$merged" | grep -qxF "$br"; then
          continue   # (c) mergeada en este mismo comando → segura
        fi
        bz_es_zombie "$root" "$br" "$base" || riesgo="$riesgo $br"
      done < <(git -C "$root" branch --list --format='%(refname:short)' "$tok" 2>/dev/null)
    done <<EOF
$toks
EOF
    # Si ninguna rama nombrada tiene trabajo PROPIO fuera de la base (todas zombies, o el glob no matcheó
    # nada) → borrado seguro → SILENCIO (mata el FP dominante). Si alguna SÍ → aviso ACOTADO a esa rama.
    if [ -n "$riesgo" ]; then
      msg="AVISO (proteger-arbol): este borrado de rama (git branch -d/-D/--delete) eliminaría commits PROPIOS aún NO integrados a '$base' en:$riesgo (no están por ancestro ni por squash/cherry). Si es intencional, adelante; si no, intégralo/pushéalo antes de borrar."
      jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
    fi
    exit 0
  fi
  # sin root o sin la lib → cae al comportamiento previo (fail-safe: no perdemos el aviso histórico).
fi

root=$(git -C "$TDIR" rev-parse --show-toplevel 2>/dev/null || true)
[ -z "$root" ] && exit 0

# ¿Cuántos commits se ORFANARÍAN? (los que HEAD tiene y su upstream no; sin upstream → vs origin/develop|main)
n=0
if git -C "$root" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  n=$(git -C "$root" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
else
  mb=$(git -C "$root" merge-base HEAD origin/develop 2>/dev/null || git -C "$root" merge-base HEAD origin/main 2>/dev/null || true)
  [ -n "$mb" ] && n=$(git -C "$root" rev-list --count "$mb..HEAD" 2>/dev/null || echo 0)
fi
[ "${n:-0}" -gt 0 ] 2>/dev/null || exit 0

# ¿Árbol PRINCIPAL (compartido) o worktree aislado?
gd=$(git -C "$root" rev-parse --git-dir 2>/dev/null)
gcd=$(git -C "$root" rev-parse --git-common-dir 2>/dev/null)

# cur = rama actual; tgt = objetivo del reset/checkout destructivo (vacío = a HEAD, inocuo). Compartidos
# por ambos caminos (worktree aislado y árbol principal).
cur=$(git -C "$root" symbolic-ref --short -q HEAD 2>/dev/null)
tgt=$(printf '%s' "$unquoted" | grep -oE 'git[[:space:]]+(reset[[:space:]]+--(hard|merge|keep)|checkout[[:space:]]+(-f|--force))[[:space:]]+[^[:space:]|;&]+' | awk '{print $NF}' | head -1)

# H14: en un worktree AISLADO el DESASTRE que este hook vigila —orfanar los commits del ORQUESTADOR en
# el árbol COMPARTIDO— es IMPOSIBLE: el aislado solo tiene SU propia rama. Y el workaround del bug de
# harness H15 (el worktree nace en `origin/HEAD` viejo y el agente hace `git reset --hard <su rama
# objetivo>` al arrancar) dispara un aviso SIEMPRE falso: los "orfanados" son el base RANCIO, no trabajo.
# Feedback real (2026-07): 4 agentes de un fan-out lo dispararon, todos legítimos → desincentiva delegar.
if [ "$gd" != "$gcd" ]; then
  # aislado Y (sin objetivo | apunta a su propia rama / su upstream | a una base develop|main) → workaround
  # H15 / rebobinado a la propia rama → aviso falso → SUPRIME.
  if [ -z "$tgt" ] || [ "$tgt" = "$cur" ] || [ "$tgt" = "origin/$cur" ] \
     || printf '%s\n' "$tgt" | grep -qE '^(origin/)?(develop|main)$'; then
    exit 0
  fi
  # aislado pero destructivo hacia OTRO objetivo → nota SUAVE (no la alarma completa): solo tu rama.
  msg="Nota (proteger-arbol): git destructivo en un worktree AISLADO — puede rebobinar $n commit(s) de TU rama, pero el árbol COMPARTIDO del orquestador NO está en riesgo. Si rebobinas a propósito, adelante."
  jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
  exit 0
fi

# L11: SYNC de la BASE local a su remoto (árbol principal). Estar parado EN develop|main y hacer
# `git reset --hard origin/<esa misma base>` ALINEA el espejo local con origin. SOLO se suprime cuando es
# LOSSLESS: el espejo local NO está ADELANTE de origin (`origin/<base>..<base>` == 0 → ff/no-op, nada único
# que orfanar). PÉRDIDA DE DATOS (hueco MEDIO, claudio 2026-10-21): con un commit LOCAL por delante de origin,
# ese reset lo ORFANA y el guard NO puede distinguir un bubble squash de trabajo real → AVISA como siempre.
# ACOTADO: SOLO cuando cur ES la base, el target es su PROPIO origin/<base>, Y no hay nada adelante. Un feature
# con `reset --hard origin/develop` (cur≠develop|main) o un `reset --hard HEAD~3` en develop (tgt≠origin/<cur>)
# siguen avisando.
case "$cur" in
  develop|main)
    if { [ "$tgt" = "origin/$cur" ] || [ "$tgt" = "refs/remotes/origin/$cur" ]; } \
       && [ "$(git -C "$root" rev-list --count "origin/$cur..$cur" 2>/dev/null || echo 1)" = 0 ]; then
      exit 0
    fi ;;
esac

# Árbol PRINCIPAL (compartido): aquí SÍ está el peligro real → aviso completo.
msg="AVISO (proteger-arbol): este git destructivo puede ORFANAR $n commit(s) sin pushear en el árbol PRINCIPAL (compartido). Si eres un AGENTE de fan-out: NO operes el árbol COMPARTIDO — trabaja en tu worktree aislado (isolation: worktree); si necesitas rebobinar, que lo haga el orquestador. Si es intencional (rebobinar a propósito) y ya lo pensaste, ignora este aviso. Lección real (2026-07): un agente reseteó HEAD en el árbol principal y orfanó un commit del orquestador."
jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
exit 0
