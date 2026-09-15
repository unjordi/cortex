# chats-extract

**Sinopsis:** `node bin/chats-extract.js [ruta]`

## Qué hace
Extractor robusto de la lista de conversaciones del app de escritorio de Claude, leyendo su cache LOCAL de IndexedDB. Sin red. Hace un snapshot del dir IndexedDB a /tmp, localiza el blob que contiene `conversations_v2`, descomprime Snappy, deserializa el grafo de objetos V8 (ValueSerializer) y cosecha los objetos que "parecen" conversación. Salida: JSON array de `{uuid, title, summary, model, updated_at, created_at}` ordenado por `updated_at` descendente.

## Opciones / argumentos
| flag / arg | qué hace |
|---|---|
| `[ruta]` | (posicional, opcional) Ruta a: el directorio IndexedDB del app (default en macOS: `~/Library/Application Support/Claude/IndexedDB`), el subdirectorio `..._0.indexeddb.blob`, o un archivo de blob concreto (p.ej. `.../blob/1/1b/1b24`). Si se omite, se usa la ruta default según el SO. |

No acepta flags.

## Ejemplos
```bash
# Con la ruta default (macOS)
node bin/chats-extract.js

# Indicando explícitamente el dir IndexedDB
node bin/chats-extract.js ~/Library/Application\ Support/Claude/IndexedDB

# Apuntando a un archivo de blob concreto
node bin/chats-extract.js ~/Library/Application\ Support/Claude/IndexedDB/app_0.indexeddb.blob/blob/1/1b/1b24
```

## Notas
- Requiere `node`.
- La DB está viva; el script hace un snapshot a /tmp antes de trabajar.
- Rutas default por SO: macOS `~/Library/Application Support/Claude/IndexedDB`, Windows `%APPDATA%/Claude/IndexedDB`, Linux `~/.config/Claude/IndexedDB`.
