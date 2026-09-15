# mmd2dot

**Sinopsis:** `python3 bin/mmd2dot.py -i <entrada.mmd|.md> -o <salida.dot> [--png <salida.png>] [--dpi <n>] [--rankdir LR|TB|RL|BT]`

## Qué hace
Convierte un `erDiagram` de Mermaid a Graphviz DOT que se renderiza bonito (self-loops limpios, crow's-foot aproximado, nodos-tabla estilo lavanda). Encadena natural con `dot2yed.py`.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `-i`, `--input` | (requerido) Entrada `.mmd` o `.md` (extrae el 1er bloque ```mermaid). |
| `-o`, `--output` | (requerido) Salida `.dot`. |
| `--png <ruta>` | Además, renderiza a este PNG con `dot`. |
| `--dpi <n>` | DPI del PNG (default 150). |
| `--rankdir <dir>` | Dirección del layout: `LR` (default), `TB`, `RL`, `BT`. |

## Ejemplos
```bash
python3 bin/mmd2dot.py -i entrada.mmd -o salida.dot
python3 bin/mmd2dot.py -i doc.md -o salida.dot --png salida.png --dpi 150
python3 bin/mmd2dot.py -i doc.md -o salida.dot --rankdir TB
```

## Notas
- Requiere solo stdlib de Python 3. Para `--png`: `dot` (graphviz) en el PATH.
- Soporta HOY: `erDiagram`. NO soporta aún: flowchart / graph / classDiagram / stateDiagram / sequenceDiagram.
