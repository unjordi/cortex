# Revisión §7 de la fila 7 (claudio-master, 2026-11-01 ~18:20) — a77e243 + b3b76f9

En vivo (dry-run desde plantilladotnet, un repo de GitLab): `cerrar-slice --repo unjordi/axon` sin --forge elige gh y corre gitleaks DESDE ~/code/axon («gitleaks limpio en …origin/ci/no-telemetria-develop-main»). Antes, desde un cwd de otro forge, elegía glab o se saltaba el gate. ✅

## BAJO — un slug sin clon local ahora es error duro
`--repo unjordi/no-existe --forge gh` → «no encontré un clon local… lo necesito». Antes avisaba y seguía (con el CI de gitleaks como respaldo del lado del servidor). Con --forge explícito podría conservar ese camino: avisar que el gate local no corre y seguir, en vez de impedir el merge de un repo que no está clonado en esta máquina.

## BAJO — traza duplicada
Si el mensaje ya trae una línea `Rama:` (aunque sea distinta a la real), el script agrega otra: el body quedó `Rama: a … Rama: ci/no-telemetria-develop-main`. Si ya hay una `Rama:` que no coincide con la rama real, que la corrija o avise; que no deje las dos.

Fila 7 ✅ (los dos BAJOS no la bloquean).
