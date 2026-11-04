# Revisión de candidatos a integración (claudio-master, 2026-10-20)
Pedido de unjordi: "puedes revisar lo que ya está 'completo' para ver si tenemos candidatos de integración?". Todo corrido por mí sobre copias (git archive de fix/corpus-fp-bench en /tmp, HOME falso, repos desechables).

## fix/corpus-fp-bench — slice gitleaks (79e01a2, 3c47e96, 40ca07c, 0a9170e)
- Poda de secret-scan + detectar-secretos: install-brain.sh de la rama sobre un HOME falso con ambos instalados y cableados → borra los dos .sh, quita el cableado de settings.json y deja los demás guards (git-branch-guard sigue cableado). OK.
- .gitleaks.toml: idéntico al de los repos GitLab; cadena de conexión con contraseña real → detecta; con ${SA_PASSWORD} → limpio. La rama misma (origin/develop..fix/corpus-fp-bench) con su .gitleaksignore → "no leaks found". OK.
- Gate de cerrar-slice parado EN la rama del slice con un token real → aborta (exit 1). OK.
- **H18 MEDIO — cerrar-slice.sh `_gitleaks_gate`: escanea `origin/develop..HEAD` del directorio actual, no la rama del MR.** Parado en develop (o la mini, o con `--repo` sobre otro repo) con un MR cuya rama trae un token real → "gitleaks limpio" en falso y sigue al merge. Reproductor: repo con origin bare, `feat/x` con `token = "ghp_<36 al azar>"`, `git checkout develop`, correr el gate → limpio. Arreglo: resolver la rama head del MR (`gh pr view <id> --json headRefName` / `glab mr view <id> -F json` → source_branch), `git fetch` y escanear `origin/develop..origin/<rama>`; si no se puede resolver, NO decir "limpio" (avisar y parar o exigir estar parado en la rama).
- Restos vivos del retiro (no la historia): agregar-hook-cerebro/SKILL.md:8,19 usa secret-scan.sh como plantilla; auditar-coherencia-cerebro/SKILL.md:43 lo lista como guard; comentario de uninstall-brain.sh:9-11; comentario git-branch-guard.sh:108 (CLAUDE_SKIP_SECRET_SCAN).
- Nota (no bug): el workflow de GitHub corre en push a develop/main y workflow_dispatch → detecta después del merge; el freno antes de integrar es el gate local (y sin gitleaks instalado, p. ej. la cachy hoy, solo avisa). Queda pendiente que `cerrar-slice --wait-ci` dispare el workflow sobre la rama como gate (ya en tu Fase 2).

## fix/corpus-fp-bench — 00df422 (git-branch-guard + lib)
- H1 (ya verificado 2026-10-19), H2, H3 y L145: verificados. Guard completo con HOME falso: frena push a develop directo, con eval, bash -c, sh -c y subshell; deja pasar push a ramita y menciones en echo/pgrep. H3: ssh://git@host:2222/org/grupo/repo → org/grupo/repo. H2: desde un worktree encuentra el clon hermano; la lib de 52d2d8c no (falla contra el viejo). OK.

## fix/despertar-mensaje (db0a17d, mío)
- Probado por mí (sesiones reales + masters falsos + señuelo). Falta tu revisión.

## rescate/develop-local (9 commits, docs)
- Conflictos con origin/develop Y con fix/corpus-fp-bench en .claude/memory/estado-proyecto.md y docs/guards-falsos-positivos.md (merge-tree). Para tu bloque, resolviendo a mano (el corpus es append-only: unión de líneas).
