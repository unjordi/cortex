# juez-comun.sh — LIB (NO es un hook; se hace `source`). Infraestructura COMÚN de los dos jueces LLM del
# cerebro (confirmar-merge-develop.sh · dod-verificar.sh): retrieval PORTABLE del token OAuth, invocación
# curl a api.anthropic.com que CAPTURA el http_code (con reintento en 401), parseo por centinela y chequeo
# de dependencias. Separar la lógica aquí la hace testeable en aislado y ELIMINA la duplicación que tenían
# ambos jueces — la misma cadena token/curl estaba copiada LITERAL en los dos, y uno hardcodeaba
# `$HOME/.claude/.credentials.json` IGNORANDO `CLAUDE_CONFIG_DIR`. Mismo patrón que analizar-comando-git.sh
# ↔ los git-guards (lib `both/lib`, sin cableado ni dedupe: cada juez sourcea la copia que está JUNTO a él).
# bash-3.2-safe. NUNCA loguea el valor del token (solo lo usa en el header Authorization).
# shellcheck shell=bash
#
# ── CONTRATO DE FAIL-SAFE (definición ÚNICA — la lib NO decide el fail-safe, solo lo REPORTA) ──────────
# La lib PRODUCE texto + un ESTADO; JAMÁS inventa un veredicto. Cada juez aplica SU política ante fallo.
#   · `_juez_token` / `_juez_llamar_api` devuelven VACÍO ante: sin token en ningún canal · sin curl/jq ·
#     sin red · timeout · HTTP != 200 (incluido 401/403 tras agotar el reintento) · respuesta sin cuerpo.
#   · La RAZÓN del vacío se comunica en la global `_JUEZ_ESTADO`, con estos valores (3 de indisponibilidad
#     + el OK). Es el insumo para que CADA juez elija su MENSAJE (no su fail-safe, que es fijo por juez):
#       OK                   → hubo respuesta 200 con cuerpo (el texto va en stdout).
#       UNAVAILABLE_NOTOKEN  → NO hay token OAuth en NINGÚN canal (colega/CI/api-key/sin login de suscripción).
#       UNAVAILABLE_NET      → deps ausentes · red/timeout/DNS · HTTP != 200 no-auth · cuerpo vacío.
#       EXPIRED              → 401/403 en el 1er intento Y TAMBIÉN tras el reintento (token vencido/revocado).
#   · POLÍTICA por juez (vive en CADA juez, no aquí — codificar el fail-safe en la lib acoplaría seguridad
#     a mecánica). RESUMEN del contrato, para que quede en UN solo lugar:
#       merge (confirmar-merge-develop) = fail-CLOSED: vacío/UNAVAILABLE_* → DENY. El estado solo cambia el
#              MENSAJE: NOTOKEN → DENY + redirección al carril de la WEB de GitLab (o `claude setup-token`);
#              EXPIRED → DENY + "reintenta, el CLI refresca el token solo"; NET → DENY genérico. SIEMPRE DENY.
#       dod (dod-verificar)             = fail-OPEN: vacío/UNAVAILABLE_* → exit 0 (es un NAG de disciplina,
#              no un candado de seguridad; bloquear cada Stop sin juez atraparía al usuario en un loop).
# NINGÚN cambio de esta lib afloja un fail-safe: el reintento en 401 solo REDUCE los falsos DENY por token
# STALE (el CLI refresca el keychain en el ínterin) — el veredicto ante un fallo GENUINO no cambia.

# _juez_dir → directorio de config de Claude, HONRANDO CLAUDE_CONFIG_DIR (homologado con claude-brain-fetch,
# el getter del widget). ARREGLA el hardcode `$HOME/.claude` de los jueces viejos → portable si el dev movió
# su config a otra ruta.
_juez_dir() { printf '%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }

# ── Canales de retrieval del token, uno por fuente. Cada uno imprime el token (o nada) + return != 0 si falla.
_juez_token_de_llavero() {          # macOS: el token vive en el llavero (única fuente viva en una Mac típica)
  command -v security >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
    | jq -er '.claudeAiOauth.accessToken // empty' 2>/dev/null
}
_juez_token_de_archivo() {          # Linux / Windows-gitbash / macOS-sin-llavero: credentials.json en texto
  local f
  f="$(_juez_dir)/.credentials.json"
  [ -r "$f" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -er '.claudeAiOauth.accessToken // empty' "$f" 2>/dev/null
}
_juez_token_de_env()  { [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && printf '%s' "$CLAUDE_CODE_OAUTH_TOKEN"; }

# _juez_token → retrieval PORTABLE, LOGIN-ACTIVO-FIRST (llavero → archivo → env). Homologado con el getter
# del widget (claude-brain-fetch, tras fix/token-login-activo-primero): el canal VIVO (llavero/archivo)
# auto-rota en cada `claude login` → nunca queda pineado a una cuenta/expiración vieja; el env es la RED DE
# SEGURIDAD headless (colega sin llavero, CI). Imprime el token en stdout, o vacío + return 1. NO loguea el valor.
_juez_token() {
  local t
  t="$(_juez_token_de_llavero)"  && [ -n "$t" ] && { printf '%s' "$t"; return 0; }
  t="$(_juez_token_de_archivo)"  && [ -n "$t" ] && { printf '%s' "$t"; return 0; }
  t="$(_juez_token_de_env)"      && [ -n "$t" ] && { printf '%s' "$t"; return 0; }
  return 1
}

# _juez_deps_ok → curl + jq disponibles. return 0/1.
_juez_deps_ok() { command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; }

# _juez_centinela $texto $regex-ERE → el ÚLTIMO match del centinela (tail -1). Reusa el parseo que estaba
# duplicado en ambos jueces; el caller normaliza (ALLOW/DENY vs si/no) sobre esta salida cruda.
_juez_centinela() { printf '%s' "$1" | grep -oiE "$2" 2>/dev/null | tail -1; }

# _juez_curl_crudo $token $body $timeout → stdout: <cuerpo-de-la-respuesta>\n<http_code>. El `-w` de curl
# ANEXA el código HTTP en su propia línea final → el caller separa cuerpo (sed '$d') de código (tail -n1),
# distinguiendo un 401 (token rechazado) de una caída de red (código 000 / vacío). NUNCA loguea el token.
_juez_curl_crudo() {
  curl -sS -m "$3" -w '\n%{http_code}' https://api.anthropic.com/v1/messages \
    -H "Authorization: Bearer $1" -H "anthropic-beta: oauth-2025-04-20" \
    -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
    -d "$2" 2>/dev/null
}

# _juez_llamar_api $modelo $max_tokens $timeout $temperature $prompt
#   → stdout: PRIMERA línea = ESTADO (OK|UNAVAILABLE_NOTOKEN|UNAVAILABLE_NET|EXPIRED); RESTO = el TEXTO del
#     assistant (content[0].text) en OK, o vacío ante fallo. El caller hace `head -1`=estado, `sed '1d'`=texto.
#   → TAMBIÉN setea la global `_JUEZ_ESTADO` (conveniencia para una llamada DIRECTA/test; NO sobrevive un
#     `$(...)`). Por eso el ESTADO viaja en stdout: un caller que hace `resp=$(_juez_llamar_api …)` (subshell)
#     recupera el estado de la línea 1 — el global se perdería en ese subshell. Retorno: 0 en OK, !=0 en fallo.
# CAPTURA el http_code y REINTENTA 1× ante 401/403 re-resolviendo el token del canal VIVO (el CLI refresca el
# keychain en el ínterin) — casi gratis (~5ms: el 401 falla rápido) y NO cambia el veredicto, solo reduce el
# falso DENY por token stale. Un solo re-try (sin bucle).
_juez_llamar_api() {
  local modelo="$1" maxtok="$2" timeout="$3" temp="$4" prompt="$5" tok body resp http body_txt txt est rc
  est=UNAVAILABLE_NET; txt=""; rc=1
  if ! _juez_deps_ok; then
    est=UNAVAILABLE_NET
  elif ! tok="$(_juez_token)" || [ -z "$tok" ]; then
    est=UNAVAILABLE_NOTOKEN
  else
    case "$temp"    in ''|*[!0-9.]*) temp=0 ;; esac
    case "$maxtok"  in ''|*[!0-9]*)  maxtok=512 ;; esac
    case "$timeout" in ''|*[!0-9]*)  timeout=20 ;; esac
    body=$(jq -n --arg m "$modelo" --arg p "$prompt" --argjson mt "$maxtok" --argjson t "$temp" \
            '{model:$m, max_tokens:$mt, temperature:$t, messages:[{role:"user",content:$p}]}' 2>/dev/null)
    if [ -z "$body" ]; then
      est=UNAVAILABLE_NET
    else
      resp="$(_juez_curl_crudo "$tok" "$body" "$timeout")"
      http="$(printf '%s' "$resp" | tail -n1)"; body_txt="$(printf '%s' "$resp" | sed '$d')"
      if [ "$http" = 200 ]; then
        txt=$(printf '%s' "$body_txt" | jq -r '.content[0].text // empty' 2>/dev/null); est=OK; rc=0
      elif [ "$http" = 401 ] || [ "$http" = 403 ]; then
        # 401/403 = token RECHAZADO (probable expiración): re-resolver del canal VIVO y reintentar 1×.
        tok="$(_juez_token)" || tok=""
        if [ -n "$tok" ]; then
          resp="$(_juez_curl_crudo "$tok" "$body" "$timeout")"
          http="$(printf '%s' "$resp" | tail -n1)"; body_txt="$(printf '%s' "$resp" | sed '$d')"
        fi
        if [ "$http" = 200 ]; then
          txt=$(printf '%s' "$body_txt" | jq -r '.content[0].text // empty' 2>/dev/null); est=OK; rc=0
        elif [ "$http" = 401 ] || [ "$http" = 403 ]; then est=EXPIRED        # sigue rechazado → vencido de verdad
        else est=UNAVAILABLE_NET; fi                                          # otro código tras el retry → red
      else
        est=UNAVAILABLE_NET   # curl falló (http vacío/000) o HTTP != 200 no-auth → red/servidor/timeout
      fi
    fi
  fi
  _JUEZ_ESTADO="$est"
  printf '%s\n%s' "$est" "$txt"
  return "$rc"
}
