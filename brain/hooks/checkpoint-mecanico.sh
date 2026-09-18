#!/usr/bin/env bash
# checkpoint-mecanico.sh — hook de PreCompact (tier GLOBAL). Dispara el andamio MECÁNICO del checkpoint
# en el momento exacto del compact (M2/X2, auditoría "mudanza de master · checkpoint/compactación",
# 2026-09-11).
#
# EL HALLAZGO (X2): PreCompact YA es un hook VIVO y cableado (lo prueba `exportar-sesion-master.sh`, que
# corre en el MISMO evento con el MISMO transcript_path) — y hoy en ese evento el cerebro guarda los
# BYTES del transcript (gzip) y tira el SIGNIFICADO. Este hook saca, ADEMÁS, el andamio del checkpoint:
# el 🗂️ árbol de archivos tocados, los mensajes de `git commit`, las citas textuales del usuario y las
# métricas de sesión — TODO mecánico, CERO tokens de modelo (`bin/checkpoint-mecanico.js`).
#
# Por qué PreCompact: es el punto donde el cerebro sabe, con certeza, que la ventana se está por perder
# AHORA. Su HERMANO PROACTIVO es aviso-contexto.sh (PostToolUse): al cruzar el umbral ALTO — ANTES de que
# el auto-compact corte — dispara el MISMO volcado. Ambos comparten el lanzador (checkpoint-mecanico-comun.sh)
# y el mismo lock por-sid → coordinan sin solaparse ni corromper el andamio.
#
# LO QUE ESTE HOOK *NO* HACE (decisión explícita, no olvido): NO invoca `claude -p --resume` ni ningún
# otro modelo. Eso es la vía-1 del dictamen (viable pero cuesta dinero y pasa por `delegacion-gate`) —
# fuera de alcance. Este hook solo corre el extractor MECÁNICO (vía-3): el juicio (en qué estamos,
# decisión abierta, siguiente paso) lo sigue poniendo el modelo vivo, ahora con el andamio ya escrito.
#
# CONTRATO: SILENCIOSO y FAIL-OPEN (el lanzador nunca bloquea el compact ni el turno). Detached
# (nohup … &) para no morir con un transcript grande. TODA la mecánica (localizar el extractor, lock
# por-sid, escritura atómica, anti-recursión) vive en la lib checkpoint-mecanico-comun.sh — una sola
# definición compartida con aviso-contexto.sh, sin drift.
set -u

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat 2>/dev/null || true)
sid=$(printf '%s'   "$input" | jq -r '.session_id // empty'      2>/dev/null)
tpath=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
cwd=$(printf '%s'   "$input" | jq -r '.cwd // empty'             2>/dev/null)

ROOT="${CLAUDE_PROJECT_DIR:-${cwd:-$(pwd)}}"
MEM="$ROOT/.claude/memory"

_selfdir="$(dirname "$0")"
# shellcheck source=checkpoint-mecanico-comun.sh
[ -f "$_selfdir/checkpoint-mecanico-comun.sh" ] || exit 0   # sin la lib → fail-open silencioso
. "$_selfdir/checkpoint-mecanico-comun.sh"

disparar_checkpoint_mecanico "$sid" "$tpath" "$ROOT" "$MEM" "$_selfdir"
exit 0
