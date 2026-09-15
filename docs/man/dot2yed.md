# dot2yed

**Sinopsis:** `python3 bin/dot2yed.py <entrada.dot> <salida.graphml>`

## Qué hace
Convierte un `.dot` de Graphviz a un `.graphml` editable en yEd, PRESERVANDO estilo (posiciones, tamaños, colores, formas, clusters como grupos). Requiere `dot` (graphviz) en el PATH.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `<entrada.dot>` | (posicional, requerido) Archivo DOT de entrada. |
| `<salida.graphml>` | (posicional, requerido) Archivo GraphML de salida. |

## Ejemplos
```bash
python3 bin/dot2yed.py docs/mapa-flujos.dot docs/mapa-flujos.graphml
```

## Notas
- Requiere `dot` (graphviz) en el PATH.
- El resultado abre en yEd YA ACOMODADO (con el layout de Graphviz).
