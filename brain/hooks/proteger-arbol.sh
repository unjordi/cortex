#!/usr/bin/env bash
# proteger-arbol.sh — PreToolUse/Bash: AVISA (NO bloquea) antes de un git DESTRUCTIVO que podría
# ORFANAR commits sin pushear en el árbol de trabajo actual. Antídoto al un caso REAL (2026-07):
# un agente de fan-out se metió al árbol de trabajo COMPARTIDO y reseteó HEAD, dejando huérfano un
# commit del orquestador (la fuente quedó a medias y el build compiló eso; se recuperó por cherry-pick).
# Solo avisa cuando REALMENTE hay commits en riesgo (bajo ruido). Fail-open. Ignora comandos
# entrecomillados (dato de un grep / mensaje de commit / doc).
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0
# cwd del payload = working dir REAL del comando (M2, auditoría 2026-09-15 §2.4/§3.1): antes este hook NI
# SOURCEABA la lib compartida y resolvía todo contra CLAUDE_PROJECT_DIR (el repo de la SESIÓN) → un
# `git -C <otro>`/`cd <otro> && git reset --hard` quedaba CIEGO, y `git.exe`/`git -c k=v` evadían la
# detección (huecos que la lib ya había cerrado para los otros guards, pero este vivía fuera del candado
# común). Se resuelve por la MISMA lib (acg_target_dir/acg_normaliza_git_prefijo/acg_despoja_comillas).
pcwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
# PRE-FILTRO barato (en-proceso): todo lo que este hook vigila (git reset/checkout/rebase/branch -D)
# contiene 'git' → sin 'git' en el comando, no hay nada que vigilar → early-exit ANTES de sourcear la lib
# y de sed/grep en el camino COMÚN. Conservador: un git destructivo SIEMPRE contiene 'git' → jamás se
# salta un caso real.
case "$cmd" in *git*) : ;; *) exit 0 ;; esac

# CRÍTICO-1 (auditoría FMEA 2026-09-16 §1.1, CONFIRMADO): sourcear un archivo con error de SINTAXIS mata el
# proceso ENTERO con exit 1 -- este hook YA es advisory/fail-open por diseño, pero antes ni siquiera llegaba
# a su propio fallback heredoc-ciego (abajo): el `.` normal mataba el proceso ANTES de que el `command -v
# acg_despoja_comillas` de abajo pudiera preguntar. Se prueba el source en un SUBSHELL primero: si truena
# ahí, el crash queda AISLADO (el proceso padre sigue vivo) y el hook DEGRADA a su fallback propio en vez de
# desaparecer sin avisar. Snippet IDÉNTICO en los 5 guards; a propósito FUERA de la lib.
_ACGLIB="$(dirname "$0")/analizar-comando-git.sh"
if [ -f "$_ACGLIB" ] && ( . "$_ACGLIB" ) >/dev/null 2>&1; then
  # shellcheck source=analizar-comando-git.sh
  . "$_ACGLIB"
else
  [ -f "$_ACGLIB" ] && printf '%s: analizar-comando-git.sh existe pero no cargó (error de sintaxis) -- usando el fallback heredoc-ciego propio. `bash -n "%s"` localiza el error.\n' "$(basename "$0")" "$_ACGLIB" >&2
fi

# M1 (auditoría 2026-09-15 §3.8): el filtro de heredoc PROPIO de este hook (descartaba TODO cuerpo de
# heredoc sin mirar el consumidor) cerró el FP de `cat >> doc.md <<EOF` pero abrió el FN simétrico —
# `bash <<EOF … EOF` con un `git reset --hard` REAL adentro quedaba invisible. Ahora usa la MISMA
# segmentación ejecutor-aware de la lib (acg_segmentos_ejecutables/acg_despoja_comillas): conserva el
# cuerpo SOLO si el `<<` alimenta un intérprete (bash/sh/zsh/…), lo descarta si alimenta un escritor
# (cat/tee/…) — resuelve las DOS direcciones con el mismo criterio, sin tener que elegir un lado. Si la
# lib no está disponible (clon roto), cae al filtro heredoc-ciego de siempre (fail-safe: nunca pierde el
# caso real por sobre-quitar; a lo más re-abre el FN viejo, nunca uno nuevo).
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
printf '%s' "$unquoted" | grep -qE 'git[[:space:]]+(reset[[:space:]]+(--hard|--merge|--keep)|checkout[[:space:]]+(-f|--force)|rebase([[:space:]]|$)|branch[[:space:]]+-D)' || exit 0

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
# ramas-zombie.sh (misma "mergeada" TRIPLE que los barredores limpiar-ramas/worktrees: ancestro de la base
# | equivalencia de parche squash/cherry | remota-gone sin commits únicos) → sin divergencia. Solo aplica
# si el comando es SOLO branch -d/-D (sin reset/checkout/rebase, que sí mueven HEAD → peligro real abajo).
if printf '%s' "$unquoted" | grep -qE 'git[[:space:]]+branch[[:space:]]+-[dD]' \
   && ! printf '%s' "$unquoted" | grep -qE 'git[[:space:]]+(reset[[:space:]]+--(hard|merge|keep)|checkout[[:space:]]+(-f|--force)|rebase([[:space:]]|$))'; then
  root=$(git -C "$TDIR" rev-parse --show-toplevel 2>/dev/null || true)
  zlib="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/ramas-zombie.sh"
  if [ -n "$root" ] && [ -f "$zlib" ]; then
    # shellcheck source=/dev/null
    . "$zlib"
    base=$(bz_resolver_base "$root")
    # tokens tras el -d/-D (hasta pipe/;/&); quita flags sueltos (-r/-f/-q…). Cada token puede ser un
    # nombre exacto o un glob → se expande contra las ramas LOCALES reales con `git branch --list`.
    toks=$(printf '%s' "$unquoted" \
      | grep -oE 'git[[:space:]]+branch[[:space:]]+-[dD][A-Za-z]*[[:space:]]+[^|;&]+' \
      | sed -E 's/.*branch[[:space:]]+-[dD][A-Za-z]*[[:space:]]+//' \
      | tr ' ' '\n' | grep -vE '^-')
    riesgo=""
    while IFS= read -r tok; do
      [ -z "$tok" ] && continue
      while IFS= read -r br; do
        [ -z "$br" ] && continue
        bz_es_zombie "$root" "$br" "$base" || riesgo="$riesgo $br"
      done < <(git -C "$root" branch --list --format='%(refname:short)' "$tok" 2>/dev/null)
    done <<EOF
$toks
EOF
    # Si ninguna rama nombrada tiene trabajo PROPIO fuera de la base (todas zombies, o el glob no matcheó
    # nada) → borrado seguro → SILENCIO (mata el FP dominante). Si alguna SÍ → aviso ACOTADO a esa rama.
    if [ -n "$riesgo" ]; then
      msg="AVISO (proteger-arbol): git branch -D borraría commits PROPIOS aún NO integrados a '$base' en:$riesgo (no están por ancestro ni por squash/cherry). Si es intencional, adelante; si no, intégralo/pushéalo antes de borrar."
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

# H14: en un worktree AISLADO el DESASTRE que este hook vigila —orfanar los commits del ORQUESTADOR en
# el árbol COMPARTIDO— es IMPOSIBLE: el aislado solo tiene SU propia rama. Y el workaround del bug de
# harness H15 (el worktree nace en `origin/HEAD` viejo y el agente hace `git reset --hard <su rama
# objetivo>` al arrancar) dispara un aviso SIEMPRE falso: los "orfanados" son el base RANCIO, no trabajo.
# Feedback real (2026-07): 4 agentes de un fan-out lo dispararon, todos legítimos → desincentiva delegar.
if [ "$gd" != "$gcd" ]; then
  cur=$(git -C "$root" symbolic-ref --short -q HEAD 2>/dev/null)
  # objetivo del reset/checkout destructivo (vacío = a HEAD, inocuo)
  tgt=$(printf '%s' "$unquoted" | grep -oE 'git[[:space:]]+(reset[[:space:]]+--(hard|merge|keep)|checkout[[:space:]]+(-f|--force))[[:space:]]+[^[:space:]|;&]+' | awk '{print $NF}' | head -1)
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

# Árbol PRINCIPAL (compartido): aquí SÍ está el peligro real → aviso completo.
msg="AVISO (proteger-arbol): este git destructivo puede ORFANAR $n commit(s) sin pushear en el árbol PRINCIPAL (compartido). Si eres un AGENTE de fan-out: NO operes el árbol COMPARTIDO — trabaja en tu worktree aislado (isolation: worktree); si necesitas rebobinar, que lo haga el orquestador. Si es intencional (rebobinar a propósito) y ya lo pensaste, ignora este aviso. Lección real (2026-07): un agente reseteó HEAD en el árbol principal y orfanó un commit del orquestador."
jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
exit 0
