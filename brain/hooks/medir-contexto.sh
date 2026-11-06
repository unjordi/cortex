#!/usr/bin/env bash
# medir-contexto.sh — MEDICIÓN ÚNICA del llenado de contexto, compartida por aviso-contexto (PostToolUse) y
# forzar-checkpoint (Stop). Una sola fuente → los dos hooks miden IDÉNTICO (no pueden divergir).
#
# mc_medir <transcript> <root> → setea las globales y devuelve:
#   0 = MEDIBLE: mc_ctx (tokens de contexto del último usage, anclado al último /compact), mc_window (ventana
#       del modelo por EVIDENCIA), mc_acw (autoCompactWindow o "no seteado"), mc_ac_enabled (true/false),
#       mc_gov (ventana GOBERNANTE = punto REAL de compact), mc_govsrc (acw|model).
#   1 = FAIL-OPEN: sin jq, sin transcript, sin usage fresco (post-compact), o sin ventana por evidencia
#       (modelo desconocido/<synthetic>) → el llamador NO actúa (silencio), NUNCA inventa una ventana.
# No lee stdin ni escribe sellos: es cálculo puro. El throttle/estado por banda lo lleva cada hook.

mc_medir() {
  local tp="$1" root="$2" s m e acw_num forced model tpm
  mc_ctx=""; mc_window=""; mc_acw="no seteado"; mc_ac_enabled=true; mc_gov=""; mc_govsrc="model"; mc_acw_num=""
  command -v jq >/dev/null 2>&1 || return 1
  { [ -n "$tp" ] && [ -f "$tp" ]; } || return 1

  # Tokens de contexto ACTUALES = último `usage`, ANCLADO al último /compact. Un isCompactSummary:true RESETEA
  # el acumulado (el usage grande PRE-compact no se cuela). Sidechain (subagente) NO cuenta al hilo principal.
  mc_ctx=$(tail -n 400 "$tp" 2>/dev/null | jq -rRn '
      reduce (inputs | fromjson?) as $o (null;
          if   ($o.isCompactSummary == true) then null
          elif ($o.isSidechain == true)      then .
          elif ($o.message.usage)            then ($o.message.usage
                | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
          else . end)
      // empty
    ' 2>/dev/null | tr -cd '0-9')
  [ -n "$mc_ctx" ] || return 1

  # Ventana del MODELO: SOLO por EVIDENCIA — override AVISO_CONTEXTO_WINDOW_TOKENS, marcador "[1m]", o un modelo
  # con ventana real LISTADA. Precedencia settings: user < proyecto < local; el modelo de RUNTIME del transcript
  # (.message.model, saltando "<…>") GANA sobre settings. Desconocido/<synthetic> → sin ventana (fail-open).
  mc_window="${AVISO_CONTEXTO_WINDOW_TOKENS:-}"
  case "$mc_window" in
    ''|*[!0-9]*)
      model=""
      for s in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" "$root/.claude/settings.json" "$root/.claude/settings.local.json"; do
        [ -f "$s" ] || continue
        m=$(jq -r '.model // empty' "$s" 2>/dev/null)
        [ -n "$m" ] && model="$m"
      done
      tpm=$(tail -n 400 "$tp" 2>/dev/null | jq -rRn '
          reduce (inputs | fromjson?) as $o (null;
              if ($o.isSidechain == true) then .
              else (($o.message.model // $o.model) as $m
                    | if ($m != null and ($m | startswith("<") | not)) then $m else . end)
              end)
          // empty' 2>/dev/null)
      [ -n "$tpm" ] && model="$tpm"
      case "$model" in
        *'[1m]'*)                                                       mc_window=1000000 ;;
        *opus-4-7*|*opus-4-8*|*opus-5*|*sonnet-5*|*fable-5*|*mythos-5*) mc_window=1000000 ;;
        *)                                                              mc_window="" ;;
      esac
      ;;
  esac
  case "$mc_window" in ''|*[!0-9]*) return 1 ;; esac
  # AUTO-CORRECCIÓN por invariante FÍSICO: si ctx > ventana detectada, promueve a 1M.
  [ "$mc_ctx" -gt "$mc_window" ] 2>/dev/null && mc_window=1000000

  # autoCompactWindow (user < proyecto < local).
  for s in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" "$root/.claude/settings.json" "$root/.claude/settings.local.json"; do
    [ -f "$s" ] || continue
    acw=$(jq -r '.autoCompactWindow // empty' "$s" 2>/dev/null)
    [ -n "$acw" ] && mc_acw="$acw"
  done

  # autoCompactEnabled: default true; solo `false` explícito (o DISABLE_AUTO_COMPACT) desactiva. user<proyecto<local.
  for s in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" "$root/.claude/settings.json" "$root/.claude/settings.local.json"; do
    [ -f "$s" ] || continue
    e=$(jq -r 'if .autoCompactEnabled == null then empty else (.autoCompactEnabled|tostring) end' "$s" 2>/dev/null)
    [ -n "$e" ] && mc_ac_enabled="$e"
  done
  case "${DISABLE_AUTO_COMPACT:-}" in ''|0|false|FALSE|no|NO) : ;; *) mc_ac_enabled=false ;; esac

  # VENTANA GOBERNANTE (GOV) = el punto REAL de compact. ACW cuando el auto-compact está ACTIVO y ACW es número
  # válido; si no (no seteado / desactivado / override manual), la ventana del modelo.
  acw_num=""
  case "$mc_acw" in ''|*[!0-9]*) : ;; *) [ "$mc_acw" -gt 0 ] 2>/dev/null && acw_num="$mc_acw" ;; esac
  mc_acw_num="$acw_num"
  forced=""
  case "${AVISO_CONTEXTO_WINDOW_TOKENS:-}" in ''|*[!0-9]*) : ;; *) forced=1 ;; esac
  mc_gov="$mc_window"; mc_govsrc="model"
  if [ -z "$forced" ] && [ "$mc_ac_enabled" = "true" ] && [ -n "$acw_num" ]; then
    mc_gov="$acw_num"; mc_govsrc="acw"
  fi
  return 0
}
