# broker-scan

**Sinopsis:** `broker-scan.sh scan`

## Qué hace
Helper interno del plasmoid KDE "Cortex Widget" (pestaña Broker). Escanea el estado del term-broker systemd user service y emite UN objeto JSON en stdout con: `generado_en`, `unidad` (cortex-term-broker.service: activa, habilitada, en_disco, estado, desde, pid, memoria_bytes, memoria_pico_bytes, reinicios), `legacy` (axon-term-broker.service: solo nombre/activa/habilitada/en_disco), `endpoint` (puerto, socket, permisos, dueño desde `~/.config/cortex/term-broker.env`), `token` (presencia del token), y `migrador` (ruta y ejecutabilidad de `migrar-term-broker.sh`).

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `scan` | Único subcomando válido: emite el JSON de estado del broker. |

Sin subcomando o con uno desconocido → imprime `Uso: broker-scan.sh scan` a stderr y `exit 2`.

## Ejemplos
```bash
broker-scan.sh scan
```

## Notas
- **Helper interno del widget**: lo invoca el DataSource "executable" de Plasma, no el usuario directamente.
- Requiere `systemctl --user` (systemd user session) y `ss` (util-linux) para el probe del endpoint.
- Lee `~/.config/cortex/term-broker.env` para puerto/socket/token.
- Busca `migrar-term-broker.sh` en `~/.local/bin/`, `~/.cortex/bin/`, `~/code/cortex/bin/`.
