# Revisión §7 de la fila 5 (claudio-master, 2026-11-01 ~17:55) — bec85e1

Probado en vivo sobre un clon de cortex con origin inalcanzable (`limpiar.sh ramas --dry-run`, HOME/config en sandbox).

✅ Sin red (DNS que no resuelve): el fetch falla rápido y el resumen lo dice («no pude actualizar origin… 2 rama(s) juzgadas con refs locales posiblemente viejas — ninguna se borró por esa duda»).

## MEDIO — con un host que no responde, el barrido sigue colgándose
Con origin en una IP que no contesta y LIMPIAR_RAMAS_FETCH_TIMEOUT=5: el fetch se corta a los 5 s como debe, pero después `barrer_remota` corre `git ls-remote --heads origin <rama>` (limpiar-impl-ramas.sh:106, y otra en la :244) SIN el ConnectTimeout ni el timeout: 75 s por cada rama local. Con una rama local, la corrida tardó 1 min 20 s; con N ramas, N × 75 s. Es justo lo que la fila venía a evitar (que el barrido no cuelgue sin red).
Arreglo: con fetch_ok=0, no consultar el remoto rama por rama (se conserva y se dice, como ya hace el resumen); y que toda llamada al remoto use el mismo GIT_SSH_COMMAND con ConnectTimeout/BatchMode y el mismo tope de tiempo. Prueba: host que no responde + 3 ramas locales → la corrida termina en ~el timeout, no en 3 × 75 s.

## BAJO — el tope mata al subshell, no a git
`( … git fetch … ) &` + `kill "$_fpid"` mata el bash del subshell; el git y su ssh quedan huérfanos hasta que el ConnectTimeout los suelta. Con `exec git …` dentro del subshell, el PID que se mata es el de git.

La fila 5 no está ✅.

## Re-revisión tras 032b62c (claudio-master, ~18:05)
Host que no responde + 3 ramas locales, LIMPIAR_RAMAS_FETCH_TIMEOUT=5: la corrida termina en 29.6 s (fetch 5 s + ~8 s de ConnectTimeout por cada ls-remote), sin git/ssh huérfanos, y el resumen dice que no pudo actualizar. Antes eran 75 s por rama sin tope. Crece N × 8 s, pero barrer-ramas lo corre en segundo plano (nohup), así que no bloquea la sesión. Fila 5 ✅.
BAJO opcional: con fetch_ok=0 se podrían saltar los ls-remote (mismo host caído) y ahorrar esos N × 8 s.
