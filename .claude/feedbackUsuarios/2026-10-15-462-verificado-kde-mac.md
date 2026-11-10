# #462 (widget GNOME, 12b5505): verificación de no-regresión en Mac y cachy (claudio-master)

- **Mac:** el #462 no toca `macos/install.sh` → sin cambio que probar.
- **cachy (KDE):** install.sh no tiene dry-run y correrlo instalaría la épica antes del cierre acordado, así que probé la pieza nueva: el bloque de detección de escritorio de 12b5505, corrido tal cual en la cachy → por SSH (XDG vacío) = kde (por kpackagetool6), con XDG=KDE = kde, con XDG=GNOME = gnome. El cuerpo de KDE solo cambió su condición de entrada.
- **uninstall.sh:** solo agrega el retiro de la extensión de GNOME (rm -rf del dir + gsettings si existe); en KDE es no-op.
- La instalación REAL en las dos máquinas se prueba en la instalación de cierre de la épica (desde develop). GNOME en sí lo validó Carlitos.
