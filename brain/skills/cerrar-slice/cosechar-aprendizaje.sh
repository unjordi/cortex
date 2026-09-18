#!/usr/bin/env bash
# cosechar-aprendizaje.sh — MAQUINARIA DETERMINISTA de la cosecha (antes el skill separado
# `cosechar-sesion`, retirado 2026-09-17: su JUICIO vive ahora en `cerrar-slice/SKILL.md` §5, este
# script es la parte MECÁNICA que invoca). Appendea UN bloque bien formado al FINAL de un
# `aprendizajes.md` (inbox append-only, `merge=union` → varias sesiones/ramas lo escriben sin pisarse).
#
# NO decide QUÉ cosechar (eso es criterio — grano vs paja, TRATO-personal vs conocimiento-de-proyecto:
# ver cerrar-slice/SKILL.md §5); SOLO garantiza el FORMATO del bloque y el append-only.
#
#   USO   cosechar-aprendizaje.sh --handle <h> --tema "<tema corto>" --texto "<prosa>"
#                                 [--fecha AAAA-MM-DD] [--sobre <handle>] [--archivo <ruta>]
set -u

_uso() { cat <<'USO'
cosechar-aprendizaje.sh — appendea un bloque de aprendizaje bien formado a aprendizajes.md.

  --handle <h>       quien aporta (o "h1, h2" si es co-autoría). REQUERIDO.
  --tema "<txt>"      tema corto del bloque (va en el encabezado). REQUERIDO.
  --texto "<txt>"     la prosa del aprendizaje (qué se aprendió, el caso real, por qué y cómo aplicarlo). REQUERIDO.
  --fecha AAAA-MM-DD  fecha del bloque. Default: hoy (`date +%Y-%m-%d`).
  --sobre <handle>    si el aprendizaje es SOBRE otra persona (trato/preferencia observada de ella).
  --archivo <ruta>    destino. Default: .claude/memory/aprendizajes.md (créalo si no existe, con un header mínimo).
  -h|--help           esta ayuda.

Formato que escribe (append-only; NUNCA edita bloques viejos):
  ## <fecha> · aportó: <handle> · [sobre: <sobre> ·] <tema>
  <texto>
  <línea en blanco>
USO
}

_err() { printf 'cosechar-aprendizaje: %s\n' "$1" >&2; exit 1; }

HANDLE=""; TEMA=""; TEXTO=""; FECHA=""; SOBRE=""; ARCHIVO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --handle)   HANDLE="${2:-}"; shift 2 ;;
    --tema)     TEMA="${2:-}"; shift 2 ;;
    --texto)    TEXTO="${2:-}"; shift 2 ;;
    --fecha)    FECHA="${2:-}"; shift 2 ;;
    --sobre)    SOBRE="${2:-}"; shift 2 ;;
    --archivo)  ARCHIVO="${2:-}"; shift 2 ;;
    -h|--help)  _uso; exit 0 ;;
    *)          _err "opción desconocida: $1 (usa --help)" ;;
  esac
done

[ -n "$HANDLE" ] || _err "falta --handle <quién aporta>."
[ -n "$TEMA" ]   || _err "falta --tema \"<tema corto>\"."
[ -n "$TEXTO" ]  || _err "falta --texto \"<prosa del aprendizaje>\"."
[ -n "$FECHA" ]  || FECHA="$(date +%Y-%m-%d)"
case "$FECHA" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) : ;;
  *) _err "--fecha debe ser AAAA-MM-DD (dado: '$FECHA')." ;;
esac
[ -n "$ARCHIVO" ] || ARCHIVO=".claude/memory/aprendizajes.md"

if [ ! -f "$ARCHIVO" ]; then
  mkdir -p "$(dirname "$ARCHIVO")" 2>/dev/null || true
  {
    printf '# Aprendizajes (inbox append-only)\n\n'
    printf '> Cada bloque: `## <fecha> · aportó: <handle> · <tema>` + prosa + línea en blanco. NUNCA se\n'
    printf '> edita un bloque viejo, solo se APPENDEA al final. `merge=union` en git-attributes recomendado.\n\n'
  } > "$ARCHIVO"
  echo "cosechar-aprendizaje: creé $ARCHIVO con el header del inbox." >&2
fi

encabezado="## $FECHA · aportó: $HANDLE"
[ -n "$SOBRE" ] && encabezado="$encabezado · sobre: $SOBRE"
encabezado="$encabezado · $TEMA"

# Append atómico al FINAL — nunca reescribe el archivo completo (dos `>>` concurrentes no se pisan).
{
  printf '%s\n' "$encabezado"
  printf '%s\n' "$TEXTO"
  printf '\n'
} >> "$ARCHIVO"

echo "cosechar-aprendizaje: appendé \"$TEMA\" (aportó: $HANDLE) a $ARCHIVO" >&2
