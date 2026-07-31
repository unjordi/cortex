---
name: zoom-screenshot
description: Leer/transcribir capturas de pantalla cuyo texto fino es ilegible al verlas enteras — recortando y ampliando regiones con ffmpeg antes de leerlas. Usar cuando el usuario deja un screenshot (menús, ajustes, UIs densas) y hay que leer texto pequeño con precisión, o transcribir varias capturas.
---

# Leer/ampliar capturas para transcribir UIs

Técnica validada el 2026-06-26 (transcribir todos los menús de Configuración de Steam).

## El problema
La herramienta Read **reduce** la imagen a un presupuesto de píxeles fijo. Una captura alta/hi-res (p.ej. 1077×1389 o 3440×1440) se ve borrosa y el texto fino es **ilegible**. Ampliar la imagen ENTERA NO ayuda (Read la vuelve a reducir). La solución es **RECORTAR** (menos área = más resolución efectiva por píxel mostrado).

## Herramientas en el Deck
`ffmpeg` ✓, `rsvg-convert` ✓, `python3` ✓. **NO** hay ImageMagick ni PIL. Usar **ffmpeg** para recortar/escalar.

## Receta
1. Dimensiones de la imagen (sin PIL):
```bash
python3 -c "import struct;d=open('IMG.png','rb').read(33);w,h=struct.unpack('>II',d[16:24]);print(w,h)"
# o: ffprobe -v error -show_entries stream=width,height -of csv=p=0 IMG.png
```
2. Recortar región y ampliar (`crop=W:H:X:Y` = ancho,alto,offsetX,offsetY):
```bash
ffmpeg -y -i IMG.png -vf "crop=920:560:155:820,scale=1840:-1:flags=lanczos" out.png
```
Para una página alta, partir en **mitad superior e inferior** (mismo X/W, distinto Y) y leer ambas. Recortar el panel de contenido (excluir la barra lateral) sube la legibilidad. Escalar a ~1600–1850 px de ancho.
3. `Read out.png`.

## Para MUCHAS capturas
Repartir en **subagentes en paralelo** (Agent tool, general-purpose), cada uno con su lote: que recorte+amplíe con ffmpeg y devuelva SOLO la transcripción en markdown. Mantiene limpio el contexto principal y es rápido. Darle a cada agente nombres de archivo únicos (prefijo por lote) para no chocar en el scratchpad.

## Cuidado
- **Verificar siempre la salida cruda**: un grep de "4 dígitos" me hizo confundir el ID de GPU "0932" con un PIN. No asumas — confirma el contexto del número/texto.
- `crop` que se sale de los límites → ffmpeg falla (exit ≠ 0). Ajustar W/H/X/Y a las dimensiones reales (usar `in_w`/`in_h` ayuda: `crop=in_w-160:560:155:380`).

Relacionado: [[steam-ui-referencia]] (caso de uso: se transcribieron ~20 secciones así).
