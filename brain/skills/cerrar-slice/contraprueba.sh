#!/usr/bin/env bash
# contraprueba.sh --base <ref> --cmd '<comando de pruebas>' [--repo <dir>] -- <archivo de prueba>...
# Corre las pruebas dadas contra el código de <ref>: monta un worktree temporal de <ref>, copia encima los archivos de
# prueba tal como están en el árbol de trabajo y ejecuta <comando> en él. Una prueba nueva tiene que FALLAR contra la
# base (skill estandar-pruebas §1); si pasa, no separa el código viejo del nuevo.
# Sale 0 si el comando falla contra la base (contraprueba presente; imprime la cola de la salida para citarla),
# 1 si pasa contra la base, 2 por error de uso o de montaje. El worktree temporal se borra al salir.
set -uo pipefail

uso() { echo "[contraprueba] uso: contraprueba.sh --base <ref> --cmd '<comando>' [--repo <dir>] -- <archivo>..." >&2; exit 2; }

BASE="" CMD="" REPO="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 || uso ;;
    --cmd)  CMD="${2:-}";  shift 2 || uso ;;
    --repo) REPO="${2:-}"; shift 2 || uso ;;
    --) shift; break ;;
    *) uso ;;
  esac
done
[[ -n "$BASE" && -n "$CMD" && $# -gt 0 ]] || uso

RAIZ="$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)" || { echo "[contraprueba] $REPO no es un repo de git." >&2; exit 2; }
COMMIT="$(git -C "$RAIZ" rev-parse --verify --quiet "${BASE}^{commit}")" || { echo "[contraprueba] no existe la base '$BASE'." >&2; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/contraprueba.XXXXXX")"
WT="$TMP/base"
limpiar() { git -C "$RAIZ" worktree remove --force "$WT" >/dev/null 2>&1; rm -rf "$TMP"; }
trap limpiar EXIT

git -C "$RAIZ" worktree add --quiet --detach "$WT" "$COMMIT" >/dev/null 2>&1 \
  || { echo "[contraprueba] no pude montar el worktree de $BASE." >&2; exit 2; }

for f in "$@"; do
  rel="${f#"$RAIZ"/}"
  [[ -f "$RAIZ/$rel" ]] || { echo "[contraprueba] no existe el archivo de prueba '$f' en el árbol de trabajo." >&2; exit 2; }
  mkdir -p "$WT/$(dirname "$rel")"
  cp "$RAIZ/$rel" "$WT/$rel"
done

( cd "$WT" && bash -c "$CMD" ) > "$TMP/salida" 2>&1
rc=$?
if [[ $rc -eq 0 ]]; then
  echo "[contraprueba] PASA contra $BASE ($COMMIT): la prueba no separa el código viejo del nuevo."
  exit 1
fi
echo "[contraprueba] FALLA contra $BASE ($COMMIT), rc=$rc. Cola de la salida (cítala y comprueba que falla el aserto, no el montaje):"
tail -n 15 "$TMP/salida" | sed 's/^/  /'
exit 0
