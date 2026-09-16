#!/usr/bin/env bash
# secret-scan.sh — PreToolUse/Bash guard DEFENSIVO: bloquea un `git commit`/`git push` cuando el
# contenido que entra al repo trae un SECRETO (llave de API, token, clave privada). Antídoto al
# clásico "se me fue una credencial al repo" — el peor error, porque una vez pusheada ya está
# comprometida aunque la borres después.
#
# Alcance quirúrgico (evita falsos positivos y ruido):
#   - Solo actúa si el comando es un `git commit` o `git push` (cualquier otro Bash → pasa al instante).
#   - En commit escanea SOLO lo AGREGADO en el staging (`git diff --cached`, líneas `+`); en push, lo
#     que sale respecto al upstream (`@{u}..HEAD`). No escanea el árbol entero ni lo que ya existía.
#   - Patrones de ALTA precisión (prefijos/formatos inconfundibles): AWS AKIA, claves privadas PEM,
#     tokens de Anthropic/OpenAI/GitHub/GitLab/Slack/Google. NO usa heurística de entropía genérica
#     (que dispara con hashes, UUIDs, minified JS…). Precisión > exhaustividad: mejor no molestar.
#
# Escapes legítimos (el humano manda): `git ... --no-verify` (convención de git para saltar hooks) o
# el entorno `CLAUDE_SKIP_SECRET_SCAN=1`. Fail-open: sin jq / sin git / sin poder determinar el rango,
# NO bloquea (nunca frena trabajo por una duda de parseo; es una red de seguridad, no una cárcel).
#
# Vive en brain/hooks/ (fuente), se instala GLOBAL en ~/.claude/hooks/ (aplica a todos los repos).
set -u

# dedupe doble-cableado: si soy la copia del REPO y la copia GLOBAL existe, cedo (evita doble escaneo
# en máquina con el cerebro global; en un clon SIN bootstrap la del repo sí corre). Necesario ahora que
# secret-scan es tier `both` (viaja per-repo Y global). NO-debilitante: sigue escaneando 1× y denegando.
case "$0" in "$HOME/.claude/hooks/"*) : ;; *) [ -f "$HOME/.claude/hooks/$(basename "$0")" ] && exit 0 ;; esac

input=$(cat 2>/dev/null || true)
# Sin jq no podemos parsear el comando ni EMITIR un deny ESTRUCTURADO (el deny sale como JSON vía jq).
# Pero un guard DEFENSIVO NO calla: que la red de seguridad esté APAGADA debe ENTERARSE el operador, no
# un fail-open silencioso (antes: `exit 0` mudo → un commit/push entraba sin escaneo y STRICT se ignoraba
# por completo). Sin jq: (a) STRICT hace fail-CLOSED por `exit 2` (bloqueo que NO necesita jq); (b) si no,
# avisa RUIDOSO por stderr y deja pasar (default fail-open). Honra los escapes explícitos aun sin jq.
if ! command -v jq >/dev/null 2>&1; then
  [ "${CLAUDE_SKIP_SECRET_SCAN:-}" = "1" ] && exit 0
  case "$input" in *--no-verify*) exit 0 ;; esac   # escape crudo (superset; coherente con el fail-open)
  case "$input" in
    *git*commit*|*git*push*)
      if [ "${CLAUDE_SECRET_SCAN_STRICT:-0}" = "1" ]; then
        printf '%s\n' "FRENO DE SEGURIDAD (secret-scan STRICT): 'jq' no está instalado; no puedo escanear en busca de secretos antes de dejar entrar código y CLAUDE_SECRET_SCAN_STRICT=1 exige poder verificar. Instala jq (brew install jq / winget install jqlang.jq), o salta conscientemente con 'git … --no-verify' o CLAUDE_SKIP_SECRET_SCAN=1." >&2
        exit 2
      fi
      printf '%s\n' "⚠️ secret-scan: 'jq' no está instalado → este git commit/push NO se escaneó en busca de secretos (la red de seguridad está APAGADA). Instala jq para reactivarla; CLAUDE_SECRET_SCAN_STRICT=1 la volvería obligatoria." >&2
      ;;
  esac
  exit 0
fi

# DECISIÓN fail-open vs fail-closed (§D): por DEFAULT fail-OPEN ante fallo de INFRAESTRUCTURA (sin git, no
# es repo, no se puede determinar el rango del diff) — bloquear TODO commit por un problema de entorno es
# desproporcionado y este guard es "red de seguridad, no cárcel"; el backstop real es la rotación + gates
# server-side. Con CLAUDE_SECRET_SCAN_STRICT=1 el operador OPTA por fail-CLOSED: si no se puede escanear,
# se bloquea (postura conservadora para entornos sensibles). El default NO cambia el comportamiento previo.
STRICT="${CLAUDE_SECRET_SCAN_STRICT:-0}"
bail_open() {  # $1 = motivo. En strict → deny; si no → deja pasar (exit 0).
  if [ "$STRICT" = "1" ]; then
    jq -n --arg r "FRENO DE SEGURIDAD (secret-scan, modo STRICT): no pude escanear en busca de secretos ($1) y CLAUDE_SECRET_SCAN_STRICT=1 exige poder verificar antes de dejar entrar código. Resuelve la causa, o usa 'git … --no-verify' / CLAUDE_SKIP_SECRET_SCAN=1 para esta acción." \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  fi
  exit 0
}

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0
# M2 (auditoría 2026-09-15, CRÍTICO §3.1): cwd del payload = working dir REAL del comando (puede diferir
# de CLAUDE_PROJECT_DIR, fijo al arranque de la sesión). Sin esto, un `git -C <otro-repo> commit`, un
# `cd <otro-repo> && git commit`, o simplemente un comando corrido desde OTRO cwd (el patrón NORMAL de un
# worktree aislado de fan-out) escaneaba el repo EQUIVOCADO — un secreto en el repo que el comando REALMENTE
# toca pasaba SIN escanear, y este es el ÚNICO control anti-credenciales del sistema (sin backstop server-side).
pcwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)

# PRE-FILTRO barato (superset conservador, mismo espíritu que proteger-arbol.sh): este guard solo actúa
# sobre `git commit`/`git push` → sin 'git' en el comando crudo, early-exit ANTES de cualquier
# normalización/despoja-comillas. Jamás salta un caso real.
case "$cmd" in *git*) : ;; *) exit 0 ;; esac

# Despoja literales entrecomillados ANTES de razonar sobre el comando: reusa acg_despoja_comillas de la
# lib compartida si está junto al hook, si no un sed equivalente. Así un token DENTRO de una comilla —el
# `--no-verify` citado en el MENSAJE del commit (A7), o un `git commit`/`git add`/`git push` mencionado en
# el texto— no altera la decisión del guard. bash-3.2-safe.
# CRÍTICO-1 (auditoría FMEA 2026-09-16 §1.1, CONFIRMADO): sourcear un archivo con error de SINTAXIS mata el
# proceso ENTERO con exit 1 -- que el harness trata como NO-bloqueante. secret-scan es "el ÚNICO control
# anti-credenciales del sistema, sin backstop server-side" (comentario original arriba): un typo de sintaxis
# en la lib compartida apagaba ESTA red de seguridad en silencio total, exactamente igual que los otros 4
# guards. Se prueba el source en un SUBSHELL primero: si truena ahí, el crash queda AISLADO (el proceso
# padre sigue vivo) y el guard DEGRADA a su propio fallback sed (el `command -v acg_despoja_comillas` de
# abajo ya sabía hacerlo -- el bug era que nunca llegaba a preguntarlo porque el `.` normal lo mataba antes).
# Snippet IDÉNTICO en los 5 guards; a propósito FUERA de la lib.
_ACGLIB="$(dirname "$0")/analizar-comando-git.sh"
if [ -f "$_ACGLIB" ] && ( . "$_ACGLIB" ) >/dev/null 2>&1; then
  # shellcheck source=analizar-comando-git.sh
  . "$_ACGLIB"
else
  [ -f "$_ACGLIB" ] && printf '%s: analizar-comando-git.sh existe pero no cargó (error de sintaxis) -- usando el fallback sed propio (menos preciso). `bash -n "%s"` localiza el error.\n' "$(basename "$0")" "$_ACGLIB" >&2
fi
# A-03/A-R4-02 (FMEA): colapsa el prefijo de opciones globales de git (`-c k=v`, `-C dir`, `--no-pager`,
# `--work-tree`, …) para que `git <globales> commit` NO evada la adyacencia git+commit/push del gate (ese
# prefijo cegaba el escaneo). A-R5-02 (FMEA r5): se NORMALIZA SOBRE EL RAW (comillas intactas) ANTES de
# despojar — si se despoja primero, un value-eater con valor entrecomillado (`git -C "/ruta" commit`) queda
# vacío y el normalizador se come el subcomando `commit` → escaneo CIEGO. El normalizador es quote-aware
# (consume el valor entrecomillado con espacios como una unidad). Orden correcto: normaliza(raw) → despoja.
if command -v acg_normaliza_git_prefijo >/dev/null 2>&1; then
  cmd_norm=$(acg_normaliza_git_prefijo "$cmd")
else
  cmd_norm=$(printf '%s' "$cmd" | sed -E 's/(^|[^[:alnum:]._-])git\.exe([[:space:]])/\1git\2/g' | sed -E "s/git[[:space:]]+((((-c|-C|--exec-path|--git-dir|--work-tree|--namespace|--attr-source|--config-env|--super-prefix)([[:space:]]+|=)([^[:space:]\"']|\"[^\"]*\"|'[^']*'|\\\\.)+)|(--?[a-zA-Z][a-zA-Z-]*(=([^[:space:]\"']|\"[^\"]*\"|'[^']*'|\\\\.)+)?))[[:space:]]+)+/git /g")
fi
if command -v acg_despoja_comillas >/dev/null 2>&1; then
  cmd_uq=$(acg_despoja_comillas "$cmd_norm")
else
  cmd_uq=$(printf '%s' "$cmd_norm" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g")
fi

# ¿Es un commit o un push? Si no, no es asunto de este guard (NO es "no poder escanear" → nunca strict-bloquea).
# LÍMITE CONOCIDO (A-07, FMEA): casa el subcomando LITERAL commit/push; un ALIAS de git del usuario (`git ci`,
# `git psh`) NO matchea → el guard queda inerte en ese caso. Cubrirlo genéricamente exigiría resolver los alias
# (`git config --get alias.*`) por-máquina; se documenta como límite aceptado (depende de config personal, no universal).
printf '%s' "$cmd_uq" | grep -qE 'git[[:space:]]+(commit|push)' || exit 0
# Escapes deliberados (el humano manda) — ganan incluso en strict.
[ "${CLAUDE_SKIP_SECRET_SCAN:-}" = "1" ] && exit 0
# --no-verify como BANDERA real (sobre el cmd despojado), no la palabra dentro del mensaje del commit (A7).
printf '%s' "$cmd_uq" | grep -qE '(^|[[:space:]])--no-verify([[:space:]]|$)' && exit 0

command -v git >/dev/null 2>&1 || bail_open "git no está en el PATH"
# M2: resuelve el DIR objetivo por la MISMA lib que git-branch-guard/merge-squash-guard/confirmar-merge-
# develop (acg_target_dir: -C > cd/pushd > cwd del payload > CLAUDE_PROJECT_DIR > '.') — antes este guard
# era, junto con proteger-arbol, el único de los 5 que NO la usaba pese a tenerla sourceada 3 líneas arriba.
if command -v acg_target_dir >/dev/null 2>&1; then
  dir=$(acg_target_dir "$cmd" "$pcwd")
else
  dir="${pcwd:-${CLAUDE_PROJECT_DIR:-.}}"
fi
git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || bail_open "no es un repo git ($dir)"
# El resto de este guard combina `git -C "$dir" diff/add -- "$f"` con rutas RELATIVAS A LA RAÍZ del repo
# (las que devuelve `git diff --name-only`). Si $dir resolvió a un SUBDIRECTORIO (p. ej. el cwd real del
# comando vive en `repo/src/foo`, el caso NORMAL de una sesión parada ahí) esas rutas root-relative dejan
# de casar con archivos reales bajo $dir → el escaneo saldría CIEGO por partida doble. Se resuelve a la
# RAÍZ (git ya sabe encontrarla desde cualquier subdir) — mantiene el repo CORRECTO que M2 acaba de fijar,
# solo corrige el punto exacto del árbol donde se para a mirar.
dir=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$dir")

# shellcheck source=detectar-secretos.sh
. "$(dirname "$0")/detectar-secretos.sh"   # patrones + ds_buscar (lógica; §D)

# ¿El comando crea un commit? (sobre el cmd despojado). Si no, por el gate de arriba es un push puro.
has_commit=0; printf '%s' "$cmd_uq" | grep -qE 'git[[:space:]]+commit([[:space:]]|$)' && has_commit=1

# A1 · idiom `git add … && git commit` (o `;`, o …`&& git push`) en UN solo comando: en PreToolUse el
# `git add` AÚN NO corrió, así que el staging (`git diff --cached`) está VACÍO → el escaneo de commit
# sería CIEGO, y si además encadena un `&& git push` el bypass es TOTAL (ni commit ni push ven el
# secreto). Cuando el comando CREA un commit y encadena un `git add`, le preguntamos a git QUÉ estagearía
# ese add con `git add --dry-run` (NO muta el índice; resuelve -A/./-u/pathspecs por nosotros) y sumamos
# ESE contenido del working tree al escaneo.
addfiles=""
if [ "$has_commit" = 1 ] && printf '%s' "$cmd_uq" | grep -qE 'git[[:space:]]+add([[:space:]]|$)'; then
  # TODOS los segmentos `git add` del comando, NO solo el 1º: `git add safe && git add secret && git commit`
  # (un solo comando) estagearía AMBOS, pero el `head -1` anterior solo escaneaba `safe` → el secreto de
  # `secret` entraba (hueco real del audit-07, OK de unjordi). Iteramos cada `git add` y sumamos su dry-run.
  while IFS= read -r _addseg; do
    [ -n "$_addseg" ] || continue
    _aargs=$(printf '%s' "$_addseg" | sed -E 's/^git[[:space:]]+add[[:space:]]*//')
    _more=$(git -C "$dir" add --dry-run $_aargs 2>/dev/null | grep "^add '" | sed -E "s/^add '(.*)'\$/\1/")
    addfiles=$(printf '%s\n%s' "$addfiles" "$_more")
  done <<EOF
$(printf '%s' "$cmd_uq" | grep -oE 'git[[:space:]]+add[^;&|]*')
EOF
  addfiles=$(printf '%s\n' "$addfiles" | grep -vE '^[[:space:]]*$' | sort -u)
fi
# A1 (residuo `commit -a`/`-am`/`--all`): la bandera -a AUTO-ESTAGEA los tracked MODIFICADOS al crear el
# commit; en PreToolUse aún no corrió, así que --cached está VACÍO para ellos → el escaneo de commit sería
# CIEGO (mismo hueco que el `git add` encadenado, pero sin `git add` explícito). Detectamos -a/--all en el
# SEGMENTO del commit (cmd_uq ya despojó el mensaje entrecomillado, así que un "-a" en el texto no dispara)
# y sumamos los tracked modificados a addfiles → added_lines los lee con `git diff HEAD -- f` (rama tracked,
# sin re-escanear lo ya versionado). --diff-filter=ACMR: contenido que entra; D (borrados) no aporta secreto.
if [ "$has_commit" = 1 ]; then
  commit_seg=$(printf '%s' "$cmd_uq" | grep -oE 'git[[:space:]]+commit[^;&|]*' | head -1)
  if printf '%s' "$commit_seg" | grep -qE '(^|[[:space:]])(--all|-[a-z]*a[a-z]*)([[:space:]]|$)'; then
    tracked_mod=$(git -C "$dir" diff HEAD --name-only --diff-filter=ACMR 2>/dev/null)
    addfiles=$(printf '%s\n%s\n' "$addfiles" "$tracked_mod" | grep -vE '^$' | sort -u)
  fi
fi

# Modo del escaneo primario: si el comando crea un commit, escaneamos lo que ENTRARÁ con ese commit
# (staging + lo que el add encadenado agregaría) — el commit MANDA aunque también haya un push encadenado
# (así el `git add && git commit && git push` de un tirón no se cuela por la puerta del push, que en
# PreToolUse tampoco vería el commit nuevo). Solo un push PURO (sin commit) usa el rango @{u}..HEAD.
if [ "$has_commit" = 1 ]; then mode="commit"; else mode="push"; fi

# Resuelve BASE (solo modo push) UNA vez; la reusan tanto el diff primario como el listado de archivos.
if [ "$mode" = "push" ]; then
  BASE=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  if [ -z "$BASE" ]; then
    # G5: rama NUEVA sin upstream (el 1er push — donde más se cuela un secreto, porque toda la historia
    # de la rama es nueva). Antes: sin upstream → fail-open (no escaneaba nada). Ahora escanea lo que la
    # rama AGREGA sobre la base de integración: el merge-base con develop/main (remotas primero, luego
    # locales). Así el primer push SÍ se revisa.
    for ref in origin/develop origin/main develop main; do
      git -C "$dir" rev-parse --verify --quiet "$ref" >/dev/null 2>&1 || continue
      BASE=$(git -C "$dir" merge-base HEAD "$ref" 2>/dev/null)
      [ -n "$BASE" ] && break
    done
    [ -z "$BASE" ] && bail_open "sin upstream ni base develop/main para acotar el rango del push"
  fi
fi

# DEFECTO medido (auditoría overhead 2026-09-16, §defecto #4): el escaneo primario ANTES corría un
# `git diff -- "$f"` POR ARCHIVO en un bucle — lineal en archivos tocados; medido en producción: 600 s
# de TIMEOUT con un commit de 105 archivos (`git add -A` + commit masivo). Y un guard DEFENSIVO que se
# pasa de tiempo DEJA DE PROTEGER: se apaga exactamente en el commit más grande, que es justo donde más
# fácil se cuela un secreto sin que nadie lo note al revisar.
#
# Fix: UN solo `git diff` cubre TODO el rango (commit: `--cached`; push: `BASE..HEAD`) sin pathspec por
# archivo — el costo deja de escalar con el número de archivos, solo con el TAMAÑO total del diff (eso
# es inevitable: hay que leer los bytes al menos una vez). Los addfiles (A1: `git add`/`-a` encadenado)
# se suman con invocaciones ÚNICAS también: un solo `git diff HEAD -- <todos los tracked>` + un solo
# `awk` que lee TODOS los untracked nuevos de un jalón (sin invocar `git` por ellos: su contenido
# íntegro entra igual, ya que `git diff --no-index` solo lo envolvía en formato diff sin aportar nada
# que las firmas necesiten).
if [ "$mode" = "commit" ]; then
  primary_diff=$(git -C "$dir" diff --cached 2>/dev/null)
else
  primary_diff=$(git -C "$dir" diff "$BASE..HEAD" 2>/dev/null)
fi

# addfiles (A1: `git add`/`-a` encadenado): separa tracked/untracked con UNA sola consulta (no una por
# archivo), y el diff de los tracked en OTRA sola invocación (todos los pathspecs juntos).
addfiles_tracked_diff=""
untracked_add_arr=()
if [ -n "$addfiles" ]; then
  addfiles_arr=()
  while IFS= read -r _af; do [ -n "$_af" ] && addfiles_arr+=("$_af"); done <<EOF
$addfiles
EOF
  if [ "${#addfiles_arr[@]}" -gt 0 ]; then
    tracked_set=$(git -C "$dir" ls-files -- "${addfiles_arr[@]}" 2>/dev/null)
    tracked_add_arr=()
    for _af in "${addfiles_arr[@]}"; do
      if printf '%s\n' "$tracked_set" | grep -qxF "$_af"; then
        tracked_add_arr+=("$_af")
      else
        untracked_add_arr+=("$_af")
      fi
    done
    # tracked-modificado (p. ej. `-a`/`-am`): solo lo AGREGADO vs HEAD, TODOS en una sola invocación
    # (no re-escanea lo ya versionado → sin falso positivo, igual que antes).
    [ "${#tracked_add_arr[@]}" -gt 0 ] && addfiles_tracked_diff=$(git -C "$dir" diff HEAD -- "${tracked_add_arr[@]}" 2>/dev/null)
  fi
fi

# Parte un diff en pares "archivo<TAB>línea-agregada" — UNA pasada de awk por diff, no por archivo.
# bash-3.2-safe (awk estándar POSIX, sin extensiones GNU).
_ds_split_por_archivo() {
  awk '
    /^diff --git / { file=""; next }
    /^\+\+\+ / {
      f=$0; sub(/^\+\+\+ /, "", f)
      if (f == "/dev/null") { file=""; next }
      sub(/^[ab]\//, "", f); file=f; next
    }
    /^\+/ { if (file != "") { line=$0; sub(/^\+/, "", line); printf "%s\t%s\n", file, line }; next }
    { next }
  '
}
by_file=$(printf '%s' "$primary_diff" | _ds_split_por_archivo)
[ -n "$addfiles_tracked_diff" ] && by_file="${by_file}
$(printf '%s' "$addfiles_tracked_diff" | _ds_split_por_archivo)"
if [ "${#untracked_add_arr[@]}" -gt 0 ]; then
  # nuevo/untracked: TODO el archivo entra al repo. UN solo `awk` recibe TODOS esos archivos como
  # argumentos (detecta el cambio de archivo por sí solo con FNR==1) — cero invocaciones de `git`, y
  # cero forks por archivo (uno solo para el lote completo).
  _uargs=(); for _af in "${untracked_add_arr[@]}"; do _uargs+=("${dir%/}/$_af"); done
  by_file="${by_file}
$(awk -v d="${dir%/}/" 'FNR==1{f=FILENAME; if (index(f,d)==1) f=substr(f,length(d)+1)} {print f "\t" $0}' "${_uargs[@]}" 2>/dev/null)"
fi

# ¿Hay ALGÚN candidato de secreto en TODO lo agregado? Un solo `grep` sobre el total (con el nombre de
# archivo pegado — no importa, es solo un filtro GRUESO): si no hay nada, termina aquí — CERO
# invocaciones de `git` o de cualquier otra herramienta por archivo, sin importar si el commit tocó
# 1 archivo o 10 000 (el caso común, y el que antes se comía los 600 s de timeout).
candidatos=$(printf '%s\n' "$by_file" | grep -E "$_DS_PAT" 2>/dev/null)
[ -z "$candidatos" ] && exit 0

# SÍ hubo candidatos: arma el reporte, pero SOLO sobre los archivos que de verdad matchearon — no sobre
# los N archivos del commit. En el caso típico (el secreto vive en 1 de miles de archivos) esto es una
# vuelta, no miles: el costo del reporte ahora escala con los HITS, no con el tamaño del commit.
hits=""
seen_files=""
while IFS=$'\t' read -r f _rest; do
  [ -z "$f" ] && continue
  printf '%s\n' "$seen_files" | grep -qxF "$f" && continue   # ya reportado (2ª línea candidata del mismo archivo)
  seen_files="${seen_files}
$f"
  # Todo lo agregado de ESE archivo (no solo la línea candidata) — para que `ds_buscar` aplique el
  # mismo tope de "hasta 3" y la misma exclusión de placeholders (lib) que siempre, sin duplicar lógica.
  texto=$(printf '%s\n' "$by_file" | awk -F'\t' -v want="$f" '$1==want{print substr($0, length($1)+2)}')
  red=$(ds_buscar "$texto" | tr '\n' ' ')   # ds_buscar ya redacta y excluye placeholders (lib)
  if [ -n "$red" ]; then
    hits="${hits}
  • ${f}: ${red}"
  fi
done <<EOF
$candidatos
EOF

[ -z "$hits" ] && exit 0   # los candidatos gruesos resultaron ser placeholders (safe_re) — sin secreto real

reason="FRENO DE SEGURIDAD (secret-scan): detecté lo que parece un SECRETO en lo que va a entrar al repo (${mode}). NO lo subas: una credencial pusheada queda comprometida aunque la borres.
Coincidencias (redactadas):${hits}
Qué hacer:
  1) Saca el secreto del código → muévelo a una variable de entorno / gestor de secretos / archivo *.local ignorado por git.
  2) Si ya estaba commiteado antes, ROTA la credencial (dala por comprometida).
  3) Si es un FALSO POSITIVO (placeholder/ejemplo), reintenta con 'git ... --no-verify' o exporta CLAUDE_SKIP_SECRET_SCAN=1 para esta acción."

jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
