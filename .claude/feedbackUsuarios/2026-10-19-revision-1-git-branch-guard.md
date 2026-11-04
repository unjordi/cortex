# Revisión directa de lo integrado (de6df53..52d2d8c) · sección 1: git-branch-guard + analizar-comando-git.sh

Revisión de claudio, pedida por unjordi el 2026-10-19 ("revísalo a detalle, módulo por módulo"). Cada caso lo corrí llamando a la librería directo, sin la cláusula de dedupe, con repos y worktrees reales en /tmp.

## Lo que cambió y está bien (probado en las dos direcciones)
- `acg_push_destino_base` borra los tokens `refs/remotes/...` antes de buscar la base.
  - Deja pasar `develop:refs/remotes/origin/develop` y `feat/x:refs/remotes/origin/develop`.
  - Sigue frenando `origin develop`, `HEAD:refs/heads/develop`, `+develop` y `develop:refs/remotes/o/develop main`.
- `git-branch-guard.sh` solo trae limpieza de comentarios.

## Hallazgos

### H1 · MEDIO · el `cd` de un segmento con palabra clave delante no se arrastra (FP que ya existía)
`analizar-comando-git.sh:375` reconoce el cd solo con `^[[:space:]]*(cd|pushd)`. En `do cd X`, `then cd X`, `else cd X` o `{ cd X`, la palabra clave va antes y el cd se pierde. Entonces el push pelón del segmento siguiente se resuelve contra el cwd de la sesión.

Repo en develop + worktree en chore/x; cwd de la sesión = el repo:

| comando | decide | debería |
|---|---|---|
| `cd <wt> && <push pelón>` | pasa | pasa |
| `cd <wt>; <push pelón>` | pasa | pasa |
| `(cd <wt> && <push pelón>)` | pasa | pasa |
| `git -C <wt> push` | pasa | pasa |
| `for r in a; do cd <wt> && <push pelón>; done` | **FRENA** | pasa |
| `cd <repo-en-develop> && <push pelón>` | frena | frena |

Arreglo: aceptar el prefijo de palabra clave de shell (`do|then|else|elif|{|!`) antes de `cd|pushd` en L375. Mejor todavía: resolver la rama con git en el dir real (punto 5 del encargo de unjordi). Test que falle contra 52d2d8c con el `for … do cd`.

### H2 · BAJO · `acg_clon_local_de_slug` no encuentra el clon si la sesión está en un worktree
Busca hermanos de `dirname(toplevel)`. Desde `~/code/a/.claude/worktrees/w`, el toplevel es el worktree, así que busca entre los otros worktrees de `a` y no en `~/code/*`.

Medido: desde el repo `a` resuelve `org/b` → `~/code/b`; desde el worktree de `a`, vacío. Es fail-safe (cae al cwd y gatea), pero frena en falso un `merge --repo org/b` lanzado desde un worktree.

Arreglo: partir de `git rev-parse --git-common-dir` (el repo principal) para buscar hermanos.

### H3 · BAJO · `acg_slug_de_dir` no entiende remotos `ssh://git@host:puerto/org/repo.git`
Devuelve `ssh://git@gitlab.com:2222/org/b`, que no casa con ningún slug. Es fail-safe, pero el slug sale mal.

Arreglo: normalizar también `ssh://[user@]host[:puerto]/`.
