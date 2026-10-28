#!/usr/bin/env bash
# entorno-maquina-guard.sh — PreToolUse/Bash. MECANISMO de la norma dura "el entorno de MÁQUINA vive
# GLOBAL, jamás en el repo de un proyecto ni en tu slug". AVISA (NO bloquea) cuando un `git commit` está por meter al `.claude/memory/`
# de un repo algo específico-de-esta-máquina — que viajaría por git y MENTIRÍA al clonar en otra compu/OS.
# Lo machine-specific vive SOLO en ~/.claude/entorno-maquina.md (global per-máquina, que NO viaja
# por git); un repo documenta el proyecto de forma PORTABLE/CONDICIONAL (nombrado `correr-en-local.md`).
#
# Dispara con DOS señales de alta precisión, ambas acotadas a archivos bajo `.claude/memory/`:
#   (1) FILENAME: un `entorno-maquina.md` (el nombre-trampa que la norma prohíbe → renómbralo).
#   (2) CONTENIDO agregado: líneas nuevas con marcas machine-specific — aliases personales
#       (`alias x=` / `→ eza|trash|…`), rutas absolutas de un `$HOME` (`/Users/x/`, `/home/x/`,
#       `C:\Users\`), o "Rosetta" SIN condicional (si/if/cuando/Apple Silicon/arm64/opt-in).
# Precisión > exhaustividad: solo mira lo que ENTRA (staged) en archivos de memoria del repo; cualquier
# otro Bash pasa al instante. NUNCA bloquea (additionalContext), así no frena trabajo — solo nombra el
# smell y a dónde va. Fail-open sin jq/git.
#
# Vive en brain/hooks/ (fuente); tier `both` (viaja per-repo Y global). dedupe doble-cableado abajo.
set -u

# dedupe: si soy la copia del REPO y la copia GLOBAL existe, cedo (evita doble aviso). En un clon SIN
# bootstrap la del repo sí corre. NO-debilitante: sigue avisando 1×.
_cfgh="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks"; case "$0" in "$_cfgh/"*) : ;; *) [ -f "$_cfgh/$(basename "$0")" ] && exit 0 ;; esac

command -v jq >/dev/null 2>&1 || exit 0
cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$cmd" ] && exit 0
# PRE-FILTRO barato (superset conservador, mismo espíritu que proteger-arbol.sh): este hook solo
# vigila `git commit` → sin 'git' en el comando crudo, early-exit ANTES de sourcear la lib.
case "$cmd" in *git*) : ;; *) exit 0 ;; esac
# El despoje usa la lib compartida (acg_despoja_comillas/acg_es_commit), la MISMA que usan los otros guards.
# shellcheck source=analizar-comando-git.sh
_ACGLIB="$(dirname "$0")/analizar-comando-git.sh"
[ -f "$_ACGLIB" ] && . "$_ACGLIB"
if command -v acg_despoja_comillas >/dev/null 2>&1; then
  # Normaliza el prefijo git (colapsa `git -C <dir>`/`-c k=v`) ANTES de acg_es_commit: sin esto un
  # `git -C <otro-repo> commit` NO se reconocía como commit (el -C rompe la adyacencia git+commit) y el
  # guard salía mudo (MEDIO auditoría 2026-10-22). El dir real lo resuelve acg_target_dir sobre el cmd CRUDO.
  unquoted=$(acg_normaliza_git_prefijo "$(acg_despoja_comillas "$cmd")")
  acg_es_commit "$unquoted" || exit 0
else
  unquoted=$(printf '%s' "$cmd" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g")
  printf '%s' "$unquoted" | grep -qE 'git[[:space:]]+commit([[:space:]]|$)' || exit 0
fi

command -v git >/dev/null 2>&1 || exit 0
# El dir objetivo honra un `git -C <path>` / `cd <path> &&` del comando (MEDIO auditoría 2026-10-22): sin
# esto el guard analizaba el repo del cwd/CLAUDE_PROJECT_DIR aunque el commit fuera a OTRO repo → leía los
# staged del repo EQUIVOCADO. Reusa acg_target_dir (misma resolución -C>cd>cwd que merge-develop-guard).
if command -v acg_target_dir >/dev/null 2>&1; then
  dir=$(acg_target_dir "$cmd" "${CLAUDE_PROJECT_DIR:-}")
else
  dir="${CLAUDE_PROJECT_DIR:-.}"
fi
git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Candidatos: archivos .md bajo .claude/memory/ que ENTRAN en este commit (staged). Si el commit trae
# -a/--all, suma también los tracked modificados sin stagear (git los staged al commitear).
staged=$(git -C "$dir" diff --cached --name-only 2>/dev/null)
allflag=0
printf '%s' "$unquoted" | grep -qE '(^|[[:space:]])(-a|--all|-[a-zA-Z]*a[a-zA-Z]*)([[:space:]]|$)' && allflag=1
[ "$allflag" = 1 ] && staged="$staged
$(git -C "$dir" diff --name-only 2>/dev/null)"

# `git commit … -- <rutas>` solo comitea esas rutas: lo staged fuera de ellas no entra (B-30).
if printf '%s' "$unquoted" | grep -qE 'commit([[:space:]][^;&|]*)?[[:space:]]--([[:space:]]|$)'; then
  rutas=$(printf '%s' "$cmd" | awk '{ i = 0; s = $0; while ((j = index(s, " -- ")) > 0) { i += j + 3; s = substr(s, j + 4) } if (i) print substr($0, i + 1) }' \
    | sed -E 's/[;&|].*$//' | tr -d "'\"")
  filtrado=""
  for r in $rutas; do
    r="${r#./}"; r="${r%/}"
    filtrado="$filtrado
$(printf '%s\n' "$staged" | awk -v r="$r" '$0 == r || index($0, r "/") == 1')"
  done
  staged="$filtrado"
fi

mem_files=$(printf '%s\n' "$staged" | grep -E '(^|/)\.claude/memory/[^/]*\.md$' | grep -v '\.local\.md$' | sort -u)
[ -z "$mem_files" ] && exit 0

# (1) FILENAME-trampa
bad_name=$(printf '%s\n' "$mem_files" | grep -E '(^|/)entorno-maquina\.md$')

# (2) CONTENIDO machine-specific en líneas AGREGADas (staged; o worktree si vino por -a)
added_of() {  # $1 = archivo → solo líneas agregadas (sin la cabecera +++)
  local f="$1" d
  d=$(git -C "$dir" diff --cached -- "$f" 2>/dev/null)
  [ -z "$d" ] && [ "$allflag" = 1 ] && d=$(git -C "$dir" diff -- "$f" 2>/dev/null)
  printf '%s\n' "$d" | grep -E '^\+' | grep -vE '^\+\+\+'
}
content_hits=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  added=$(added_of "$f")
  [ -z "$added" ] && continue
  hit=""
  printf '%s\n' "$added" | grep -qE '(^|[^[:alnum:]])alias[[:space:]]+[A-Za-z0-9_-]+=|→[[:space:]]*`?(eza|trash|bat|nvim|colima)' && hit="alias/tool personal"
  printf '%s\n' "$added" | grep -qE '/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/|[A-Za-z]:[\\]Users[\\]' && hit="${hit:+$hit, }ruta absoluta de un \$HOME"
  # "Rosetta" en una línea SIN una palabra condicional. Per-LÍNEA: basta UNA línea Rosetta incondicional
  # para avisar. Antes el chequeo era COLECTIVO — una línea Rosetta CON condicional (el inner grep -qi de
  # abajo) SILENCIABA a las otras SIN condicional (MEDIO auditoría 2026-10-22). El `grep rosetta | grep -v
  # <cond>` ya deja SOLO las líneas incondicionales; si queda alguna (-q → exit 0), avisa.
  printf '%s\n' "$added" | grep -iE 'rosetta' | grep -viqE 'si |if |cuando|apple silicon|arm64|opt-in|condicional|solo si|only if' \
    && hit="${hit:+$hit, }Rosetta sin condicional"
  [ -n "$hit" ] && content_hits="${content_hits}    · ${f##*/}: $hit\n"
done <<EOF
$mem_files
EOF

[ -z "$bad_name" ] && [ -z "$content_hits" ] && exit 0

MSG="AVISO (norma dura 'el entorno de MÁQUINA vive GLOBAL, jamás en el repo de un proyecto ni en tu slug'): este git commit mete al .claude/memory/ de ESTE repo contenido que parece específico-de-esta-máquina — en un repo viaja por git y MIENTE al clonar en otra compu/OS."
[ -n "$bad_name" ] && MSG="$MSG || FILENAME-trampa: $(printf '%s' "$bad_name" | tr '\n' ' ')— la norma prohíbe 'entorno-maquina.md' en un repo; si es cómo correr EL PROYECTO, hazlo PORTABLE/CONDICIONAL y renómbralo a 'correr-en-local.md'."
[ -n "$content_hits" ] && MSG="$MSG || CONTENIDO machine-specific en:\n$(printf '%b' "$content_hits")   Lo personal-de-instancia (aliases, rutas de tu \$HOME, Rosetta/colima sin condicional) va SOLO en el entorno GLOBAL per-máquina (~/.claude/entorno-maquina.md, que NO viaja por git). En el repo deja solo lo portable/condicional ('si estás en Apple Silicon: platform: linux/amd64')."
MSG="$MSG || Esto AVISA, no bloquea: si de verdad es portable, ignóralo."

jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
exit 0
