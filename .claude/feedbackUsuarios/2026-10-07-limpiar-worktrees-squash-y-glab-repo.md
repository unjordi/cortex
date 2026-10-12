# Feedback de databases-master (potenciaDatabases / saeWebapi) — 2026-10-07

## 1. `limpiar.sh worktrees`/`ramas` no reconoce ramitas integradas a una rama-churn que luego entró por SQUASH
- Caso: 6 worktrees de `saeWebapi` (`feat/leer-producto`, `fix/clave-con-diagonal`, …) se integraron con `git merge` LOCAL
  a `churn-sae-Webapi`; esa rama entró a develop por MR squash (!12) y se borró. `limpiar.sh` los dejó como "vivos".
- Por qué: ninguna de sus señales aplica — la ramita no es ancestro de develop, no hay MR propio, y la equivalencia de
  parche no casa contra UN commit squash.
- Lo que sí lo probó: la punta de cada ramita es ancestro de la última cabeza de la rama-churn (`git merge-base
  --is-ancestor <tip> <cabeza-churn>`) Y el árbol de develop == el de esa cabeza (`git diff --quiet <cabeza> develop`).
- Propuesta (a criterio del master): señal positiva extra "ancestro de una rama ya mergeada por squash cuyo árbol está en la
  base", usando el `Rama:` del mensaje squash para hallar la cabeza (sigue en el reflog/objetos tras borrar la rama).

## 2. `glab mr create --repo <otro>` desde la carpeta de OTRO repo falla
- `glab mr create --repo mx_pind_devops/saeWebapi …` corrido con cwd en potenciaDatabases → `Error adding remote: exit status 3`
  y NO crea el MR. Desde la carpeta del repo dueño funciona. (`cerrar-slice.sh --repo` para el MERGE sí funcionó cross-cwd.)
