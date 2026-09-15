# cortex-term-broker

**Sinopsis:** `cortex-term-broker`

## Qué hace
Lanza el BROKER DE TERMINAL de cortex (opt-in, Linux). Sirve un shell de ESTA máquina por DOS transportes (socket UNIX + 127.0.0.1:8799) con el mismo token. Lo consume axon para que el widget de Terminal de Odysseus dé la computadora real.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| *(ninguno)* | No acepta flags propios. Toda la configuración es por variables de entorno (ver Notas). |

## Ejemplos
```bash
cortex-term-broker
```

## Notas
- **REQUERIDO:** `AXON_TERM_BROKER_TOKEN` — sin él el broker NO arranca.
- `AXON_TERM_BROKER_SOCKET` (default `$XDG_RUNTIME_DIR/axon/term-broker.sock`; `off` lo desactiva).
- `AXON_TERM_BROKER_PORT` (default 8799).
- `AXON_TERM_BROKER_BIND` (default 127.0.0.1).
- `AXON_TERM_BROKER_HOME` (default `$HOME`).
- `AXON_TERM_BROKER_MAX_SESSIONS` (default 32).
- `AXON_TERM_BROKER_MAX_PTYS` (default 32).
- `AXON_TERM_BROKER_WS_HIGH_WATER` (default 1 MiB).
- `AXON_TERM_BROKER_WS_MAX_BUFFER` (default 8 MiB).
- `CORTEX_TERM_BROKER_LIB` (override de la lib vendorizada).
- Requiere `node` >=22 (por `--experimental-strip-types`).
