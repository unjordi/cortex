# Revisión de todo lo de git en cortex — sin la biblioteca de comandos (decisión de unjordi, 2026-11-09)

[user 2026-11-09: "quiero que nos deshagamos de la biblioteca compartida de comandos de gits. Se supone que eso era lo que iba a hacer usar el árbol!! No vamos a reimplementar todo bien nada más para saber si estamos cuidando bien los merges!!!"]
[user 2026-11-09: "ES DEMASIADO CÓDIGO!!"]
Manda sobre el rediseño de hoy (2026-11-09-rediseno-merge-develop-guard.md) donde lo contradiga, y conserva sus decisiones de fondo y las del 2026-10-21 (2026-10-21-ok-retirar-git-branch-guard.md): nada determinista sobre el texto, repo y destino por git y preguntándole a gh/glab, lo ambiguo al juez Haiku, cero frenos en falso.

## Medido en develop (69da5136)
Lo de git suma 4 094 líneas (2 239 de código, 113 funciones), más de la mitad de las 6 719 de hooks/libs/scripts del cerebro:
merge-develop-guard 723 · analizar-comando-git 1 158 · juez-comun 314 · proteger-arbol 206 · ramas-zombie 498 · barrer-ramas 166 · limpiar + 3 implementaciones 639 · cerrar-slice.sh 390.
Dependen de analizar-comando-git: merge-develop-guard (27 funciones), barrer-ramas (5), entorno-maquina-guard (4), proteger-arbol (4), no-bypass-deploy (1), cerrar-slice.sh (1), install-brain.sh (1), test-brain.sh, tests/corpus-fp.
La suite tiene ~300 aserciones solo de este guard en 21 baterías ad hoc.

## Principio
**Cortex no reimplementa git.** El texto del comando se lee UNA vez con shfmt (`shfmt --to-json`) para saber qué ejecutable corre, con qué argumentos, en qué directorio y con qué variables de entorno. Todo HECHO sobre el repo lo responde la herramienta: `git` en ese directorio, `gh`/`glab` con los mismos argumentos que el comando, el servidor para la protección y el estado del MR/PR. Lo que no se pueda afirmar así va al juez Haiku o se calla; nunca se adivina con regex.

## Qué se hace
1. **Se borra `analizar-comando-git.sh` completo**, con sus pruebas y su entrada en MANIFEST (tier `retirado` con su motivo, para que install-brain la pode de las máquinas).
2. **Lo único compartido** es un helper mínimo y genérico, sin nada de git: `shfmt --to-json | jq` → una lista de comandos (`exe`, `args`, `dir` efectivo, `env`), pelando wrappers comunes (env, sudo, exec, xargs, command, time, nice, nohup) y marcando lo opaco (`$VAR`, `$(…)`, eval, `bash -c` con cuerpo no literal, process substitution, parseo fallido). Si crece más allá de eso, está mal.
3. **merge-develop-guard**: de la lista toma los `gh pr merge` / `glab mr merge|accept` / `gh|glab api …/merge` / `curl` a la API de la forja; los flags (`--squash`, `--delete-branch`) salen de sus args; destino, origen y repo se los pregunta a gh/glab en el directorio de ese comando; autorización = juez + grant. Opaco con `merge` a la vista → juez con destino desconocido. Push a develop/main → solo el AVISO si el servidor dice que la rama no está protegida (GitHub `gh api repos/<slug>/branches/<rama>` campo `protected`; GitLab `protected_branches` con comodines; 403 sin Pro = avisa 1×/sesión/repo; no se sabe = silencio).
4. **proteger-arbol**: identifica el comando destructivo por `exe`/`args` del helper; si orfanaría trabajo lo pregunta a git (`git rev-list @{u}..HEAD`, `git branch --merged`) y al estado del MR/PR, no a heurísticas.
5. **entorno-maquina-guard, no-bypass-deploy, barrer-ramas, cerrar-slice.sh, install-brain.sh**: dejan de cargar la biblioteca; lo que necesiten del comando sale del helper.
6. **ramas-zombie / limpiar / barrer-ramas**: «¿esta rama ya entró?» lo responde primero la forja (MR/PR mergeado) y luego git (ancestro de la base); las heurísticas de equivalencia de parche y de texto se quedan solo si una prueba de uso real demuestra que hacen falta.
7. **Pruebas**: las ~21 baterías ad hoc del guard se reemplazan por UNA tabla `comando → veredicto esperado` (frena / pasa / avisa) que corre contra el guard completo: todos los falsos positivos de docs/guards-falsos-positivos.md, los comandos diarios legítimos y las evasiones del merge a main. Cada caso nuevo es un renglón.
8. **Comentarios**: solo el porqué no obvio; la historia de cada parche se va (va en commits y memoria).
9. **Diagramas 03/06/07 y docs** (CLAUDE.md, MEMORY.md, normas, README) al final, describiendo solo lo vigente.

## Criterio de cierre (lo verifica claudio-master)
- La biblioteca ya no existe y nada la carga (`grep -r analizar-comando-git brain/` vacío, salvo la línea `retirado` del MANIFEST).
- La tabla de comandos completa pasa: cero frenos en falso y cero evasiones del merge a main y a develop coordinado.
- Re-auditoría independiente sin críticos ni altos.
- Menos código: el total de git medido igual que arriba baja de forma clara; se reporta el antes y el después.
- CI de develop verde; prueba en vivo de claudio; release a main por claudio (autorizado por unjordi).

## Ajuste de unjordi (2026-11-09 ~23:45)
[user: "Lo que más nos importa ahorita es la funcionalidad bien portada, no las pruebas! ... primero hacemos bien la funcionalidad la revisamos y luego la comparamos con nuestro Corpus"] → orden: portar la funcionalidad bloque por bloque, claudio revisa el código de cada uno, la comparación con el corpus va al final.
**no-bypass-deploy y entorno-maquina-guard: SIN DECISIÓN.** unjordi preguntó si iban a desaparecer ("Pero al menos el no bypass y el de entorno máquina, no?"); era pregunta, no orden. Mientras no decida, siguen en el plan original: solo dejan de cargar la biblioteca.
