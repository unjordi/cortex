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

# ¿El comando trae un operador de ESCRITURA A ARCHIVO? (para la regla de indirección — el destino puede ir
# oculto en una variable/glob). Reconoce tee/cp/mv/ln/install/rsync/dd/truncate, `sed -i`, un intérprete con
# -c/-e, y una redirección `>`/`>>` A ARCHIVO — excluyendo las que NO escriben un archivo del repo: `2>…`
# (stderr), `>&N` (dup de fd), `&>…`, y `>/dev/null`. Así una LECTURA con `2>/dev/null` no cuenta como escritura.
_tiene_escritura_a_archivo() {
  local c="$1" r
  printf '%s' "$c" | grep -qE '(^|[^[:alnum:]_/])(tee|cp|mv|ln|install|rsync|dd|truncate)([[:space:]]|$)' && return 0
  printf '%s' "$c" | grep -qE '(^|[^[:alnum:]_/])sed[[:space:]]+[^|&;]*-i' && return 0
  printf '%s' "$c" | grep -qE '(^|[^[:alnum:]_/])(python[0-9.]*|perl|ruby|node|php)[[:space:]][^|&;]*-[ce]' && return 0
  r=$(printf '%s' "$c" | sed -E 's/2>>?[[:space:]]*[^|&;[:space:]]*//g; s/[0-9]*>&[0-9-]*//g; s/&>>?[[:space:]]*[^|&;[:space:]]*//g; s#>>?[[:space:]]*/dev/null##g')
  printf '%s' "$r" | grep -qE '>' && return 0
  return 1
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

# --- Camino Bash: ¿el comando ESCRIBE a autorizaciones-vigentes* (directo o por INDIRECCIÓN)? ---
# Pre-filtro barato: el nombre se parte en dos mitades distintivas, `autoriz…` y `…vigentes`. Una
# indirección (variable/glob/split) puede ocultar una mitad, pero rara vez las dos → si NINGUNA aparece en el
# texto, el comando no puede nombrar el archivo → early-exit. (Residual BAJO: ofuscación que no deja NINGUNA
# mitad — base64/rev/un script aparte — ver nota en la sección (B).)
printf '%s' "$cmd" | grep -qiE 'autoriz|vigentes' || exit 0

# Normaliza quitando SOLO los caracteres de comilla (mantiene el texto): así `>> "autoriz…"` (destino
# entrecomillado) se detecta igual, sin re-parsear el shell. Conservador para un DENY de seguridad: a lo
# más un `echo '>> autorizaciones-vigentes'` (texto literal, caso irreal) daría un FP seguro.
norm=$(printf '%s' "$cmd" | tr -d "\"'")

# ── (A) VECTORES DIRECTOS: el nombre LITERAL es el destino de una escritura. Mensaje preciso por vector. ──
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

# ── (B) INDIRECCIÓN (MEDIO 2026-10-23, verificado contra el hook): una variable/glob/split oculta el destino
# y los vectores directos de (A) NO lo ven — p. ej. `F=…/autorizaciones-vigentes.local.md; echo x >> $F`,
# `echo x >> .claude/memory/autoriz*`, `n=autorizaciones; echo x >> .claude/memory/$n-vigentes.local.md`. Con
# el piso de la cita ya retirado (una palabra de cualquier mensaje humano basta), esta cadena re-habilita la
# AUTO-AUTORIZACIÓN → se cierra con una regla CONSERVADORA: si hay un OPERADOR DE ESCRITURA A ARCHIVO Y el
# comando (a) reconstruye las DOS mitades del nombre (`autoriz…` + `…vigentes`) o (b) usa un GLOB pegado a una
# mitad (podría expandir al archivo real) → DENY. LEER sin operador de escritura sigue pasando; una escritura
# con `autoriz` pero SIN `vigentes` ni glob (p. ej. `echo autorizado > status.txt`) NO dispara (anti-FP).
# RESIDUAL BAJO (NO cubierto aquí a propósito, por la norma de precisión): ofuscación pura que no deja ninguna
# mitad en el texto — `base64 … | sh`, `$(printf … | rev)`, o escribir un script aparte y ejecutarlo después.
# Esos los cubren la revisión HUMANA del PR (nadie mergea solo) y el juez de merge; cerrarlos aquí exigiría
# ejecutar/evaluar el comando (inviable en un hook de PreToolUse).
if _tiene_escritura_a_archivo "$norm"; then
  { printf '%s' "$norm" | grep -qiE 'autoriz' && printf '%s' "$norm" | grep -qiE 'vigentes'; } \
    && _deny "escritura con el nombre reconstruido por indirección ('autoriz…' + '…vigentes' en variable/split)"
  printf '%s' "$norm" | grep -qiE '(autoriz|vigentes)[^[:space:]<>|&;]*[*?]|[*?][^[:space:]<>|&;]*(autoriz|vigentes)' \
    && _deny "escritura hacia un glob que puede expandir al archivo de grants (autoriz* / *vigentes)"
fi

exit 0
