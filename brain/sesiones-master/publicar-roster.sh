#!/usr/bin/env bash
# publicar-roster.sh — publica el masters.json LOCAL (hand-curado) + los respaldos de sesiones al FOLDER
# de sync configurado (Drive/iCloud/…), para que el roster y las sesiones VIAJEN entre máquinas.
#
# Opción A (Jordi, 2026-10-14): el hook de export YA NO escribe un masters.json compartido (generaba
# conflictos de sync de Drive entre masters concurrentes). La propagación se hace AQUÍ, por-host y sin
# colisión: el `~/.claude/masters.json` local se publica como `masters-<host>.json` en el folder, y
# `seed.sh` une todos los `masters-*.json` en la otra máquina.
#
# Lo INVOCA cada WIDGET de cuota en su ciclo de chequeo de versión ("que en los ciclos de actualización del
# widget … copie el masters.json Y los respaldos de sesiones ahí mencionados al folder que tenga
# configurado" — Jordi). Una SOLA implementación (este script), que los 3 widgets llaman — en vez de
# duplicar la copia en Swift/C#/QML (3× superficie, 3× drift). Nota de diseño: acopla el disparo al ciclo
# del widget de cuota; es deliberado (el widget es el proceso periódico que ya corre en cada máquina).
#
# FOLDER destino (el "configurado"): $CLAUDE_SESSIONS_DRIVE si está en el entorno; si no (el widget GUI no
# hereda el shell), la 1ª línea de `~/.claude/sessions-drive`. Sin ninguno → no hay a dónde publicar → sale.
#
# CONTRATO: SILENCIOSO, FAIL-OPEN, IDEMPOTENTE. Nunca rompe nada (siempre exit 0). Copias ATÓMICAS
# (tmp+rename) para el json; los .gz/.meta solo se recopian si el destino falta o es más viejo (no re-subir
# cientos de MB en balde). Override del origen de sesiones: $CLAUDE_SESSIONS_LOCAL (default ~/.claude-sessions).
set -u

# ── folder destino (el "configurado") ──────────────────────────────────────────────────────────────
DEST="${CLAUDE_SESSIONS_DRIVE:-}"
if [ -z "$DEST" ] && [ -f "$HOME/.claude/sessions-drive" ]; then
  DEST="$(head -n1 "$HOME/.claude/sessions-drive" 2>/dev/null | tr -d '\r')"
fi
[ -n "$DEST" ] && [ -d "$DEST" ] || exit 0   # sin folder configurado / inexistente → nada que publicar

# ── host-key sanitizado (para que dos máquinas no colisionen su masters-<host>.json en el folder) ────
HOST="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo host)"
HOST="$(printf '%s' "$HOST" | tr -c 'A-Za-z0-9._-' '_')"
[ -n "$HOST" ] || HOST=host

# ── 1) el masters.json LOCAL hand-curado → masters-<host>.json en el folder (copia ATÓMICA) ─────────
LOCAL="$HOME/.claude/masters.json"
if [ -f "$LOCAL" ]; then
  tmp="$DEST/.masters-$HOST.json.tmp.$$"
  if cp -f "$LOCAL" "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$DEST/masters-$HOST.json" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  else
    rm -f "$tmp" 2>/dev/null || true
  fi
fi

# ── 2) respaldos de sesiones (.gz + .meta) → el folder ──────────────────────────────────────────────
# CON masters.json local: SOLO las sesiones que LISTA ("los respaldos de sesiones ahí mencionados" — Jordi); un *-master
# no listado NO viaja. SIN masters.json local (aún no curado): FALLBACK a TODAS las sesiones exportadas
# localmente (derivadas de los metas), para NO apagar EN SILENCIO el resume cross-máquina mientras no exista
# el roster curado — migración suave (claudio); `/despertar-master --curar` siembra el roster y de ahí en más
# filtra. El roster MANDA cuando existe. Ids por grep (uuids; sin dependencia de jq). Solo copia lo más nuevo.
SRC="${CLAUDE_SESSIONS_LOCAL:-$HOME/.claude-sessions}"
if [ -d "$SRC" ] && [ "$SRC" != "$DEST" ]; then
  if [ -f "$LOCAL" ]; then
    ids=$(grep -oE '"id"[[:space:]]*:[[:space:]]*"[^"]+"' "$LOCAL" 2>/dev/null | sed -E 's/.*"([^"]+)"[[:space:]]*$/\1/')
  else
    ids=$(for m in "$SRC"/*.meta.json; do [ -f "$m" ] && basename "$m" .meta.json; done)   # fallback: todo lo exportado
  fi
  for id in $ids; do
    [ -n "$id" ] || continue
    for ext in jsonl.gz meta.json; do
      f="$SRC/$id.$ext"
      [ -f "$f" ] || continue
      if [ ! -f "$DEST/$id.$ext" ] || [ "$f" -nt "$DEST/$id.$ext" ]; then
        cp -f "$f" "$DEST/$id.$ext" 2>/dev/null || true
      fi
    done
  done
fi
exit 0
