#!/usr/bin/env bash
# merge-squash-guard.sh — PreToolUse guard: al mergear una ramita a develop, EXIGE squash.
# Lee el JSON del hook por stdin; si el comando mergea un MR/PR (glab mr merge|accept, gh pr
# merge) SIN `--squash`/`-s`, devuelve permissionDecision "deny": NO pregunta — bloquea y pide
# rehacerlo con `--squash --squash-message "<resumen curado>"`. Así develop recibe UN commit
# limpio por slice (la ramita puede traer N commits granulares; se colapsan al integrar).
#
# Reparto de responsabilidades: este hook fuerza el SQUASH (mecánico) y un PISO de SUSTANCIA del
# MENSAJE del squash (bloquea el título default "Merge pull request #N", el vacío y el placeholder de
# una palabra — ver la validación develop-scoped abajo). La CALIDAD del resumen (prosa que explique el
# cambio neto y su porqué) sigue siendo criterio de la skill cerrar-slice / flujo-mr-gitlab: el hook es
# un PISO anti-basura (auditor=piso-no-meta), no una vara de calidad. El candado server-side definitivo
# es el ajuste de GitLab `squash_option=always` (ver flujo-de-trabajo.md).
#
# Fail-open ante parseo (sin jq no bloquea). Vive en <repo>/.claude/hooks/ (viaja por git).

# dedupe doble-cableado: si soy la copia del REPO y la copia GLOBAL existe, cedo (la global maneja
# esta invocación) → evita disparo doble en máquina con el cerebro global; en un clon SIN bootstrap
# (sin copia global) la del repo sí corre. NO-debilitante: sigue disparando 1× y denegando igual.
case "$0" in "$HOME/.claude/hooks/"*) : ;; *) [ -f "$HOME/.claude/hooks/$(basename "$0")" ] && exit 0 ;; esac
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0
# PRE-FILTRO barato (superset conservador, mismo espíritu que proteger-arbol.sh): lo que este guard
# vigila (glab mr merge|accept, gh pr merge) requiere 'glab'/'gh' en el comando crudo → sin eso,
# early-exit ANTES de gastar sed/grep/source-lib. Jamás salta un caso real.
case "$cmd" in *glab*|*gh*) : ;; *) exit 0 ;; esac
# cwd del payload → resuelve el repo/destino del MR desde el dir REAL del comando (no CLAUDE_PROJECT_DIR).
# Mejora la resolución gh/glab del destino (cierra el FP de release-gh por RESOLVER bien, sin tocar el
# fail-safe). Ausente → vacío → acg_destino_de_mr cae a CLAUDE_PROJECT_DIR (conducta de hoy).
pcwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)

# shellcheck source=analizar-comando-git.sh
. "$(dirname "$0")/analizar-comando-git.sh"

# Comando-ejemplo tool-aware para rehacer el merge con squash + un mensaje curado (gh vs glab). Fuente
# ÚNICA para los DOS deny del hook (falta-de-squash y mensaje-pobre) → no divergen.
_rehaz_sugerido() {
  if printf '%s' "$1" | grep -qE 'gh(\.exe)?[[:space:]]+pr'; then
    printf '%s' 'gh pr merge <id> --squash --subject "<título curado>" --body "$(cat resumen.md)"'
  else
    printf '%s' 'glab mr merge <id> --squash --squash-message "$(cat resumen.md)" --remove-source-branch --yes'
  fi
}

# ¿El comando EJECUTA una integración REAL de MR/PR? (merge/accept glab, pr merge gh; no ayuda/dry-run).
# La lógica de reconocimiento vive en la lib (fuente única con los otros git-guards → no divergen).
acg_es_merge_mr "$cmd" || exit 0

# ¿Ya trae squash? (--squash o -s). Si SÍ, el SQUASH está garantizado — pero un squash con MENSAJE POBRE
# (título default de la plataforma "Merge pull request #N", vacío o placeholder de una palabra) igual
# pierde el resumen curado que exige cerrar-slice. Validamos la CALIDAD del mensaje ANTES de dejar pasar.
SQUASH_RE='(--squash([[:space:]]|=|$)|(^|[[:space:]])-s([[:space:]]|$))'
if printf '%s' "$cmd" | grep -qE "$SQUASH_RE"; then
  # La validación de mensaje es develop-scoped (MISMA frontera que la exigencia de squash): main=release y
  # ramas personales van libres; destino IRRESOLUBLE ⇒ PASA (la calidad del mensaje es un concern MÁS SUAVE
  # que el mecánico del squash — bloquear por él sin certeza del alcance sería FP-prone; conservador ≠ tumbar
  # un merge legítimo). El destino se resuelve con la MISMA lib+caché que comparte confirmar-merge-develop
  # (cache-hit típico → sin llamada de red extra en el caso develop).
  _dest_sq=$(acg_destino_de_mr "$cmd" "$pcwd")
  [ "$_dest_sq" = "develop" ] || exit 0
  # ¿De dónde sale el subject? LITERAL (flag en el comando → verifica directo) · AUTO (título del MR/PR →
  # verifica vía API) · UNVERIFICABLE ($()/variable/--fill/--body-file → no verificable en PreToolUse → PASA).
  case "$(acg_msg_clasificar "$cmd")" in
    UNVERIFICABLE) exit 0 ;;
    LITERAL)       _msg=$(acg_msg_valor "$cmd") ;;
    *)             _msg=$(acg_mensaje_de_mr "$cmd" "$pcwd"); [ -z "$_msg" ] && exit 0 ;;   # API no resolvió → FAIL-OPEN
  esac
  acg_msg_es_pobre "$_msg" || exit 0   # el mensaje tiene sustancia → PASA
  # Mensaje POBRE → DENY: rehacer con un resumen curado (NO afloja la exigencia de squash: la conserva y AÑADE ésta).
  _rehaz=$(_rehaz_sugerido "$cmd")
  jq -n --arg r "FLUJO DE GIT (ley interna): el squash a develop debe llevar un RESUMEN CURADO en prosa (el cambio neto y su porqué), NO el título default de la plataforma (\"Merge pull request #N\"), ni un mensaje vacío o de una sola palabra (\"wip\"/\"fix\"/\"update\"). Rehaz el merge con un mensaje con sustancia: $_rehaz  — el mensaje es el resumen del slice, no el pegote de commits. Ver skill cerrar-slice." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
fi

# La obligatoriedad de --squash aplica cuando el DESTINO es `develop` (1 commit limpio por slice) y —por
# FAIL-SAFE— también cuando el destino NO se pudo resolver (vacío por timeout/error de red). `main` es
# RELEASE (conserva historia — JAMÁS se fuerza squash) y las ramas personales/ramitas son el día a día
# (a tu gusto). El destino lo resuelve la lib (acg_destino_de_mr): caché por MR-id COMPARTIDA con
# confirmar-merge-develop (típicamente 1 llamada de red, no 2; no es lock) + timeout interno para no
# fallar-abierto por muerte del proceso (H5).
#
# B3 (FMEA 2026-07-30): ANTES un destino irresoluble (timeout de red) NO exigía squash, mientras que
# confirmar-merge-develop SÍ trataba el vacío como develop → "merge a develop CONFIRMADO, pero SIN
# squash". Ahora ambos guards FALLAN al MISMO lado: destino irresoluble ⇒ exige squash (conservador),
# SALVO señal EXPLÍCITA de release-a-main en el propio comando (main mencionado / palabra `release`),
# para no aplastar el histórico de un release cuya red no se pudo consultar.
_es_release_explicito() {
  local u; u=$(acg_sin_flag_repo "$(acg_despoja_comillas "$1")")
  printf '%s' "$u" | grep -qiE '[[:space:]:/=](main)([[:space:]]|$)|\brelease\b'
}
_destino=$(acg_destino_de_mr "$cmd" "$pcwd")
if [ -n "$_destino" ]; then
  # Destino RESUELTO: solo `develop` obliga squash; main/personales/ramitas van libres.
  [ "$_destino" = "develop" ] || exit 0
else
  # Destino IRRESOLUBLE (timeout/red / sin id): fail-safe → exige squash salvo release explícito en el cmd.
  _es_release_explicito "$cmd" && exit 0
fi

# El mensaje cita la herramienta REAL del repo (gh vs glab), no siempre glab (P5).
_rehaz=$(_rehaz_sugerido "$cmd")
jq -n --arg r "FLUJO DE GIT (ley interna): integrar a develop SQUASHEA a UN commit limpio por slice. NO reintentes este merge sin squash. Rehazlo con: $_rehaz  — donde el mensaje es un RESUMEN CURADO en prosa del slice (el cambio neto y su porqué), NO el pegote de commits granulares. NOTA: la obligación de squash es SOLO para develop — a main (release) va SIN squash (conserva historia) y tus ramas personales van a tu gusto. Ver skill cerrar-slice." \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
