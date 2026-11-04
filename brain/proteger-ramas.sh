#!/usr/bin/env bash
# proteger-ramas.sh <grupo/subgrupo/repo | id> — aplica la NORMA DE RAMAS a UN repo GitLab:
#   - crea `develop` desde la rama default si falta
#   - protege default + develop: push=nadie (0), merge=Maintainer (40), sin force-push
# Usa la auth LOCAL de glab (no requiere token en CI, sin caducidad). Idempotente.
# Correr al crear/abrir un repo nuevo (el "failsafe" de la norma).
# PATH heredado PRIMERO (resolución estándar: un glab/jq del usuario o un stub de PATH de las pruebas
# gana), con los dirs de Homebrew/sistema APPENDEADOS como fallback para contextos de PATH mínimo
# (hook/launchd). NO hay perilla de mock en producción: glab se resuelve SOLO por PATH (los tests
# inyectan un glab falso prependeando su dir a PATH; el camino de producción no lee ninguna env).
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
set +e

PROJ="$1"
[ -z "$PROJ" ] && { echo "uso: proteger-ramas.sh <grupo/subgrupo/repo | id>"; exit 1; }
ENC=$(printf '%s' "$PROJ" | sed 's|/|%2F|g')
id=$(glab api "projects/$ENC" 2>/dev/null | jq -r '.id // empty')
[ -z "$id" ] && { echo "✗ no encontré el proyecto: $PROJ"; exit 1; }
def=$(glab api "projects/$id" 2>/dev/null | jq -r '.default_branch // "main"')
echo "proyecto: $PROJ (id $id), default=$def"

if ! glab api "projects/$id/repository/branches/develop" >/dev/null 2>&1; then
  glab api --method POST "projects/$id/repository/branches?branch=develop&ref=$def" >/dev/null 2>&1 \
    && echo "  ✓ develop creada desde $def" || echo "  ✗ no pude crear develop"
else
  echo "  = develop ya existe"
fi

# A3 (auditoría 2026-10-22): NO se borra la protección a ciegas antes del POST (si el POST fallaba, la rama
# quedaba DESPROTEGIDA y el script igual imprimía "aplicada" + exit 0 por el `set +e`). Ahora: si la rama NO
# está protegida → POST directo (sin ventana de desprotección); si YA está protegida → se re-aplica
# (DELETE+POST, única vía en GitLab para fijar niveles) PERO se VERIFICA el POST; si el POST falla, el mensaje
# lo dice y el script sale con rc≠0 (nuevo-repo.sh:71 ya avisa por su `warn`). FAIL si alguna rama no quedó.
# BAJO (auditoría 2026-10-23, claudio): el re-aplicar (DELETE+POST, única vía en GitLab para fijar niveles)
# abre una VENTANA — si el POST falla, la rama queda desprotegida (A3 ya AVISA con rc 1, no silencioso). Para
# EVITAR la ventana en el caso común (re-run sobre una rama YA protegida con NUESTRA config), se consulta la
# protección actual y, si ya casa exacto (push=0, merge=40, force=false), se DEJA INTACTA (sin DELETE). Solo
# si NO existe o DIFIERE se (re)aplica. GitLab no expone PATCH para estos niveles → DELETE+POST sigue siendo
# la vía cuando hay que cambiarlos. Sin jq → se cae al camino conservador (re-aplica como antes).
FAIL=0
for b in "$def" develop; do
  cur=$(glab api "projects/$id/protected_branches/$b" 2>/dev/null); rc=$?
  if [ "$rc" = 0 ]; then                        # YA protegida (404/no-protegida → rc≠0 → directo al POST)
    if command -v jq >/dev/null 2>&1 && printf '%s' "$cur" | jq -e . >/dev/null 2>&1; then
      pa=$(printf '%s' "$cur" | jq -r '[.push_access_levels[]?.access_level]|join(",")' 2>/dev/null)
      ma=$(printf '%s' "$cur" | jq -r '[.merge_access_levels[]?.access_level]|join(",")' 2>/dev/null)
      fp=$(printf '%s' "$cur" | jq -r '.allow_force_push' 2>/dev/null)
      if [ "$pa" = "0" ] && [ "$ma" = "40" ] && [ "$fp" = "false" ]; then
        echo "  🔒 ya protegida (config correcta): $b — sin re-aplicar (evita la ventana DELETE→POST)"
        continue
      fi
    fi
    # config DIFERENTE, o ilegible sin jq → re-fijar (DELETE+POST, única vía en GitLab para los niveles)
    glab api --method DELETE "projects/$id/protected_branches/$b" >/dev/null 2>&1
  fi
  if glab api --method POST "projects/$id/protected_branches?name=$b&push_access_level=0&merge_access_level=40&allow_force_push=false" >/dev/null 2>&1; then
    echo "  🔒 protegida: $b (push=nadie, merge=Maintainer)"
  else
    echo "  ✗ FALLÓ proteger $b — pudo quedar SIN protección; revísalo (token/red). NO reintentes a ciegas."
    FAIL=1
  fi
done
if [ "$FAIL" = 1 ]; then
  echo "✗ norma de ramas INCOMPLETA en $PROJ (hubo fallos arriba)."
  exit 1
fi
echo "norma de ramas aplicada a $PROJ."