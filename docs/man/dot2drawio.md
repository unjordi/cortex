# dot2drawio

**Sinopsis:** `python3 bin/dot2drawio.py <entrada.dot> <salida.drawio>`

## Qué hace
Convierte un `.dot` de Graphviz a un `.drawio` editable en draw.io, PRESERVANDO layout y estilo: un vértice por nodo
(forma, relleno, borde, texto), un contenedor por cada `cluster_*` con sus nodos adentro, etiquetas HTML de dot tal
cual y aristas con la ruta que calculó Graphviz. Requiere `dot` (graphviz) en el PATH. Gemelo de `dot2yed`.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `<entrada.dot>` | (posicional, requerido) Archivo DOT de entrada. |
| `<salida.drawio>` | (posicional, requerido) Archivo draw.io de salida. |

## Ejemplos
```bash
python3 bin/dot2drawio.py docs/flowcharts/03-enforcement-git-guards.dot 03.drawio
drawio -x -f png -e -b 10 -o 03.drawio.png 03.drawio   # exporta con el diagrama embebido
```

## Notas
- Requiere `dot` (graphviz) en el PATH.
- El resultado abre en draw.io YA ACOMODADO (con el layout de Graphviz); de ahí se reacomoda a mano.
