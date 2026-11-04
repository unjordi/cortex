# git-branch-guard: frena el push de una ramita hecho tras `cd <worktree> &&` (FP que YA existía, no regresión)

Corrección: el reporte anterior lo llamaba regresión de la épica. Era falso. La comparación corría copias del guard fuera de `~/.claude/hooks/`, y la cláusula de dedupe las hacía salir con 0 sin evaluar nada.

Reproducido llamando a la librería directamente, sin dedupe. Repo en `develop`, worktree en `chore/x`, y el comando:

    for r in a:b; do cd <repo>-wt && git add -A && <push pelón>; done

`acg_push_toca_base <ese comando> <repo>` da "toca base" en de6df53 y también en 52d2d8c.

Causa probable: el segmento del push resuelve su directorio con `acg_target_dir(segmento)` y cae al cwd de la sesión. El `cd` de un segmento previo no se aplica dentro de `for … do … done`.

Arreglo esperado: resolver la rama con git en el directorio real del comando (punto 5 del encargo de unjordi), con un test que falle contra 52d2d8c.

Para cualquier banco de guards: probar una copia fuera de `~/.claude/hooks/` sin neutralizar el dedupe da verde falso.

Mismo día, otro FP: el guard frenó un heredoc/printf que solo MENCIONABA un push dentro del texto de este reporte.
