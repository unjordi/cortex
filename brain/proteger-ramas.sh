#!/usr/bin/env bash
# proteger-ramas.sh <grupo/subgrupo/repo | id> — aplica la NORMA DE RAMAS a UN repo GitLab:
#   - crea `develop` desde la rama default si falta
#   - protege default + develop: push=nadie (0), merge=Maintainer (40), sin force-push
# Usa la auth LOCAL de glab (no requiere token en CI, sin caducidad). Idempotente.
# Correr al crear/abrir un repo nuevo (el "failsafe" de la norma).
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
set +e
GLAB="${PROTEGER_RAMAS_GLAB:-glab}"   # override para tests herméticos (mock de glab)

PROJ="$1"
[ -z "$PROJ" ] && { echo "uso: proteger-ramas.sh <grupo/subgrupo/repo | id>"; exit 1; }
ENC=$(printf '%s' "$PROJ" | sed 's|/|%2F|g')
id=$("$GLAB" api "projects/$ENC" 2>/dev/null | jq -r '.id // empty')
[ -z "$id" ] && { echo "✗ no encontré el proyecto: $PROJ"; exit 1; }
def=$("$GLAB" api "projects/$id" 2>/dev/null | jq -r '.default_branch // "main"')
echo "proyecto: $PROJ (id $id), default=$def"

if ! "$GLAB" api "projects/$id/repository/branches/develop" >/dev/null 2>&1; then
  "$GLAB" api --method POST "projects/$id/repository/branches?branch=develop&ref=$def" >/dev/null 2>&1 \
    && echo "  ✓ develop creada desde $def" || echo "  ✗ no pude crear develop"
else
  echo "  = develop ya existe"
fi

# A3 (auditoría 2026-10-22): NO se borra la protección a ciegas antes del POST (si el POST fallaba, la rama
# quedaba DESPROTEGIDA y el script igual imprimía "aplicada" + exit 0 por el `set +e`). Ahora: si la rama NO
# está protegida → POST directo (sin ventana de desprotección); si YA está protegida → se re-aplica
# (DELETE+POST, única vía en GitLab para fijar niveles) PERO se VERIFICA el POST; si el POST falla, el mensaje
# lo dice y el script sale con rc≠0 (nuevo-repo.sh:71 ya avisa por su `warn`). FAIL si alguna rama no quedó.
FAIL=0
for b in "$def" develop; do
  if "$GLAB" api "projects/$id/protected_branches/$b" >/dev/null 2>&1; then
    "$GLAB" api --method DELETE "projects/$id/protected_branches/$b" >/dev/null 2>&1   # re-aplicar: fijar niveles
  fi
  if "$GLAB" api --method POST "projects/$id/protected_branches?name=$b&push_access_level=0&merge_access_level=40&allow_force_push=false" >/dev/null 2>&1; then
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