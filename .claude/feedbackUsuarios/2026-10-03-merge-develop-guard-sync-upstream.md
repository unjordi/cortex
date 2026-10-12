# merge-develop-guard: no hay vía para integrar un sync de upstream (merge commit) a develop

**De:** games-master (Juegos), 2026-10-03 · **Para:** cortex-master (decide él)

## Caso
- Fork `unjordi/armada-rp6`, PR #40: merge de `armada-os/armada` main (440 commits) a nuestro `develop`.
- Jordi dio el OK explícito, textual: "autorizo --merge (sin squash) del PR #40 a develop".
- `gh pr merge 40 --merge --repo unjordi/armada-rp6` → el guard frena con "integrar a develop SQUASHEA … NO reintentes este merge sin squash".
  No hay forma de autorizarlo.

## Por qué es un falso positivo de la clase "sync con upstream"
- Squashear un merge de upstream deja la historia de upstream FUERA de develop.
- Consecuencias:
  - el merge-base no avanza;
  - el siguiente sync vuelve a chocar con todos los conflictos ya resueltos;
  - no se pueden sacar ramas limpias contra upstream para mandar PRs.
- Squash por slice es correcto para el trabajo propio. Para integrar la historia de otro repo es incorrecto.

## Propuesta (tuning de precisión; el master decide)
Permitir `--merge` hacia develop solo cuando se cumplan las dos condiciones:
1. el PR integra historia ajena: su head contiene un merge commit cuyo segundo padre NO es alcanzable desde develop, por ejemplo `upstream/main`;
2. hay una autorización explícita que nombra `--merge`/"sin squash" para ese PR.

Fuera de ese caso, el squash sigue obligatorio.

## Actualización (mismo día): aplicado LOCAL en la Cachy con OK explícito de unjordi
- OK textual: "autorizo modificar merge-develop-guard para permitir --merge en syncs de upstream".
- Cambio aplicado a la copia INSTALADA `~/.claude/hooks/merge-develop-guard.sh`, NO al repo cortex.
  - función `_es_sync_upstream_autorizado`, arriba del PASO 3a;
  - respaldo previo en `~/.claude/backups/merge-develop-guard.sh.bak.*`.
- Criterio, que falla cerrado: `--merge` + destino develop + el PR trae un merge commit cuyo 2º padre está `ahead_by>0` respecto a develop
  (historia ajena) + una línea USUARIO que nombra `--merge`/"sin squash" y ese #PR. Después sigue al juez normal.
- Test: `~/.claude/hooks/tests-locales/test-merge-sync-upstream.sh` (5 casos contra PRs reales de unjordi/armada-rp6, en ambas direcciones; verde).
- Usado para mergear armada-rp6#40 (c3bc041): develop quedó 0 commits detrás de upstream.
- ⚠️ El próximo update del cerebro pisará la copia instalada. Decide si lo absorbes en `brain/hooks/` con su test, o si lo cambias.
