#!/usr/bin/env bash
# cementerio.sh — helper del "CEMENTERIO per-cerebro" (cortex). Standalone (kind=script): NO se
# cablea; se corre A MANO desde dentro de un repo (como limpiar-ramas.sh / verificar-cerebro.sh).
#
# LA IDEA: las "lápidas" (mitos descartados, callejones muertos, "NO re-proponer") ya no viven INLINE
# repartidas por cada memoria con 7 líneas del trauma. Viven en UN solo `.claude/memory/cementerio.md`
# por cerebro; cada lápida = una entrada con un ID content-hash corto (🪦#34341f45a): qué murió · cuándo
# · con qué se reemplazó / por qué no re-proponer, en UNA línea. Donde antes iba la lápida inline queda
# solo la REFERENCIA `(🪦#<id>)` — o NADA si el punto no necesita la advertencia. El cerebro guarda
# CONOCIMIENTO, no cicatrices.
#
#   uso:
#     cementerio.sh add "<qué murió>" ["<detalle: cuándo · reemplazo / por qué no re-proponer>"]
#         → acuña un ID content-hash de "<qué murió>" (determinista → mismo texto = mismo ID = dedup),
#           appende la entrada a .claude/memory/cementerio.md (lo crea con header si no existe) y
#           DEVUELVE la referencia `(🪦#<id>)` a stdout para pegar inline. Si el ID ya existe, no
#           duplica: solo devuelve la ref (dedup natural).
#     cementerio.sh verify
#         → junta todas las refs `(🪦#<id>)` de las memorias del repo y todos los IDs del cementerio, y
#           reporta refs HUÉRFANAS (apuntan a un ID inexistente) e IDs MUERTOS (nadie los referencia,
#           informativo). Exit != 0 si hay huérfanas.
#     cementerio.sh --help
#
#   Overrides (tests): CLAUDE_MEMORY_DIR fija el dir de memorias (default: <repo>/.claude/memory).
#
# Portátil: bash 3.2 (macOS) y Linux. Detecta shasum (macOS) o sha1sum (Linux) para el hash.
set -u

# ── hash content-addressed: 9 hex de sha1(texto). Detecta la herramienta disponible. ──
_sha1() {  # lee stdin, imprime el hash hex
  if command -v shasum >/dev/null 2>&1; then shasum -a 1
  elif command -v sha1sum >/dev/null 2>&1; then sha1sum
  else echo "cementerio: falta shasum/sha1sum (no puedo acuñar el ID)" >&2; return 1; fi
}
mint_id() {  # <texto> → 9 hex deterministas
  printf '%s' "$1" | _sha1 | cut -c1-9
}

# ── resolución del dir de memorias del repo (override para tests) ──
resolve_memdir() {
  if [ -n "${CLAUDE_MEMORY_DIR:-}" ]; then printf '%s' "$CLAUDE_MEMORY_DIR"; return; fi
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$root" ]; then printf '%s/.claude/memory' "$root"; else printf '%s/.claude/memory' "$PWD"; fi
}

CEMENTERIO_HEADER() {
cat <<'EOF'
# ⚰️ Cementerio del cerebro — lápidas por ID (NO monumentos)

> Una lápida = **conocimiento que evita re-pisar un callejón caro**, NO un monumento al trauma. Aquí
> vive, en UNA línea, cada mito descartado / decisión revertida / "NO re-proponer": **qué murió ·
> cuándo · con qué se reemplazó o por qué no volver.** El cerebro guarda CONOCIMIENTO, no cicatrices.
>
> Cada entrada tiene un **ID content-hash** (`🪦#<9-hex>`, determinista sobre el "qué murió"). Donde
> una memoria necesita la advertencia, deja solo la **referencia inline** `(🪦#<id>)` — sin repetir el
> monumento. Acuña/appende con `cementerio.sh add "<qué murió>" "<detalle>"`; valida refs↔IDs con
> `cementerio.sh verify`. Este archivo es la ÚNICA casa de las lápidas de ESTE cerebro (viaja con el repo).

EOF
}

cmd_add() {
  local titulo="${1:-}" detalle="${2:-}"
  if [ -z "$titulo" ]; then echo "cementerio add: falta el texto de la lápida (qué murió)" >&2; return 2; fi
  local memdir cem id
  memdir="$(resolve_memdir)"
  cem="$memdir/cementerio.md"
  id="$(mint_id "$titulo")" || return 1

  mkdir -p "$memdir" 2>/dev/null || { echo "cementerio: no pude crear $memdir" >&2; return 1; }
  if [ ! -f "$cem" ]; then CEMENTERIO_HEADER > "$cem"; fi

  # dedup natural: si el ID ya está, no re-appendear — solo devolver la ref.
  if grep -qF "🪦#$id" "$cem" 2>/dev/null; then
    printf '(🪦#%s)\n' "$id"
    return 0
  fi

  {
    printf '### 🪦#%s — %s\n' "$id" "$titulo"
    [ -n "$detalle" ] && printf '%s\n' "$detalle"
    printf '\n'
  } >> "$cem"

  printf '(🪦#%s)\n' "$id"
}

cmd_verify() {
  local memdir cem
  memdir="$(resolve_memdir)"
  cem="$memdir/cementerio.md"

  if [ ! -d "$memdir" ]; then echo "cementerio verify: no existe $memdir" >&2; return 0; fi

  # IDs DEFINIDOS = tokens 🪦# del cementerio (sus headings). Vacío si aún no hay cementerio.
  local defined refs
  if [ -f "$cem" ]; then
    defined="$(LC_ALL=C grep -ohE '🪦#[0-9a-f]{9}' "$cem" 2>/dev/null | sed 's/^.*#//' | sort -u)"
  else
    defined=""
  fi

  # REFS = ocurrencias `(🪦#<id>)` en las memorias del repo (todo .md salvo el propio cementerio).
  local files
  files="$(find "$memdir" -name '*.md' -type f 2>/dev/null | grep -v '/cementerio.md$')"
  if [ -n "$files" ]; then
    refs="$(printf '%s\n' "$files" | while IFS= read -r f; do
              [ -n "$f" ] || continue
              LC_ALL=C grep -ohE '\(🪦#[0-9a-f]{9}\)' "$f" 2>/dev/null
            done | sed 's/^(🪦#//; s/)$//' | sort -u)"
  else
    refs=""
  fi

  local orphans dead rc=0
  # HUÉRFANAS: ref cuyo id NO está definido → ERROR.
  orphans="$(comm -23 <(printf '%s\n' "$refs" | grep -v '^$' | sort -u) \
                       <(printf '%s\n' "$defined" | grep -v '^$' | sort -u) 2>/dev/null)"
  # MUERTOS: id definido que nadie referencia → informativo (no es error).
  dead="$(comm -13 <(printf '%s\n' "$refs" | grep -v '^$' | sort -u) \
                    <(printf '%s\n' "$defined" | grep -v '^$' | sort -u) 2>/dev/null)"

  local n_def n_ref
  n_def="$(printf '%s\n' "$defined" | grep -vc '^$')"
  n_ref="$(printf '%s\n' "$refs" | grep -vc '^$')"
  echo "⚰️  cementerio verify — $cem"
  echo "   IDs en el cementerio: $n_def · refs inline distintas: $n_ref"

  if [ -n "$orphans" ]; then
    echo "   ✗ refs HUÉRFANAS (apuntan a un ID inexistente):"
    printf '%s\n' "$orphans" | sed 's/^/       🪦#/'
    rc=1
  else
    echo "   ✓ sin refs huérfanas"
  fi
  if [ -n "$dead" ]; then
    echo "   · IDs MUERTOS (en el cementerio, nadie referencia — informativo, no error):"
    printf '%s\n' "$dead" | sed 's/^/       🪦#/'
  fi
  return $rc
}

case "${1:-}" in
  add)     shift; cmd_add "$@" ;;
  verify)  shift; cmd_verify "$@" ;;
  -h|--help|help|"")
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "cementerio: subcomando desconocido '$1' (usa: add | verify | --help)" >&2
    exit 2 ;;
esac
