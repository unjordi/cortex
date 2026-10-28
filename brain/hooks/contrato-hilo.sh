#!/usr/bin/env bash
# contrato-hilo.sh — LIB (tier global). El CONTRATO entre quien ESCRIBE el hilo (el skill `checkpoint`)
# y quien lo LEE (`rehidratar-hilo.sh`). UNA sola definición del footer de metadatos y de la fecha.
#
# POR QUÉ EXISTE: el footer `> Última actualización: <fecha> · rama <rama> · nivel <x>` es un contrato
# REAL — `rehidratar-hilo.sh` decide con él si el hilo está vigente o si lo degrada a "⚠️ POSIBLEMENTE
# OBSOLETO", y la skill `checkpoint` lo prescribe en su plantilla. Sin footer el gate de rama no puede
# dispararse, cae al proxy de 12h y un hilo vigente se presenta como obsoleto; esta lib lo verifica.
#
# La lib es la mitad "una sola definición": el lector la SOURCEA (en vez de re-escribir el regex) y el
# escritor la puede correr como verificación de su propio volcado. Que el regex viva en un solo lado es
# lo que impide que escritor y lector deriven — la misma clase de falla que el candado de
# `reubicar-master` combate exigiendo el preludio byte a byte.
#
# API (todo read-only; ninguna función escribe ni un byte):
#   hilo_rama <archivo>          → imprime la rama del footer ("" si no hay)
#   hilo_fecha <archivo>         → imprime la 1a fecha ISO del archivo ("" si no hay)
#   hilo_edad_legible <segundos> → "2d 5h" / "3h 20m" / "45m"
#   verificar_hilo <archivo> [fresco] → exit 0 si cumple el contrato; 1 e imprime los motivos. Con un 2º
#                                  arg NO-vacío ("fresco") ADEMÁS exige que el archivo se haya ESCRITO en
#                                  ESTE volcado (mtime < CONTRATO_HILO_FRESCO_MIN, def 10 min) y que el §SIGUIENTE
#                                  quepa en el preview (≤ CONTRATO_HILO_SIGUIENTE_MAX, def 900 B): el camino del
#                                  ESCRITOR/checkpoint, para cazar un Write que falló y dejó el hilo VIEJO.
#
# CONTRATO DE USO: fail-open en el LECTOR (un hilo sin footer se lee igual, solo pierde el gate de rama),
# fail-LOUD en el ESCRITOR (el checkpoint SÍ debe enterarse de que su volcado nace inauditable).

# La rama del footer de metadatos. ANCLADA al separador `·` a propósito — es la misma extracción que
# `rehidratar-hilo.sh` usaba inline, y cierra sus dos bugs históricos:
#   (1) un `.*[Rr]ama` goloso consumía hasta el "rama" de una SUBCADENA (`feat/diagrama-x` → `-x`), y
#   (2) una línea de PROSA con "de rama X" no son metadatos (la prosa no lleva `· rama`).
# Una rama de git no tiene espacios; `tr` limpia el markdown (`· rama \`<x>\``).
hilo_rama() {
  [ -f "${1:-}" ] || return 0
  grep -E '·[[:space:]]+[Rr]ama[[:space:]]' "$1" 2>/dev/null | head -n1 \
    | sed -E 's/.*·[[:space:]]+[Rr]ama[[:space:]]+//' | awk '{print $1}' | tr -d '`*"'
}

# La fecha ABSOLUTA (ISO) del volcado. "hoy"/"ayer" no son fechas: al releerse tras un corte, una fecha
# relativa miente sobre su propia antigüedad.
hilo_fecha() {
  [ -f "${1:-}" ] || return 0
  grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$1" 2>/dev/null | head -n1
}

# Edad en prosa corta, para que el encabezado del rehidratado diga el DATO y no solo un veredicto.
hilo_edad_legible() {
  _s="${1:-0}"
  case "$_s" in ''|*[!0-9]*) printf 'edad desconocida'; return 0 ;; esac
  _d=$(( _s / 86400 )); _h=$(( (_s % 86400) / 3600 )); _m=$(( (_s % 3600) / 60 ))
  if   [ "$_d" -gt 0 ]; then printf '%sd %sh' "$_d" "$_h"
  elif [ "$_h" -gt 0 ]; then printf '%sh %sm' "$_h" "$_m"
  else                       printf '%sm' "$_m"; fi
}

# El verificador. Lo corre el skill `checkpoint` tras volcar (fail-LOUD) y `test-brain.sh` sobre fixtures.
# NO juzga el CONTENIDO del hilo (eso es criterio del modelo): solo que sea AUDITABLE por su lector.
verificar_hilo() {
  _f="${1:-}"
  _fresco="${2:-}"   # no-vacío (p. ej. "fresco") → ADEMÁS exige que el archivo se haya ESCRITO en ESTE volcado
  _fallos=0
  if [ ! -f "$_f" ]; then
    printf 'CONTRATO-HILO: no existe el archivo: %s\n' "$_f" >&2
    return 1
  fi
  if [ -z "$(hilo_rama "$_f")" ]; then
    printf 'CONTRATO-HILO: %s SIN footer "· rama <x>" ⇒ rehidratar-hilo NO puede usar el gate de rama y\n' "$_f" >&2
    printf '  caerá al proxy de 12h: un hilo VIGENTE se presentará como "⚠️ POSIBLEMENTE OBSOLETO".\n' >&2
    printf '  Arreglo: la 2a línea del hilo va como "> Última actualización: <AAAA-MM-DD> · rama <rama> · nivel <ligero|COMPLETO>".\n' >&2
    _fallos=$((_fallos+1))
  fi
  if [ -z "$(hilo_fecha "$_f")" ]; then
    printf 'CONTRATO-HILO: %s SIN fecha ABSOLUTA (AAAA-MM-DD) ⇒ al releerlo no se puede juzgar su antigüedad.\n' "$_f" >&2
    _fallos=$((_fallos+1))
  fi
  # FRESCURA (solo si el caller lo pide — el camino del ESCRITOR/checkpoint): el footer con rama + fecha del
  # MISMO día PASA aunque el Write del checkpoint haya FALLADO y en disco quede el hilo de hace horas (caso real
  # cps-master 2026-10-21: Write "Error writing file", el hilo quedó de las 13:42, verificar_hilo dio rc=0 y la
  # sesión anotó un "checkpoint COMPLETO" que no existió). El escritor debe enterarse (fail-LOUD): si el archivo
  # NO se escribió recién, su volcado no ocurrió. El LECTOR (rehidratar-hilo) NO pasa el flag — ahí el hilo es
  # legítimamente viejo (de otra sesión). stat GNU `-c` primero, BSD `-f` de fallback (mismo patrón que la lib git).
  if [ -n "$_fresco" ]; then
    _mt=$(stat -c %Y "$_f" 2>/dev/null || stat -f %m "$_f" 2>/dev/null)
    _now=$(date +%s 2>/dev/null)
    _max="${CONTRATO_HILO_FRESCO_MIN:-10}"
    case "$_max" in ''|*[!0-9]*) _max=10 ;; esac
    if [ -n "$_mt" ] && [ -n "$_now" ] && [ "$(( (_now - _mt) / 60 ))" -ge "$_max" ]; then
      printf 'CONTRATO-HILO: %s NO se escribió en ESTE volcado — su mtime es de hace %s (≥ %s min).\n' "$_f" "$(hilo_edad_legible $((_now - _mt)))" "$_max" >&2
      printf '  ⇒ el Write del checkpoint pudo FALLAR y quedó el hilo VIEJO. NO declares el checkpoint hecho:\n' >&2
      printf '  re-escribe el hilo (Write) y reintenta la verificación.\n' >&2
      _fallos=$((_fallos+1))
    fi
  fi
  # §SIGUIENTE: si el bloque reinyectado supera el umbral, el harness deja solo ~2KB de preview (faro incluido);
  # el §SIGUIENTE tiene que caber ahí completo. Máximo configurable con CONTRATO_HILO_SIGUIENTE_MAX (bytes).
  if [ -n "$_fresco" ]; then
    _sigmax="${CONTRATO_HILO_SIGUIENTE_MAX:-900}"
    case "$_sigmax" in ''|*[!0-9]*) _sigmax=900 ;; esac
    _sigb=$(awk '
      /^#+[[:space:]]/ && tolower($0) ~ /siguiente|estado/ && !seen { seen=1; print; next }
      seen && /^##[[:space:]]/ { exit }
      seen { print }
    ' "$_f" 2>/dev/null | wc -c | tr -d ' ')
    if [ "${_sigb:-0}" -gt "$_sigmax" ]; then
      printf 'CONTRATO-HILO: el §SIGUIENTE de %s mide %s bytes (máx %s) ⇒ en el preview de ~2KB del rehidratado
' "$_f" "$_sigb" "$_sigmax" >&2
      printf '  queda CORTADO. Recórtalo a 2-5 líneas (el detalle va en las secciones de abajo).
' >&2
      _fallos=$((_fallos+1))
    fi
  fi
  [ "$_fallos" -eq 0 ]
}
