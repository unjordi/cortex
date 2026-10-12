# seed.sh — el resolver `target → repo local` NO puentea el MISMO folder con distinto MOUNT ROOT por máquina

**Fecha:** 2026-09-24 · **Reportado por:** claudio-master (sesión madre, corriendo en plantilladotnet)
**Componente:** sincronización de sesiones master — `brain/sesiones-master/seed.sh` (la mitad "sembrar")
**Severidad:** MEDIA — deja el sync master **a medias** (export sí, seed no) para un caso NORMAL.

## Qué pasó
Reviso si `games-master` (vive en Cachy, su "repo" es la carpeta de Google Drive `Juegos`) se puede
**resumir en la Mac** vía el sync de sesiones master. El export está impecable: el `.jsonl.gz` (83 MB) y
el cerebro (`Juegos/.claude/`) están en el Drive, bajados. Pero **nunca se sembró en la Mac** y `seed.sh`
**lo saltaría** al correrlo aquí.

## Causa (verificada, no supuesta)
- `seed.sh` resuelve el `target` de `masters.json` contra las rutas locales **solo** con: case-insensitive
  + (por lo que documenta el header) el swap `/Users↔/home`. Regla: "repo que en esta máquina NO está
  clonado → se SALTA".
- El `target` de games-master es `/run/media/unjordi/SteamAndFiles/GoogleDrive/Juegos` (Insync en Cachy).
  En la Mac, **el MISMO folder de Drive** es `/Users/unjordi/Mi unidad/Juegos` (Drive nativo). Es **otro
  mount root completo**, NO un swap `/Users↔/home` ni diferencia de mayúsculas → el resolver no lo puentea
  → skip.
- El MOTOR está bien: `session-import.js` **re-ancla correctamente al `--repo` que se le pase** (deriva el
  slug local, reescribe el cwd, maneja `/Users↔/home↔C:\`). Verificado con siembra MANUAL:
  `node session-import.js --repo "/Users/unjordi/Mi unidad/Juegos" --sessions-dir "$CLAUDE_SESSIONS_DRIVE" --only 0204409d-…`
  → `ok:true`, slug `-Users-unjordi-Mi-unidad-Juegos`, cwd reescrito en 10,148 líneas, 141 MB, resumible.
  **El gap es exclusivamente el resolver `target → --repo` de `seed.sh`**, no el import.

## Por qué importa (es el caso NORMAL, no una rareza)
Una carpeta de Google Drive compartida entre máquinas tiene **rutas absolutas totalmente distintas** por
plataforma/cliente:
- Linux + Insync: `/run/media/…/GoogleDrive/Juegos` (o `~/Insync/…`)
- macOS nativo: `/Users/<u>/Mi unidad/Juegos`
- Steam Deck: `~/juegos`

Cualquier master cuyo "repo" sea una carpeta de Drive así **no se auto-siembra** en las otras máquinas →
el "que se sincronice entre las dos" queda incompleto (export automático sí; seed automático no).

## Fix sugerido (propone claudio-master; decide cortex-master/unjordi)
`seed.sh` necesita una EQUIVALENCIA de rutas cross-máquina más allá de case + `/Users↔/home`. Opciones con
su trade-off:
- **(a) Mapa de equivalencias per-máquina** (config: "carpeta de Drive X = esta ruta aquí"). Explícito,
  robusto; requiere sembrar el mapa una vez por máquina.
- **(b) Resolver por CONTENIDO** — la carpeta local que contiene el MISMO `.claude/` (match por marca/
  contenido, no por ruta). Cero config, pero más lógica.
- **(c) Clave machine-agnostic en `masters.json`** — guardar la ruta RELATIVA al root de Drive (+ un id de
  "drive-project") además del `target` absoluto; el resolver arma la ruta local con el root de Drive de
  ESTA máquina (`$CLAUDE_SESSIONS_DRIVE` ya conoce el root de Drive local).
- **(d) Match por basename** (`Juegos`) + heurística "es carpeta de Drive". Simple pero frágil ante
  homónimos.

Mi voto: **(c)** encaja con lo que ya existe (el root de Drive per-máquina ya se conoce vía
`CLAUDE_SESSIONS_DRIVE`), y es determinista.

## Workaround vigente (mientras tanto)
Sembrar a mano: `session-import.js --repo <ruta-local-del-folder-Drive> --sessions-dir "$CLAUDE_SESSIONS_DRIVE" --only <id>`.
Ya aplicado para games-master en la Mac (id `0204409d-c792-4021-84a9-c3f8f33843b9`).

## Nota aparte (menor)
`masters.json` tiene **3 entradas** `games-master` (ids `0204409d` target `…/Juegos`, `8ed4c05b` target
`…/Juegos`, `9cfeed6b` target `…/Juegos/.claude/memory` ← target claramente mal, apunta a un subfolder).
No bloquea el resume (se elige el id correcto), pero conviene deduplicar y corregir esa 3ª entrada.
