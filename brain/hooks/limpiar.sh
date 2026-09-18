#!/usr/bin/env bash
# limpiar.sh — DISPATCHER único de los barridos de higiene del cerebro. Consolida (2026-09-17) los
# ejecutables sueltos que antes se invocaban cada uno por su propio nombre — limpiar-ramas.sh,
# limpiar-worktrees.sh, limpiar-residuo.sh, barrer-flotilla-cerebro.sh (retirados, ver MANIFEST) — en
# UN entrypoint: `limpiar.sh <subcomando> [args…]`. La LÓGICA de cada barrido no cambió una sola línea
# (renombrados con `git mv`, historia intacta); solo el punto de entrada es nuevo.
#
#   USO   limpiar.sh ramas      [--dry-run] [--no-fetch] …   (antes limpiar-ramas.sh)
#         limpiar.sh worktrees  [--dry-run] …                (antes limpiar-worktrees.sh)
#         limpiar.sh residuo    [--dry-run] [--dias-backups=N] …  (antes limpiar-residuo.sh)
#         limpiar.sh flotilla   [--dry-run] [--code-dir D] …      (antes barrer-flotilla-cerebro.sh)
#
# Quien antes invocaba el ejecutable suelto ahora llama `limpiar.sh <subcomando>` con los MISMOS flags
# (se reenvían tal cual, `"$@"` después de consumir el subcomando). Los 4 `limpiar-impl-*.sh` de al lado
# son implementación interna — no los invoques directo; usa este dispatcher.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

_uso() {
  cat <<'USO'
limpiar.sh — dispatcher de los barridos de higiene del cerebro.

  limpiar.sh ramas      [flags…]   barre ramas LOCALES ya integradas (squash-safe)
  limpiar.sh worktrees  [flags…]   barre worktrees de ramas ya integradas
  limpiar.sh residuo    [flags…]   barre residuo de housekeeping por EDAD (backups, logs, cachés)
  limpiar.sh flotilla   [flags…]   sweeper batch de N repos de la flotilla (corre residuo al final)

Cada subcomando reenvía sus flags tal cual al `limpiar-impl-<subcomando>.sh` correspondiente —
consulta su propio --help si lo trae.
USO
}

sub="${1:-}"
[ $# -gt 0 ] && shift

case "$sub" in
  ramas)      exec bash "$SCRIPT_DIR/limpiar-impl-ramas.sh" "$@" ;;
  worktrees)  exec bash "$SCRIPT_DIR/limpiar-impl-worktrees.sh" "$@" ;;
  residuo)    exec bash "$SCRIPT_DIR/limpiar-impl-residuo.sh" "$@" ;;
  flotilla)   exec bash "$SCRIPT_DIR/limpiar-impl-flotilla.sh" "$@" ;;
  -h|--help|'') _uso; [ -z "$sub" ] && exit 2 || exit 0 ;;
  *) printf 'limpiar.sh: subcomando desconocido: %s (usa --help)\n' "$sub" >&2; exit 2 ;;
esac
