#!/usr/bin/env bash
# Lib compartida: la ruta del dir de estado per-repo del cerebro (sellos de throttle/dedupe), FUERA del repo.
# Una sola definición para los hooks que escriben sellos (aviso-contexto, limpiar-impl-ramas) y sus tests,
# para que no driften. No crea el dir; solo lo calcula.

# cortex_state_dir <root> -> ${CLAUDE_CONFIG_DIR:-~/.claude}/state/<cksum del root>
# <root> es el mismo valor que el hook usa como ROOT (CLAUDE_PROJECT_DIR o `git rev-parse --show-toplevel`):
# el cksum se calcula sobre esa cadena, así que el llamador debe pasar el mismo root para casar la ruta.
cortex_state_dir() {
  printf '%s/state/%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" \
    "$(printf '%s' "$1" | cksum 2>/dev/null | awk '{print $1}')"
}
