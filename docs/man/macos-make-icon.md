# macos-make-icon

**Sinopsis:** `./macos/make-icon.sh`

## Qué hace
Genera `macos/build/AppIcon.icns` a partir de los SVG maestros compartidos (`assets/icon.svg` para tamaños ≥128 y `assets/icon-small.svg` para 16/32). Rasteriza cada tamaño con `rsvg-convert`, arma un `.iconset` y lo empaqueta con `iconutil`. Imprime la ruta del `.icns` resultante.

## Opciones / argumentos
No acepta flags ni argumentos.

## Ejemplos
```bash
./macos/make-icon.sh
```

## Notas
- Requiere `rsvg-convert` (librsvg): `brew install librsvg`.
- Requiere `iconutil` (macOS estándar).
- Faltan los SVG en `assets/` → `exit 1`.
- Escribe en `macos/build/AppIcon.iconset/` y `macos/build/AppIcon.icns` (sobrescribe).
