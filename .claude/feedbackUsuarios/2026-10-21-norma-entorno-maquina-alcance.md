# Norma «El entorno de MÁQUINA vive GLOBAL, jamás en un repo»: precisar el alcance

- Intención [user 2026-10-21: "la norma del cerebro dice que el entorno de la máquina nunca vive en un repo porque siempre la ponían en sus propios slugs..."]: prohibirlo en el repo de un PROYECTO (viaja por git y miente al clonar en otra máquina).
- La redacción actual («jamás en un repo») se lee como absoluta: claudio-master la citó como objeción al mover el entorno de la Mac a `PowerScripts/.claude/memory/mac-entorno.md` (con `~/.claude/entorno-maquina.md` como symlink), y eso es justo lo correcto: PowerScripts ES el repo de setup de las máquinas de unjordi.
- Edición [user 2026-10-21: "nomás pon la edición como «jamás en el repo de un proyecto ni en tu slug». casi nadie tiene un repo de setup"]: cambiar «jamás en un repo» por «jamás en el repo de un proyecto ni en tu slug». Sin mencionar repos de setup.

## Revisión de c2d5664 (claudio 10:52)
- Texto correcto en norma, guard (comentario + MSG), install-brain y flowchart 13.
- Quedaron 4 copias con el texto viejo «jamás en un repo» (doc=realidad, rastrear copias): macos/Sources/Cortex/PopoverView.swift:1405, src/plasmoid/contents/ui/main.qml:1029, windows/src/Cortex/PopupForm.cs:1996 (la ficha del guard en los 3 widgets) y como-trabajar-con-usuario.example-barebones.md:14. Lo de feedbackUsuarios/ y la línea histórica de MEMORY.md:203 es historia, se queda.
- Reproductor: `git grep -n "jamás en un repo" -- macos src windows "*.example-barebones.md"`.
