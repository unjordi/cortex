# Siguiente hito: cortex se publica desde un repo nuevo

Decisión de unjordi (2026-10-23), mismo modelo que PowerScripts → winturbo:
- El repo actual pasa a ser INTERNO (renombrarlo, p. ej. cortex-interno, y hacerlo privado) — último paso, cuando el equipo ya no dependa de él.
- Repo PÚBLICO nuevo (idealmente con el nombre unjordi/cortex, para que las URLs actuales sigan sirviendo) con un árbol curado: un manifiesto de publicación lista lo que viaja (brain/, src/, macos/, windows/, instaladores, doc de uso); memoria, buzón, docs internas e historia NO viajan.
- Script de publicación: un commit por release, sin historia.
- Chequeo de publicación que falla con datos personales/de máquina o secretos en lo publicado.
- Precondiciones de hacerlo privado: updater del widget y bootstrap leen del público; instalaciones del equipo y repos compartidos (plantilladotnet / sincronizar-cerebro) migrados.
- Gates vivos en lo publicado: sin datos personales (8 hooks, skills, sesiones-master, app de macOS), código utilitario sin historia de decisiones, instalación en limpio por plataforma, CI verde en el público, sin FPs vivos, idioma (decisión de unjordi).
Detalle y estado: ~/Desktop/pendiente-merge-cortex.xlsx (pestaña «Siguiente hito») en la Mac de unjordi.
- Gate agregado por unjordi (2026-10-23): la distribución NO puede incluir clonar el repo — macOS .app; Windows .msi/.exe o script PowerShell estilo winturbo (irm | iex desde release asset); Linux Flatpak o equivalente. Hoy bootstrap.sh/.ps1 hacen git clone y el updater de los 4 widgets usa git fetch/checkout sobre el clon.
- Idioma (unjordi 2026-10-23): la publicación va en español e inglés.
- Modelo de amenaza (unjordi 2026-10-23): "confío en claude. y es responsabilidad de cada quién saber que los modelos LLM no son perfectos ni omniscientes." → los guards protegen de ERRORES del agente, no de evasión deliberada; la ofuscación a propósito (base64, script aparte, $(…) armado) queda como BAJO documentado. El permiso durable de merge se queda.
