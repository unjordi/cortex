#!/usr/bin/env bash
# proteger-autorizaciones.sh — PreToolUse/{Bash,Edit,Write,MultiEdit}: BLOQUEA (deny) que el AGENTE
# ESCRIBA el archivo de grants durables `autorizaciones-vigentes*` (típico `.claude/memory/
# autorizaciones-vigentes.local.md`). Cierra la AUTO-AUTORIZACIÓN: ese archivo es la vía durable por la
# que merge-develop-guard honra un merge a develop SIN el juez (un grant con `cita="<frase del usuario>"`).
# Si el propio agente puede ESCRIBIRLO, elige la subcadena-cita que quiera de cualquier mensaje humano y
# se auto-autoriza — el veto de cita de _grant_cita_verificada verifica que la cita EXISTA, no que el
# HUMANO decidiera poner el grant. La defensa correcta es el CHOKEPOINT de escritura: solo el HUMANO
# escribe este archivo.
#
# CÓMO lo logra (el invariante): una escritura del AGENTE a este archivo SIEMPRE pasa por una tool
# (Bash/Edit/Write/MultiEdit) → PreToolUse la ve → la DENIEGA. La escritura del HUMANO con el prefijo `!`
# (`! echo '- scope=merge-develop …' >> …/autorizaciones-vigentes.local.md`) la corre el CLI directamente,
# NO como tool_use → NO pasa por PreToolUse → el humano SÍ escribe el grant, el agente no. Ése es el
# mecanismo exacto que separa "lo decidió el usuario" de "se lo inventó el agente".
#
# - LEER el archivo (cat/grep/awk/less/head/tail/sed sin -i …) PASA: el agente debe poder consultar el
#   grant vigente. Solo se bloquea una ESCRITURA cuyo DESTINO sea `autorizaciones-vigentes*`.
# - Vectores de escritura cubiertos (Bash): `>`/`>>` (incl. heredoc `cat > … <<EOF`), `tee`, `sed -i`,
#   `cp`/`mv`/`ln`/`install`/`rsync`/`dd of=`, y un intérprete (python/perl/ruby/node/php) que abra el
#   archivo en modo escritura. Edit/Write/MultiEdit: por `file_path`.
# - SIN escape por env: una perilla que el AGENTE pudiera setear sería justo el bypass que esto cierra.
#   El único "escape" es el legítimo: que lo escriba el HUMANO con `!` (no pasa por este hook).
# - FAIL-OPEN sin jq / sin command ni file_path → exit 0 (no frena a ciegas). Rápido: pre-filtro por el
#   token del nombre antes de cualquier regex.
#
# Vive en brain/hooks/ (fuente); tier `both` (global por bootstrap + viaja por-repo para proteger clones
# COMPARTIDOS sin brain global) → trae la cláusula de dedupe (la copia del repo cede a la global).
_cfgh="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks"; case "$0" in "$_cfgh/"*) : ;; *) [ -f "$_cfgh/$(basename "$0")" ] && exit 0 ;; esac

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat 2>/dev/null || true)

# El nombre que protegemos (prefijo). Cualquier basename que empiece así → es el archivo de grants.
_AUTH_GLOB='autorizaciones-vigentes'

_deny() {   # $1 = detalle de por qué/ cómo
  local r="BLOQUEADO (proteger-autorizaciones): este comando ESCRIBIRÍA el archivo de grants durables \`autorizaciones-vigentes*\` ($1). Ese archivo es la autorización durable que merge-develop-guard honra SIN el juez; si el AGENTE lo escribe, se AUTO-AUTORIZA un merge a develop. Por diseño SOLO el HUMANO lo escribe: si unjordi quiere dejar un grant, que lo corra ÉL con el prefijo \`!\` (p. ej. \`! echo '- scope=merge-develop vence_epoch=… cita=\"<su frase>\"' >> .claude/memory/autorizaciones-vigentes.local.md\`) — ese \`!\` lo ejecuta el CLI, NO pasa por este hook. LEER el archivo (cat/grep) sí está permitido. (Norma dura «Integridad de los guardarraíles»: este candado no se afloja por conveniencia.)"
  jq -n --arg r "$r" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)

case "$tool" in
  Edit|Write|MultiEdit)
    fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    [ -z "$fp" ] && exit 0
    case "$(basename -- "$fp")" in
      "$_AUTH_GLOB"*) _deny "un $tool a $fp" ;;
    esac
    exit 0
    ;;
  *)
    # Bash (y cualquier otro con .command). El matcher nos manda Bash; actuamos solo si hay command.
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    [ -z "$cmd" ] && exit 0
    ;;
esac

# --- Camino Bash: ¿el comando ESCRIBE a autorizaciones-vigentes*? ---
# Pre-filtro barato: sin el token del nombre no puede tocarlo → early-exit antes de gastar regex.
printf '%s' "$cmd" | grep -qF "$_AUTH_GLOB" || exit 0

# Normaliza quitando SOLO los caracteres de comilla (mantiene el texto): así `>> "autoriz…"` (destino
# entrecomillado) se detecta igual, sin re-parsear el shell. Conservador para un DENY de seguridad: a lo
# más un `echo '>> autorizaciones-vigentes'` (texto literal, caso irreal) daría un FP seguro.
norm=$(printf '%s' "$cmd" | tr -d "\"'")

# 1) Redirección (> o >>, incluye el heredoc `cat > f <<EOF`) cuyo destino contiene el nombre.
printf '%s' "$norm" | grep -qE '>>?[[:space:]]*[^[:space:]<>|&;]*'"$_AUTH_GLOB" \
  && _deny "redirección > / >> hacia el archivo"
# 2) tee (escribe cada archivo-argumento; -a = append).
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])tee([[:space:]]+-[A-Za-z]+)*[[:space:]]+[^|&;]*'"$_AUTH_GLOB" \
  && _deny "tee hacia el archivo"
# 3) sed -i / in-place, y cp/mv/ln/install/rsync/dd of= con el archivo como argumento (destino).
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])sed[[:space:]]+[^|&;]*-i[^|&;]*'"$_AUTH_GLOB" \
  && _deny "sed -i sobre el archivo"
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])(cp|mv|ln|install|rsync)([[:space:]]+-[A-Za-z]+)*[[:space:]]+[^|&;]*'"$_AUTH_GLOB" \
  && _deny "cp/mv/ln/install/rsync con el archivo como destino"
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])dd([[:space:]]+[^|&;]*)?[[:space:]]of='"[^[:space:]|&;]*$_AUTH_GLOB" \
  && _deny "dd of= hacia el archivo"
# 4) Intérprete que abre el archivo en modo ESCRITURA (python/perl/ruby/node/php) — heurística: el
#    intérprete + el nombre + una señal de escritura (modo w/a, open(...,'w'), .write, >>).
if printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])(python[0-9.]*|perl|ruby|node|php)([[:space:]]|$)'; then
  printf '%s' "$norm" | grep -qE "open\([^)]*$_AUTH_GLOB[^)]*,[^)]*[wa]|$_AUTH_GLOB[^)]*,[^)]*[\"]?[wa]|[wa][\"]?[^)]*$_AUTH_GLOB|\.write|>>[[:space:]]*[^[:space:]]*$_AUTH_GLOB" \
    && _deny "un intérprete abriendo el archivo en modo escritura"
fi

exit 0
