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
# MODELO DE AMENAZA (decisión de unjordi 2026-10-23, vía claudio): este guard protege contra un ERROR del
# agente, NO contra evasión DELIBERADA. CUBRE: los vectores de escritura directos + la indirección por
# variable/split/glob/comillas/bracket cuyo DESTINO sea el archivo de grants. NO cubre (BAJO aceptado, no se
# persigue): ofuscación a propósito que no deja ni el nombre ni un glob en el texto —`base64 … | sh`,
# `$(printf … | rev)`, armar el nombre en runtime, o un script aparte— porque la revisión HUMANA del PR y el
# juez de merge son el backstop, y cerrarlo exigiría EJECUTAR el comando (inviable en PreToolUse).
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

# DEFANG (R5-1a, auditoría 2026-10-23): quita comillas (" ') y backslashes de escape para que el nombre
# LITERAL se reconstruya ANTES del pre-filtro y de la detección. Sin esto, el pre-filtro corría sobre el
# comando CRUDO y una comilla intra-palabra (`au''torizaciones-vi''gentes`) o un escape (`au\toriz`) rompían
# ambas mitades del nombre → el hook early-exiteaba y la escritura PASABA. NO expande globs reales (*/?/[…]):
# esos los trata la regla de indirección (B), que ahora reconoce `[` como metacarácter además de */?.
_defang() { printf '%s' "$1" | tr -d '\042\047\134'; }

# ¿El comando trae un operador de ESCRITURA A ARCHIVO? (para la regla de indirección — el destino puede ir
# oculto en una variable/glob). Reconoce tee/cp/mv/ln/install/rsync/dd/truncate, `sed -i`, un intérprete con
# -c/-e, curl/wget que DESCARGAN a archivo, sponge, git checkout/restore -- (sobrescribe el working file),
# y una redirección `>`/`>>` A ARCHIVO — excluyendo las que NO escriben un archivo del repo: `2>…` (stderr),
# `>&N` (dup de fd), `&>…`, y `>/dev/null`. Así una LECTURA con `2>/dev/null` no cuenta como escritura.
_tiene_escritura_a_archivo() {
  local c="$1" r
  printf '%s' "$c" | grep -qE '(^|[^[:alnum:]_/])(tee|cp|mv|ln|install|rsync|dd|truncate|sponge)([[:space:]]|$)' && return 0
  printf '%s' "$c" | grep -qE '(^|[^[:alnum:]_/])sed[[:space:]]+[^|&;]*-i' && return 0
  printf '%s' "$c" | grep -qE '(^|[^[:alnum:]_/])(python[0-9.]*|perl|ruby|node|php)[[:space:]][^|&;]*-[ce]' && return 0
  printf '%s' "$c" | grep -qE '(^|[^[:alnum:]_/])curl[[:space:]][^|&;]*(-o|--output)([[:space:]]|=)' && return 0
  printf '%s' "$c" | grep -qE '(^|[^[:alnum:]_/])wget[[:space:]][^|&;]*(-O|--output-document)([[:space:]]|=)' && return 0
  printf '%s' "$c" | grep -qE '(^|[^[:alnum:]_/])git[[:space:]][^|&;]*(checkout|restore)[[:space:]][^|&;]*--([[:space:]]|$)' && return 0
  # R5-2: quita también las FLECHAS `->`/`=>` para no confundirlas con una redirección `>` (un mensaje
  # `git commit -m 'agente -> deny'` no es una escritura).
  r=$(printf '%s' "$c" | sed -E 's/2>>?[[:space:]]*[^|&;[:space:]]*//g; s/[0-9]*>&[0-9-]*//g; s/&>>?[[:space:]]*[^|&;[:space:]]*//g; s#>>?[[:space:]]*/dev/null##g; s/[-=]>//g')
  printf '%s' "$r" | grep -qE '>' && return 0
  return 1
}

# R5-2 (auditoría 2026-10-23): extrae los DESTINOS de escritura del comando (token tras >/>> —no 2>/>&/&>/
# /dev/null ni la flecha ->/=>—, args de tee, el ÚLTIMO arg de cp/mv/ln/install/rsync, dd of=, curl -o,
# wget -O, sponge) y resuelve UN nivel de $VAR/${VAR} por las asignaciones VAR=valor del propio comando.
# Captura `$(...)`/`${...}` como unidad (no se corta en espacios). Lo usa la regla (B) para exigir que el
# nombre del grant esté en el DESTINO, no en cualquier parte: así el nombre en TEXTO (-m/--body), en una
# LECTURA (`cat grant | … > otro`) o en un heredoc NO dispara (FPs de R5-2), mientras la indirección por
# variable/split/glob EN EL DESTINO (R5-1b/indirección) sí.
_destinos_escritura() {
  local c="$1" red dst d vn vv
  red=$(printf '%s' "$c" | sed -E 's/2>>?[[:space:]]*[^|&;[:space:]]*//g; s/[0-9]*>&[0-9-]*//g; s/&>>?[[:space:]]*[^|&;[:space:]]*//g; s#>>?[[:space:]]*/dev/null##g; s/[-=]>//g')
  dst=$(
    printf '%s\n' "$red" | grep -oE '>>?[[:space:]]*(\$\([^)]*\)|[^[:space:]<>|&;]+)' | sed -E 's/^[[:space:]]*>>?[[:space:]]*//'
    printf '%s\n' "$c"   | grep -oE '(^|[^[:alnum:]_/])tee([[:space:]]+-[A-Za-z]+)*[[:space:]]+[^|&;]+' | sed -E 's/.*tee([[:space:]]+-[A-Za-z]+)*[[:space:]]+//'
    printf '%s\n' "$c"   | grep -oE '(^|[^[:alnum:]_/])(cp|mv|ln|install|rsync)[[:space:]][^|&;]+' | awk '{print $NF}'
    printf '%s\n' "$c"   | grep -oE 'of=[^[:space:]|&;]+' | sed 's/^of=//'
    printf '%s\n' "$c"   | grep -oE '(-o|--output)[[:space:]]+[^[:space:]|&;]+' | sed -E 's/^(-o|--output)[[:space:]]+//'
    printf '%s\n' "$c"   | grep -oE '(-O|--output-document)[[:space:]]*=?[[:space:]]*[^[:space:]|&;]+' | sed -E 's/^(-O|--output-document)[[:space:]]*=?[[:space:]]*//'
    printf '%s\n' "$c"   | grep -oE '(^|[^[:alnum:]_/])sponge[[:space:]]+[^[:space:]|&;]+' | sed -E 's/.*sponge[[:space:]]+//'
  )
  printf '%s\n' "$dst" | while IFS= read -r d; do
    [ -n "$d" ] || continue
    case "$d" in
      *'$'[A-Za-z_]*|*'${'*)
        vn=$(printf '%s' "$d" | sed -E 's/.*\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?.*/\1/')
        vv=$(printf '%s' "$c" | grep -oE "(^|[^[:alnum:]_])$vn=[^[:space:];|&<>]+" | head -1 | sed -E "s/.*$vn=//")
        if [ -n "$vv" ]; then printf '%s\n' "$d" | sed -E "s/\\\$\\{?$vn\\}?/$(printf '%s' "$vv" | sed 's/[&/\]/\\&/g')/g"
        else printf '%s\n' "$d"; fi ;;
      *) printf '%s\n' "$d" ;;
    esac
  done
}

# R5-1b (auditoría 2026-10-23): una escritura cuyo DESTINO es un GLOB bajo .../memory/ que PODRÍA expandir al
# archivo de grants — p. ej. `for f in .claude/memory/*.local.md; do … >> $f; done` (el glob alimenta la
# variable de escritura; ni (A) ni las dos-mitades de (B) lo ven). Extrae los tokens `…/memory/<glob>` con
# metacarácter y prueba con `case` si el glob casa el nombre canónico — PERO solo DENY si el glob es SELECTIVO
# para el grant: casa `autorizaciones-vigentes.local.md` y NO casa un archivo de memoria benigno común
# (bitacora.md / estado-proyecto.md). Así `.claude/memory/*.local.md` (casa el grant, no los benignos) → DENY,
# pero un `ls .claude/memory/*.md` junto a una escritura ajena (`*.md` casa TODO) → PASA (no es selectivo).
_glob_memory_casa() {
  local c="$1" tok base
  for tok in $(printf '%s' "$c" | grep -oE '[^[:space:]<>|&;)]*memory/[^[:space:]<>|&;)]*[][*?][^[:space:]<>|&;)]*' 2>/dev/null); do
    base="${tok##*/}"
    case "autorizaciones-vigentes.local.md" in
      $base)
        case "bitacora.md" in $base) continue ;; esac
        case "estado-proyecto.md" in $base) continue ;; esac
        return 0 ;;
    esac
  done
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
# DEFANG primero (R5-1a): el pre-filtro y la detección corren sobre el comando SIN comillas/escapes, para que
# `au''toriz…`/`au\toriz…` no rompan las mitades del nombre. (Antes el pre-filtro corría sobre el CRUDO → una
# comilla intra-palabra lo evadía y el hook early-exiteaba.)
scan=$(_defang "$cmd")

# Pre-filtro barato: el nombre se parte en dos mitades distintivas, `autoriz…` y `…vigentes`. Una indirección
# (variable/glob/split) puede ocultar una mitad, pero rara vez las dos. Si NINGUNA mitad aparece en el texto
# DEFANGED Y tampoco hay un GLOB bajo …/memory/ (que podría expandir al grant sin deletrear ninguna mitad,
# R5-1b) → el comando no puede nombrar el archivo → early-exit. (Residual BAJO: ofuscación que no deja NINGUNA
# mitad NI glob — base64/rev/un script aparte — ver nota en la sección (B).)
if ! printf '%s' "$scan" | grep -qiE 'autoriz|vigentes'; then
  printf '%s' "$scan" | grep -qE 'memory/[^[:space:]<>|&;]*[][*?]' || exit 0
fi

# `scan` es el comando defanged; la detección de abajo opera sobre él (así `>> "autoriz…"` entrecomillado se
# detecta igual). Conservador para un DENY de seguridad: a lo más un `echo '>> autorizaciones-vigentes'`
# (texto literal, caso irreal) daría un FP seguro.
norm="$scan"

# ── (A) VECTORES DIRECTOS: el nombre LITERAL es el destino de una escritura. Mensaje preciso por vector. ──
# 1) Redirección (> o >>, incluye el heredoc `cat > f <<EOF`) cuyo destino contiene el nombre.
printf '%s' "$norm" | grep -qE '>>?[[:space:]]*[^[:space:]<>|&;]*'"$_AUTH_GLOB" \
  && _deny "redirección > / >> hacia el archivo"
# 2) tee (escribe cada archivo-argumento; -a = append).
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])tee([[:space:]]+-[A-Za-z]+)*[[:space:]]+[^|&;]*'"$_AUTH_GLOB" \
  && _deny "tee hacia el archivo"
# 3) sed -i / in-place y dd of= con el archivo como destino. (cp/mv/ln/install/rsync NO van aquí: su nombre
#    puede ser la FUENTE —p. ej. `mv docs/autorizaciones-vigentes-notas.md archivo/`, R5-2 FP— así que su
#    DESTINO lo valida la sección (B) destino-based, que toma el ÚLTIMO arg.)
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])sed[[:space:]]+[^|&;]*-i[^|&;]*'"$_AUTH_GLOB" \
  && _deny "sed -i sobre el archivo"
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])dd([[:space:]]+[^|&;]*)?[[:space:]]of='"[^[:space:]|&;]*$_AUTH_GLOB" \
  && _deny "dd of= hacia el archivo"
# 4) Intérprete que abre el archivo en modo ESCRITURA (python/perl/ruby/node/php) — heurística: el
#    intérprete + el nombre + una señal de escritura (modo w/a, open(...,'w'), .write, >>).
if printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])(python[0-9.]*|perl|ruby|node|php)([[:space:]]|$)'; then
  printf '%s' "$norm" | grep -qE "open\([^)]*$_AUTH_GLOB[^)]*,[^)]*[wa]|$_AUTH_GLOB[^)]*,[^)]*[\"]?[wa]|[wa][\"]?[^)]*$_AUTH_GLOB|\.write|>>[[:space:]]*[^[:space:]]*$_AUTH_GLOB" \
    && _deny "un intérprete abriendo el archivo en modo escritura"
fi
# 5) curl -o/--output y wget -O/--output-document que DESCARGAN al archivo (R5-1c, auditoría 2026-10-23).
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])curl[[:space:]][^|&;]*(-o|--output)[[:space:]]+[^|&;]*'"$_AUTH_GLOB" \
  && _deny "curl -o/--output hacia el archivo"
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])wget[[:space:]][^|&;]*(-O|--output-document)[[:space:]]*=?[[:space:]]*[^|&;]*'"$_AUTH_GLOB" \
  && _deny "wget -O/--output-document hacia el archivo"
# 6) sponge (moreutils) absorbe stdin y ESCRIBE su argumento (R5-1g).
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])sponge[[:space:]]+[^|&;]*'"$_AUTH_GLOB" \
  && _deny "sponge hacia el archivo"
# 7) sed/ed/ex con el comando de ESCRITURA `w <archivo>` (sed 'w f' escribe el patrón a f) (R5-1e).
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])(sed|ed|ex)[[:space:]][^|&;]*[[:space:]]w[[:space:]]+[^|&;]*'"$_AUTH_GLOB" \
  && _deny "sed/ed/ex con el comando de escritura w hacia el archivo"
# 8) git checkout/restore … -- <archivo> SOBRESCRIBE el working file desde otra ref/stash (R5-1f).
printf '%s' "$norm" | grep -qE '(^|[^[:alnum:]_/])git[[:space:]][^|&;]*(checkout|restore)[[:space:]][^|&;]*--[[:space:]]+[^|&;]*'"$_AUTH_GLOB" \
  && _deny "git checkout/restore -- hacia el archivo (sobrescribe el working file)"

# ── (B) INDIRECCIÓN (MEDIO 2026-10-23): una variable/glob/split oculta el DESTINO y los vectores literales de
# (A) NO lo ven — `F=…/autorizaciones-vigentes.local.md; echo x >> $F`, `echo x >> .claude/memory/autoriz*`,
# `n=autorizaciones; echo x >> .claude/memory/$n-vigentes.local.md`, `echo x >> $(ls autoriz*)`. Con el piso de
# la cita ya retirado (una palabra de cualquier mensaje humano basta), esta cadena re-habilita la AUTO-
# AUTORIZACIÓN. REFINADO en R5-2 (auditoría 2026-10-23): la regla opera sobre los DESTINOS de escritura
# (`_destinos_escritura`, con $VAR resuelto) y NO sobre "el nombre en cualquier parte" — antes el nombre en
# TEXTO (`git commit -m 'autoriz => vigentes'`), en una LECTURA (`cat grant | head > otro`) o en un heredoc
# daba un FALSO POSITIVO. Si algún DESTINO (a) reconstruye las DOS mitades (`autoriz…`+`…vigentes`) o (b) usa
# un GLOB pegado a una mitad → DENY. Más `_glob_memory_casa` para el glob SELECTIVO bajo memory/ (R5-1b).
# RESIDUAL BAJO (por la norma de precisión): un `$VAR` sin asignación visible en el MISMO comando (seteado en
# un turno previo), o una ofuscación que no deja ninguna mitad ni glob (base64/rev/script aparte). Los cubren
# la revisión HUMANA del PR y el juez de merge; cerrarlos aquí exigiría ejecutar el comando.
if _tiene_escritura_a_archivo "$norm"; then
  _DST="$(_destinos_escritura "$norm")"
  { printf '%s' "$_DST" | grep -qiE 'autoriz' && printf '%s' "$_DST" | grep -qiE 'vigentes'; } \
    && _deny "escritura cuyo DESTINO reconstruye el nombre del archivo ('autoriz…' + '…vigentes' por variable/split)"
  # Glob pegado a una mitad del nombre EN EL DESTINO — reconoce *, ? y `[` (bracket-glob, R5-1d).
  printf '%s' "$_DST" | grep -qiE '(autoriz|vigentes)[^[:space:]<>|&;]*[][*?]|[][*?][^[:space:]<>|&;]*(autoriz|vigentes)' \
    && _deny "escritura hacia un glob que puede expandir al archivo de grants (autoriz* / *vigentes / [a]utoriz…)"
  # Glob bajo …/memory/ SELECTIVO para el grant aunque no deletree ninguna mitad (R5-1b: `*.local.md`).
  _glob_memory_casa "$norm" \
    && _deny "escritura cuyo destino es un glob SELECTIVO bajo .claude/memory/ que casa el archivo de grants (p. ej. *.local.md)"
fi

exit 0
