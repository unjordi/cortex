# macos-make-app

**Sinopsis:** `./macos/make-app.sh`

## Qué hace
Compila el binario de release con Swift y ensambla `Cortex Widget.app` bajo `build/`. Regenera el ícono desde `assets/icon.svg` (vía `make-icon.sh`), copia el binario, `Info.plist`, el ícono `.icns`, empaqueta el brain dentro del .app, genera `version.json` (sha, fecha, repo, branch, versión) para el autoupdate, y hace ad-hoc codesign. Imprime la ruta absoluta del .app resultante.

## Opciones / argumentos
No acepta flags ni argumentos.

## Ejemplos
```bash
./macos/make-app.sh
```

## Notas
- Requiere Swift toolchain (`swift build`) y `rsvg` (o un `.icns` previo) para el ícono.
- Requiere un repo git válido en la raíz del proyecto para generar `version.json` (sha, commit count, branch).
- El ad-hoc codesign (`codesign --force --sign -`) es opcional: si falla, continúa.
- Escribe en `build/Cortex Widget.app/` (sobrescribe si existe).
