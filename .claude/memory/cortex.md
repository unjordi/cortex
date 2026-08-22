---
name: cortex
description: "Widget KDE+macOS+Windows de límites de uso de Claude; repo propio github.com/unjordi/cortex (fork de fuziontech restyleado al look FelixDes)"
metadata: 
  node_type: memory
  type: project
  originSessionId: f59bc25a-fdde-4d83-80c0-f29da9699946
---

Widget de escritorio open-source que muestra los límites de uso de Claude (sesión 5h + semanal de claude.ai), en **paridad macOS/Linux/Windows**.

## Casa canónica e instalación
- **Fuente de verdad ÚNICA:** repo propio **`github.com/unjordi/cortex`** (fork público de fuziontech), clonado en `~/code/cortex`. El código y el CEREBRO de Claude (`.claude/`) viajan juntos por el repo. `origin`=tu fork; `upstream`=fuziontech (jalar mejoras / eventual PR upstream).
- **En otra máquina:** clonar y `bash .claude/bootstrap-claude.sh` una vez (enlaza la memoria al slug de esa máquina; skills se autocargan).
- **Instalar el plasmoid (KDE):** `kpackagetool6 -t Plasma/Applet -i/-u <path>/src/plasmoid` (no hay `just`). Preview: `plasmoidviewer -a <path>` + spectacle. Recargar: `kquitapp6 plasmashell && kstart plasmashell`. `ccusage` global vía pkexec (su binario nativo necesitó `chmod +x`).
- **Instalar Windows:** `pwsh -File windows/install.ps1` → publica un `.exe` self-contained single-file (~110 MB) a `%LOCALAPPDATA%\Programs\ClaudeBrain` + autoarranque `HKCU\...\Run`.
- **QA de una rama sin merge:** `bootstrap` acepta `CLAUDE_BRAIN_REF` → `curl …/develop/bootstrap.sh | CLAUDE_BRAIN_REF=<rama> bash` (Win: `$env:CLAUDE_BRAIN_REF='<rama>'; irm …/develop/bootstrap.ps1 | iex`).

## De dónde salen los datos
- **% real (exacto):** endpoint OAuth `https://api.anthropic.com/api/oauth/usage` (el mismo de `/usage` de Claude Code), read-only (no gasta cuota). **NO es API pública documentada → puede romperse.**
- **Token:** llavero (mac) / `~/.claude/.credentials.json` (Linux/Win: `%USERPROFILE%\.claude\.credentials.json`). Prioridad: **login activo PRIMERO**, `CLAUDE_CODE_OAUTH_TOKEN` solo como fallback headless (invertido 2026-07-26: un env-token estático heredado de `launchctl setenv` pisaba el cambio de cuenta).
- **`$` API-equiv:** estimado por **ccusage** de transcripts LOCALES → **puede subestimar** (idea pendiente: etiquetar `≈ $X (local)`). Es lo ÚNICO que necesita Node+ccusage; sin él sale "—" y el resto funciona. En Windows el fetch es C# puro (`JsonDocument`, sin bash/jq/curl/Node) salvo ese `$`.
- **`account_email`** (footer): de `~/.claude.json` → `.oauthAccount.emailAddress` — **NO** está en `.credentials.json`/Keychain (que solo trae el token). Nuevo campo `account_email` en `state.json`; si null, cae al texto viejo.

## Arquitectura por-OS (paridad)
- **Linux/mac:** script bash `*/bin/cortex-fetch` (idéntico entre `macos/bin/` y `src/bin/` por convención) en timer/launchd cada 5 min → `state.json`+`stats.json`. macOS: launchd, token del Keychain, Node vía brew.
- **Windows:** app de bandeja **WinForms .NET 10** en `windows/` (sin upstream); **hace el fetch en C# ella misma** cada 5 min (piso 5.5 min) → `%LOCALAPPDATA%\cortex\{state,stats}.json` (mismo schema). Ícono de bandeja = 2 mini-barras SIN número (la bandeja es cuadrada; % y ⟳reset van a tooltip+popup).
- **BUILD de Windows en mac:** `dotnet build -p:EnableWindowsTargeting=true` → 0/0 (el .NET SDK cross-targetea). **RUNTIME/UI necesita Windows REAL** (`--shot`/`DrawToBitmap` de WinForms es Windows-only) → QA en VM/otra compu/Chunito (🪦#03b0d197a). Build req: **.NET 10 SDK**.

## Pestañas del popup (riel vertical izquierdo + StackLayout)
1. **Límites** (original; footer pineado al fondo, SIN ScrollView).
2. **Resumen:** 9 tarjetas 3×3 (tokens, días, modelo favorito, racha, costo, **Sesiones**=nº .jsonl, **Mensajes**=líneas user/assistant, **Hora pico**=histograma timestamps→hora local) + heatmap tipo GitHub. Fase 2 (Sesiones/Mensajes/Hora pico) se calcula de `~/.claude/projects/**/*.jsonl` con grep/awk (no jq, ~155 MB, ~4 s).
3. **Modelos:** barras apiladas por día + tabla in/out y %. Datos de `ccusage daily --json --breakdown`.
4. **Proyectos:** uso por carpeta `~/.claude/projects/<slug>`. Nombre bonito: `~/.claude.json .projects` (mapa keyed por ruta real) → slug (`/`→`-`) → `basename` vía jq; fallback al slug legible. Swift: `StatsProject`/`DayProject` en `QuotaModel.swift`.
5. **Cerebro:** infografía del cerebro global (🔒 INVIOLABLE → 💡 SKILLS). **Auto-refleja** tu `~/.claude` REAL (hooks+cableado, normas, skills), cara al usuario BINARIA (verde=bien/rojo=falta). **Curita 🩹**: botón que corre el `install-brain.sh` empaquetado y re-lee. Inspector `BrainInspector.swift`/`.cs` + `brain-scan.sh`. Catálogo curado a mano en `brainTiers` de cada GUI (skill `agregar-hook-cerebro`).
- Resumen/Modelos/Proyectos van en `ScrollView` individual; Límites no.

## GOTCHAS (el corazón — no perder)
- **`kpackagetool6 -u` NO reemplaza archivos si `KPlugin.Version` no cambió** (ni `-r`+`-i` fiable). Para iterar en vivo: **`command cp -rf src/plasmoid/contents/. ~/.local/share/plasma/plasmoids/<id>/contents/`** + recargar plasmashell. Para release real, **bumpea la Version**.
- **El `cp` de unjordi está aliaseado a `cp -i`** → sin TTY responde "no" y no sobrescribe. Usa **`command cp`**.
- **`plasmoidviewer` cachea/ignora los defaults de propiedades** (ej. `currentTab`) → verifica otras pestañas EN VIVO en el panel (clic), no con plasmoidviewer.
- **Dedup por `message.id` (OBLIGATORIO):** Claude Code escribe **una línea jsonl POR BLOQUE DE CONTENIDO** (thinking/tool_use/text separados), y cada línea repite el mismo `message.id` y el MISMO `usage` acumulado → sumar por línea **triplica** los tokens. Dedup con `seen[id]` en awk (campo `"id":"msg_..."` dentro de `"message":{}`). En mac/Linux ccusage ya deduplica; en Windows/fase-3 yo derivo days/models/projects del transcript → dedup por id a mano. **"Mensajes" SÍ cuenta líneas crudas** (paridad con el fetch), no turnos.
- **Zona horaria:** el timestamp crudo es UTC; ccusage `daily` agrupa por **día calendario LOCAL**. La fase 3 lo replica con `shiftDay()` en awk (suma `$OFF` horas, ajusta fecha ±1 con tabla días-por-mes/bisiesto). Sin esto, la madrugada (UTC-6) cae en el día UTC equivocado.
- **ccusage agrega TODOS los CLIs de IA de la máquina** (Claude Code + Gemini/Codex/OpenCode/Amp/Droid si están) → **Modelos/Resumen NO están acotados a Claude**; **Proyectos SÍ** (solo lee `~/.claude/projects`) → su total puede ser menor, no es bug. Para acotar Modelos/Resumen a Claude: ver `ccusage claude daily` (subcomando).
- **macOS — `popover.contentSize` (AppKit) y `.frame()` (SwiftUI raíz) son DOS fuentes de verdad que deben COINCIDIR a mano** (ambas `520×420`). No hay binding automático fiable: si difieren, el `NSHostingController` re-negocia el tamaño tras el 1er render y el popover se ve "saltado"/mal alineado. Si tocas el alto de una pestaña, actualiza los dos lugares juntos (`AppDelegate.swift` + `PopoverView.swift`; no hay ScrollView en Límites).
- **macOS — íconos del rail en bold** partían "Resumen" en 2 líneas → rail a 132pt + `lineLimit(1)`.
- **Reset semanal (fallback `basis:"cost"` cuando el endpoint cae):** NO adivines "próximo lunes 00:00 UTC" (el reset real de esta cuenta es **viernes 5am local = 11:00 UTC**). El fetch hereda el `resets_at` del run ANTERIOR *solo si ese run tenía `basis:"oauth"`* y sigue en el futuro (compara ISO-8601 "Z" lexicográficamente, válido). Aplica a `five_hour` y `weekly` en ambos `*/bin/cortex-fetch`.
- **Bandeja/tray:** (1) las mini-barras COLAPSAN a ancho 0 → la barra necesita `Layout.minimumWidth` (no solo `preferredWidth`). (2) el widget se EMPALMA con los vecinos → el panel reserva `Layout.min/preferred/maxWidth` de la compactRepresentation, **NO** `implicitWidth`. Etiqueta del `$`: `(API equiv local)`. unjordi lo tiene EN LA BANDEJA (no en el panel).
- **`$ duplicado` NO es bug:** five_hour y weekly coinciden al inicio de semana porque el semanal arranca = solo el bloque de 5h activo y se separa conforme avanza la semana (block vs weekly de fuentes distintas).
- **Refresh tras mover/renombrar sesión:** NO uses el fetch completo (lento) — re-corre SOLO `sessions-extract.js` y recarga al instante (`QuotaModel.refreshSessions` / `sessionsExtractSource` / `RefreshSessionsAsync`).

## Features de sesión (#104/#106)
- **Renombrar con contexto:** diálogo con `summary` DERIVADO (petición inicial ≤320 chars; salta saludos/`[…]`/`<command-message>`, concatena mensajes CON SUSTANCIA) + botón **"Sugerir nombre"** que hace `claude -p --no-session-persistence`. ⚠️ **La bandera `--no-session-persistence` es CLAVE:** sin ella cada sugerencia crea una sesión fantasma en el slug `/` (cwd=/) que consume cuota. Foundation `bin/sessions-extract.js` (campos `summary`+`slug`).
- **Mover sesión entre slugs:** `bin/session-move.js` mueve el `.jsonl`, RESPALDA en `~/.claude/session-move-backups/` y reescribe el `cwd` interno (para que `claude --resume` reanude coherente). Los 3 instaladores lo despliegan.

## Íconos (fuente ÚNICA = SVG)
`assets/icon.svg` (grande) + `assets/icon-small.svg` (cerebro simple + chispa gruesa para **≤32px**, nítido a 16px en el login item). Render con **rsvg-convert** (librsvg, prereq de macOS): `.icns` (`macos/make-icon.sh` + `iconutil`), plasmoid (`src/plasmoid/contents/icons/cortex.svg` + metadata `Icon: "cortex"`), Windows `.ico` (packer propio en python, 6 tamaños PNG — no hay ImageMagick). Diseño actual = **cerebro + chispa**; no volver a los previos (🪦#7faf66200).
- **Login item del daemon:** incrusta el ícono como ícono CUSTOM del archivo vía **`NSWorkspace.setIcon`** (`macos/set-icon.swift`). **NO uses Rez/SetFile** (dejan el resource fork a medias: 286 bytes rotos vs 214KB con setIcon) (🪦#f21a621da).
- **GOTCHA:** `make-app.sh`/fetch-icon deben **regenerar SIEMPRE el `.icns` desde el SVG, NO "solo si falta"** — un `.icns` rancio se queda pegado y se instala el ícono viejo (bug real). Ver skill `cambiar-icono`.

## Rebrand `claude-quota` → `cortex` (criterio para futuros cambios)
- **RENOMBRA lo visible/runtime:** `.app` "Claude Brain Widget", daemon `cortex-fetch`, launchd `io.github.unjordi.cortex`, systemd `cortex.{service,timer}`, cache `~/{Library/Caches,.cache}/cortex` (+ `%LOCALAPPDATA%\cortex`), logs `/tmp/cortex.*`.
- **CONSERVA lo invisible/que rompería:** dir de config **`~/.config/cortex`** (ahí viven `limits.env`/`machine-id`/`account`; moverlo pierde calibración+identidad de sync), env vars **`CLAUDE_BRAIN_ACCOUNT`/`_SYNC_DIR`**, User-Agent **`cortex`**, carpeta de nube **`cortex-sync`**, namespace **`ClaudeBrain`** (C#/Swift), **Id del plasmoid** (renombrarlo hace desaparecer el applet del panel), nombre del repo/dir.
- **Migración** idempotente en cada instalador: baja el daemon viejo, borra la app vieja, MUEVE cache viejo→nuevo (config quieto). Barre el bloque PATH viejo del rc (marcador `(claude, claude-quota-fetch)`) en `ensure_path_local_bin` (test `e8`), que antes dejaba un 2º bloque PATH duplicado.
- **Clon oculto del bootstrap (PR #138):** `bootstrap.sh` → `~/.cortex` (migra un clon viejo visible `~/cortex` vía `mv`); `bootstrap.ps1` → `%LOCALAPPDATA%\cortex-repo` (`-repo` para no chocar con el cache `%LOCALAPPDATA%\cortex` ni la app `%LOCALAPPDATA%\Programs\ClaudeBrain`). El autoupdate lo NECESITA (no se puede borrar tras instalar). `brain-scan.sh` conoce la ruta nueva.

## Autoupdate + política de release
- Cada GUI embebe `version.json` (sha+fecha+repo) al buildear; consulta `commits/main` y ofrece banner "Actualizar widget" que hace **ff a `origin/main` + reinstala** (fail-open; nunca te deja sin widget). **Solo es real desde un release a main con el clon limpio.** Detalle: `docs/autoupdate.md`.
- **ONE-STOP (paridad):** el instalador del botón es el COMPLETO (cerebro + widget): `install.sh`/`install.ps1` instalan el cerebro por defecto. El botón "🩹 Curar cerebro global" es self-heal SIN git pull.
- **DECISIÓN DURA (2026-07-26): cada push a `main` reconstruye TODOS los assets precompilados** de todas las plataformas. Se **quitó el filtro `paths:`** de `release-macos.yml`/`release-windows.yml` → cualquier push a main dispara reconstruir+publicar. **Por qué:** con path-filter, releases que no tocaban esos paths dejaban los assets rolling RANCIOS mientras main avanzaba → el autoupdate descargaba el asset viejo pero chequeaba `commits/main` → **loop infinito de "actualiza"**. El **dedupe-guard** (lee `build-sha:` del release rolling, salta build si == `github.sha`) se conservó en macOS y se AÑADIÓ a Windows. **Linux** = plasmoid QML sin compilar → sin asset precompilado (autoupdate git-based), sin workflow de release.
- ⚠️ **El botón "Actualizar widget" ensucia `develop` local si lo corres estando en `develop`** (caso dev, no usuario final): el `ff-only origin/main` empalma en develop local los merge-commits de TODOS los releases develop→main (diff de árbol vacío, pero `git status` marca "adelante N"). Fix: `git reset --hard origin/develop` (seguro SOLO con diff de árbol vacío — verifica antes). Blindaje posible: que el updater haga `ff-only` solo si la rama activa es `main`.

## Cuenta duplicada / flip-flop (RESUELTO 2026-07-06)
El widget saltaba entre dos cuentas (Sesión 5h llegó a 315.3%). **Causa raíz:** dos cuentas GENUINAMENTE distintas comparten el MISMO item del llavero (`Claude Code-credentials`, `acct=unjordi`), que guarda un solo token:
- **Terminal (CLI):** `jordi.serra@pind.mx` (accountUuid `0f969ded-…`, org PindDevelopment).
- **Claude.app (desktop):** `informatica@pind.mx` (accountUuid `25545a28-…`). El desktop trae su propio Claude Code integrado (`~/Library/Application Support/Claude/claude-code/<ver>`) que escribe el token OAuth en el MISMO item → el último login gana. (El Claude.app se autentica con cookies web cifradas; ese token del llavero es lo único compatible con `/api/oauth/usage`.)
- **Diagnóstico sin escanear el llavero a ciegas:** comparar `oauthAccount.accountUuid` de `~/.claude.json` (CLI) vs `lastKnownAccountUuid` de `~/Library/Application Support/Claude/config.json` (desktop).
- **Solución (unjordi):** `claude logout`+`login` en la terminal eligiendo la cuenta del desktop → terminal y desktop coinciden → sin flip-flop. **Fragilidad:** re-loguear la otra cuenta en la terminal lo reactiva (mismo cajón del llavero), pero se **ve** en el footer (cuenta activa). La prioridad del env-token sobre el login activo se invirtió por esto (🪦#b23fdf3c6).
- **Blindaje `account-guard` (opt-in, 3 plataformas):** fijas una cuenta esperada (uuid/email) en `~/.config/cortex/account` (override `$CLAUDE_BRAIN_ACCOUNT`; Win `%LOCALAPPDATA%\cortex\account`). Si la activa (de `~/.claude.json .oauthAccount`) difiere → el fetch marca `account_mismatch:true` y la UI avisa en ROJO. Windows tiene menú de bandeja "Fijar/Quitar cuenta"; mac/KDE editan el archivo a mano. Campos nuevos en `state.json`: `account_uuid`, `account_mismatch`. Sin pin ⇒ comportamiento previo.

## Pendientes / ideas
- Publicación en KDE Store (eventual).
- Paleta Nord opcional en vez de naranja: la nota `kde-tema-opaco` vive en la memoria GLOBAL per-máquina (`~/.claude/projects/-home-unjordi/memory/`), no en este repo (es tweak de máquina).
- "Mensajes" (Resumen) cuenta líneas crudas, no turnos reales → confirmar/arreglar si unjordi lo pide.
