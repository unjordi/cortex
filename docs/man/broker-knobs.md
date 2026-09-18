# broker-knobs

**Sinopsis:** `broker-knobs.sh {list | set <ENV_VAR> <valor> | unset <ENV_VAR>}`

## Qué hace
Helper interno de ESCRITURA de la pestaña Broker del widget KDE. Edita `~/.config/cortex/term-broker.env` de forma atómica (tmp + mv, umask 077), validando cada knob contra el spec (`broker-knobs.tsv`). Solo escribe variables declaradas con `gui=edita`; el TOKEN nunca se lee ni se imprime (se conserva byte a byte). Ningún cambio aplica hasta reiniciar el servicio.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `list` | Emite JSON con el spec de knobs + el valor actual de cada uno. |
| `set <ENV_VAR> <valor>` | Escribe el knob validado contra el spec (tipo, rango, `cero_apaga`). |
| `unset <ENV_VAR>` | Devuelve el knob a su default (comenta la línea). |

Sin subcomando o desconocido → `uso: broker-knobs.sh {list|set <ENV_VAR> <valor>|unset <ENV_VAR>}` a stderr, `exit 2`.

## Ejemplos
```bash
broker-knobs.sh list
broker-knobs.sh set MAX_SESSIONS 16
broker-knobs.sh unset MAX_SESSIONS
```

## Notas
- **Helper interno del widget**: lo invoca el DataSource "executable" de Plasma, no el usuario directamente.
- El archivo editado contiene el TOKEN del broker: quien lo tenga puede ejecutar comandos como ese usuario. El TOKEN no es un knob y no se puede set/unset.
- Variables solo-lectura (BIND, PORT, SOCKET, HOME) se rechazan con un mensaje explicativo.
- Requiere el spec `broker-knobs.tsv` (buscado junto al script, en `../../widget-spec/`, `~/.cortex/src/widget-spec/`, `~/code/cortex/src/widget-spec/`).
- Variables de entorno opcionales: `BROKER_KNOBS_ENV` (ruta del .env), `BROKER_KNOBS_SPEC` (ruta del spec).
