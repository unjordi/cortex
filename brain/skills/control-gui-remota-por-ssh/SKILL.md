---
name: control-gui-remota-por-ssh
description: Ver y operar la GUI de escritorio de una máquina remota usando SOLO una sesión SSH (sin VNC/RDP disponible) — screenshot, clicks, teclado, inspección de ventanas/controles, portapapeles, lanzar/cerrar apps y procesos, todo scriptable y con evidencia (screenshot antes/después). Resuelve los DOS problemas duros que lo hacen no-trivial: (1) el AISLAMIENTO DE SESIÓN — una sesión SSH corre en otra logon-session y no ve el escritorio interactivo del usuario logueado — y (2) el DPI-AWARENESS — sin fijarlo, el screenshot sale truncado y los clicks se desvían. Windows (15 scripts `win-ssh-*.ps1`), Linux (13 scripts `linux-ssh-*.sh`, KDE Wayland) y macOS (13 scripts `mac-ssh-*.sh`) están COMPLETOS y verificados en hardware/sesión real. Úsalo cuando necesites ver/manejar una GUI de escritorio remota y NO tengas VNC/RDP/un navegador con visor web disponible — solo SSH; o como paso previo a `ingenieria-inversa-gui-db-navegador` (que asume navegador) cuando el objetivo es escritorio nativo, no web.
---

# Control de GUI remota por SSH

> El kit `win-ssh-*` está verificado en hardware real (2026-08-27) manejando una estación Windows
> sin noVNC disponible, solo por SSH. El kit `linux-ssh-*` está verificado en vivo (2026-09-18)
> contra `cachy` (CachyOS, KDE Plasma 6.7/Wayland) — screenshot, list-windows, launch, kill-process
> y clipboard confirmados de punta a punta; send-click/send-keys quedan construidos y correctos
> pero bloqueados en ESA máquina por un permiso pendiente de un humano (ver gotcha EIS más abajo).
> El kit `mac-ssh-*` está verificado LOCAL (2026-09-18) en esta Mac — screenshot, clipboard,
> get-processes-list, kill-process y list-windows confirmados; send-click/send-keys tienen el
> primitivo (cliclick/System Events) confirmado sin error, sin un click en vivo sobre UI real para
> no interferir con la sesión del usuario. Es una capacidad GENÉRICA del cerebro — cualquier
> sesión/máquina del equipo la tiene, sin depender de qué repo o proyecto la necesitó primero.

## Cuándo usar esto
Cuando la única vía de acceso a una máquina remota es una **sesión de terminal (SSH)** — no hay
VNC/RDP nativo, ni un visor web (noVNC/dockur) que un navegador pueda automatizar — y necesitas
**ver la pantalla y operar la GUI** igual que un usuario sentado enfrente: tomar un screenshot,
hacer clic en un botón, teclear en un campo, leer el mensaje de un diálogo, lanzar o cerrar una
app. Casos típicos: una estación de trabajo administrada sin acceso remoto gráfico habilitado, una
VM headless que solo expone SSH, diagnóstico/soporte remoto de una GUI legacy.

**NO uses esto si** ya tienes un navegador con automatización (`claude-in-chrome` u otro) apuntando
a un visor web de la máquina (noVNC, RDP-sobre-navegador) — ese caso lo cubre el skill
`ingenieria-inversa-gui-db-navegador`, que además trae el método de diffear BD/filesystem
alrededor de cada acción. Los dos son complementarios: éste resuelve el **transporte** (cómo ver y
tocar la pantalla cuando solo hay SSH); aquél resuelve el **método de RE** (cómo documentar con
evidencia). Nada impide usar este kit COMO el "driver" de ese método cuando el transporte es SSH en
vez de navegador.

## Los DOS problemas duros (por qué esto no es trivial)

### 1. Aislamiento de sesión (logon-session)
Una sesión SSH corre en una **logon-session distinta** a la consola interactiva del usuario
logueado. Desde SSH no puedes capturar la pantalla que ese usuario ve, ni enviarle clicks/teclas
que él "sienta" — el aislamiento de sesiones del SO lo impide.

**La solución (Windows, ya resuelta en los scripts):** despachar cada gesto (captura, click, tecla,
lanzar, cerrar) a la **sesión interactiva** con una tarea programada de **token interactivo**
(`schtasks /IT` en Windows — corre COMO el usuario logueado, en SU escritorio) en vez de ejecutarlo
directo en el proceso SSH. Los scripts crean la tarea, la disparan, esperan, y la borran — todo en
una sola invocación; tú solo los llamas.

### 2. DPI-awareness
Con escala de pantalla 125%/150% (común en laptops), sin marcar el proceso como DPI-aware:
- el **screenshot sale TRUNCADO** a la esquina superior-izquierda (reporta menos resolución de la
  real, p. ej. 1280×720 de una pantalla 1920×1080),
- los **clicks se DESVÍAN** (la coordenada se multiplica por el factor de escala y aterriza en el
  lugar equivocado).

**La solución (ya resuelta):** todos los scripts llaman `SetProcessDPIAware()` (Windows) antes de
capturar/clickear. El resultado: las coordenadas de un screenshot y las que espera un click son
**las mismas** — no hay que traducir entre "coords del visor" y "coords reales".

## El loop central (cómo operar, con cualquier plataforma)
1. **`screenshot`** — mira qué hay en pantalla ahora.
2. **`list-windows`** — qué ventanas hay abiertas (título, PID, rectángulo) si el screenshot no basta.
3. **`get-window-coordinates`** (o el equivalente de accesibilidad) — el centro de cada control de
   UNA ventana, para clickear con precisión en vez de adivinar píxeles sobre el screenshot.
4. **`send-click`** / **`send-keys`** en esa coordenada.
5. **`screenshot`** de nuevo — confirma el efecto. Repite.

Para leer el TEXTO de un diálogo sin depender del screenshot (más fiable que OCR): `read-text`
(controles clásicos) o `read-uia`/UI-Automation-equivalente (diálogos modernos que no exponen hijos
clásicos — ver gotcha abajo).

## Windows — COMPLETO, verificado en hardware real
15 scripts en [`win/`](win/), patrón `win-ssh-{acción}.ps1`, todos despachando a la sesión
interactiva vía `schtasks /IT` y DPI-aware donde aplica. **Verificados en vivo el 2026-08-27**
contra una estación Windows real por SSH (no simulado).

| Script | Qué hace |
|---|---|
| `win-ssh-screenshot.ps1` | Captura la pantalla (DPI-aware, VirtualScreen completo, multi-monitor). `-B64` la imprime en base64. |
| `win-ssh-send-click.ps1` | Click izq/der por coordenada `-X -Y` (`-Button right`, `-Double`, `-Window` para enfocar antes). |
| `win-ssh-send-double-click.ps1` | Doble-click por coordenada (abrir iconos/listas). |
| `win-ssh-send-keys.ps1` | Teclea `-Keys "texto{ENTER}"` (SendKeys: `{TAB}`,`^a`,`%{F4}`…); `-ClickX/-ClickY` enfoca por clic + teclea en el MISMO proceso (evita perder foco entre un click y un send-keys separados). |
| `win-ssh-list-windows.ps1` | Lista ventanas visibles: título, PID, X, Y, ancho, alto. `-Filter`, `-Csv`. |
| `win-ssh-get-window-coordinates.ps1` | De UNA ventana: rectángulo + el CENTRO de cada control (botón/edit/checkbox) — para clickear preciso. Controles Win32 clásicos. |
| `win-ssh-read-text.ps1` | Texto de una ventana + sus controles clásicos (Win32/Delphi). |
| `win-ssh-read-uia.ps1` | Texto por **UI Automation** — para diálogos MODERNOS (TaskDialog/DirectUIHWND) que `read-text` no ve. `-WithRect` da el centro de CADA elemento (incluso sin texto) listo para pasar a `send-click`. |
| `win-ssh-launch.ps1` | Lanza una app EN la sesión del usuario, con su entorno completo (drives mapeados). Default vía shell (`explorer`, como doble-clic real); `-Direct` = `Start-Process` (permite `-Args`). |
| `win-ssh-maximize-window.ps1` | Maximiza/restaura/minimiza (`-State`) una ventana por título. |
| `win-ssh-move-window.ps1` | Mueve/redimensiona una ventana a `-X -Y [-W -H]` — deja una ventana en posición CONOCIDA antes de clickear por coordenada. |
| `win-ssh-close-window.ps1` | Cierre GRACIOSO (`WM_CLOSE`, como la X) — puede disparar un diálogo "¿guardar?". |
| `win-ssh-clipboard.ps1` | `-Get` lee / `-Set "texto"` escribe el portapapeles de la sesión interactiva (STA). |
| `win-ssh-get-processes-list.ps1` | Lista procesos (top-N por RAM). NO necesita sesión interactiva. `-Name`, `-Csv`. |
| `win-ssh-kill-process.ps1` | Mata por `-Name`/`-Id` (`-WhatIf` primero si dudas). NO necesita sesión interactiva. |

Notas de límites (ya conocidas, no las re-descubras):
- `read-text`/`get-window-coordinates` ven controles **Win32 clásicos** (apps clásicas/Delphi SÍ).
  Apps **UWP** y **TaskDialogs modernos** no exponen hijos clásicos → para su texto usa **`read-uia`**;
  para lo visual, el screenshot.
- Los títulos de ventana están en el idioma del SO remoto (una estación en español dice "Bloc de
  notas", no "Notepad").
- Requisitos: correr COMO admin de la máquina (para crear tareas `/IT` del usuario logueado); el
  usuario objetivo debe tener una **sesión de consola activa** (si nadie está logueado, no hay
  escritorio que manejar); Windows PowerShell 5.1 (lo traen las estaciones). ASCII puro en los `.ps1`.

### Recetas de invocación (genéricas — sustituye host/usuario/llave/carpeta por los tuyos)
Parámetros que varían por caso, nunca hardcodeados en los scripts: `$JUMP` (host de salto si aplica,
`usuario@ip`), `$STA` (la estación destino, `usuario@ip` u hostname), `$KEY` (ruta a tu llave
privada). Si la estación no es alcanzable directo, añade `-J "$JUMP"` a `ssh` (ProxyJump).

**1) Desplegar un script a la estación** (base64 → `WriteAllBytes`, UN script por comando — no metas
dos grandes en un solo `-EncodedCommand`: pasa el límite de ~32 KB de línea de PowerShell):
```bash
KEY=/ruta/a/tu_llave ; STA=usuario@host-o-ip     # + -J "$JUMP" a ssh si hace falta salto
FB=$(base64 -i win-ssh-screenshot.ps1 | tr -d '\n')
printf '[IO.File]::WriteAllBytes("C:\\GuiSshWork\\win-ssh-screenshot.ps1",[Convert]::FromBase64String("%s"))' "$FB" > _dep.ps1
B=$(iconv -f UTF-8 -t UTF-16LE _dep.ps1 | base64 | tr -d '\n')
ssh -i "$KEY" "$STA" "powershell -NoProfile -EncodedCommand $B"
```

**2) Correr un script** (los que devuelven texto salen directo; usa `-OutputFormat Text`):
```bash
mk(){ iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\n'; }        # helper: script PS -> EncodedCommand
echo '& C:\GuiSshWork\win-ssh-list-windows.ps1 -Filter MiApp' > _r.ps1
ssh -i "$KEY" "$STA" "powershell -NoProfile -OutputFormat Text -EncodedCommand $(mk < _r.ps1)"
```

### Traer un screenshot a tu máquina
`-B64` imprime el PNG en base64 por stdout; decodifícalo tolerante con python (el `base64 -d` de
macOS a veces se atraganta con el stream de PowerShell — el filtro de python, que solo toma
alfabeto base64, decodifica limpio):
```bash
echo '& C:\GuiSshWork\win-ssh-screenshot.ps1 -Out C:\GuiSshWork\s.png -B64' > _r.ps1
ssh -i "$KEY" "$STA" "powershell -NoProfile -OutputFormat Text -EncodedCommand $(mk < _r.ps1)" > s.b64
python3 -c "import re,base64;open('s.png','wb').write(base64.b64decode(''.join(re.findall(r'[A-Za-z0-9+/=]',open('s.b64').read()))))"
# luego: abrir s.png, o leerlo directo con la tool de imagen de tu agente
```

**Flujo típico de principio a fin:** `launch` la app → `list-windows` para ver qué salió →
`screenshot` para ver / `read-uia`\|`read-text` para leer un mensaje → `get-window-coordinates` para
el centro del botón → `send-click` ahí → `screenshot` para confirmar.

### Gotchas de Windows (ya resueltos, no los re-descubras)
- `schtasks /tr` **sin comillas internas** alrededor del `.ps1` (si no, truena "no se encuentra el
  archivo"); la carpeta de trabajo **sin espacios** (los scripts usan `C:\GuiSshWork` por defecto,
  ajústala a una carpeta real sin espacios en la máquina remota).
- Nada de `$ErrorActionPreference='Stop'` en el cuerpo de estos scripts — el `schtasks /delete` de
  una tarea que todavía no existe (primera corrida) tronaría en falso.
- Un click y un `send-keys` despachados como DOS tareas `/IT` **separadas** pueden perder el foco
  entre uno y otro (la ventana activa cambia). `win-ssh-send-keys.ps1 -ClickX -ClickY` resuelve esto
  haciendo clic+tecleo en el MISMO proceso.
- Combos/dropdowns clásicos pueden responder mejor a teclado (`Down`+`Return`) que a clic directo en
  la lista desplegada — si un clic no reacciona, prueba el atajo de teclado antes de asumir que algo
  está roto.
- Ventanas maximizadas que se traslapan (una hija sobre su padre) pueden hacer que un clic pensado
  para "cerrar la hija" aterrice en el botón de cerrar del PADRE — verifica con
  `get-window-coordinates`/`read-uia -WithRect` el rectángulo exacto antes de clickear a ciegas.

## Linux — COMPLETO, verificado en vivo (KDE Wayland)
13 scripts en [`linux/`](linux/), patrón `linux-ssh-{acción}.ps1` → `.sh`, gemelos estructurales de
`win-ssh-*` (mismos nombres de flag: `-X -Y`, `-Window`, `-Csv`, `-WhatIf`…). Comparten
`linux/lib-linux-ssh-env.sh` (adaptación documentada respecto a Windows: como UN proceso hace todo
el gesto de punta a punta — a diferencia de Windows, que despacha CADA gesto como una tarea
independiente — una lib compartida de detección de entorno no genera drift entre 13 copias).
**Verificado en vivo el 2026-09-18** contra `cachy` (CachyOS, KDE Plasma 6.7, `kwin_wayland`).

| Script | Qué hace | Verificado en vivo |
|---|---|---|
| `linux-ssh-screenshot.sh` | Captura la pantalla (spectacle\|grim\|gnome-screenshot\|import, según compositor). Default = escritorio COMPLETO (todos los monitores, paridad con el VirtualScreen de Windows). `-Display <output>` (por nombre, ej. `HDMI-A-1`) para UN monitor. `-ActiveWindow` (solo spectacle/KDE) para la ventana con foco. `-B64`. | ✅ default 1920×1080 no-negro; ✅ `-Display HDMI-A-1` recortó igual al único output real; ✅ `-Display FAKE-99` cayó a pantalla completa con aviso; ✅ `-ActiveWindow` capturó SOLO el diálogo con foco (594×314, contenido distinto) — máquina de prueba con 1 solo monitor físico, cosido de 2+ reales sin confirmar visual |
| `linux-ssh-list-windows.sh` | Lista ventanas visibles vía `xdotool search` (solo X11/XWayland — ver límite abajo). `-Filter`, `-Csv`. | ✅ enumeró ventanas reales de la sesión |
| `linux-ssh-get-window-coordinates.sh` | Rectángulo + CENTRO de una ventana por título (solo nivel-ventana, ver paridad parcial). | Construido, mecanismo = list-windows |
| `linux-ssh-launch.sh` | Lanza una app en la sesión gráfica (`setsid`+entorno resuelto, sin mecanismo de despacho por-gesto — ver script). | ✅ abrió Kate real en pantalla (PID vivo + screenshot lo confirmó) |
| `linux-ssh-send-click.sh` | Click izq/der por coordenada `-X -Y` vía `xdotool` (`-Button right`, `-Double`, `-Window`). | Construido; bloqueado en cachy por el permiso EIS de KWin (ver gotcha) |
| `linux-ssh-send-double-click.sh` | Atajo de send-click `-Double`. | Mismo mecanismo que send-click |
| `linux-ssh-send-keys.sh` | Teclea `-Keys "texto{ENTER}"` (mini-lenguaje adaptado de SendKeys) vía `xdotool key/type`. `-ClickX/-ClickY`. | Construido; mismo gotcha EIS que send-click |
| `linux-ssh-move-window.sh` | Mueve/redimensiona una ventana por título `-X -Y [-W -H]`. | Construido (mismo primitivo `xdotool` que list-windows, ya confirmado) |
| `linux-ssh-maximize-window.sh` | Maximiza/restaura/minimiza (`-State`) una ventana por título. | Construido |
| `linux-ssh-close-window.sh` | Cierre GRACIOSO (`xdotool windowclose`) por título. | Construido |
| `linux-ssh-clipboard.sh` | `-Get` lee / `-Set "texto"` escribe el portapapeles (`wl-copy`/`wl-paste`, fallback `xclip`/`xsel`). | ✅ round-trip set→get confirmado, sin permiso EIS de por medio |
| `linux-ssh-get-processes-list.sh` | Lista procesos (top-N por RSS). NO necesita sesión gráfica. `-Name`, `-Csv`. | ✅ listó procesos reales |
| `linux-ssh-kill-process.sh` | Mata por `-Name`/`-Id` (`-WhatIf` primero). NO necesita sesión gráfica. | ✅ mató un proceso real (Kate) tras confirmar con `-WhatIf` |

### GOTCHA REAL Y CRÍTICO: el permiso EIS de KWin (Wayland) para input sintético
**Verificado 2026-09-18 en cachy.** La PRIMERA vez que `xdotool` intenta mover el mouse o mandar una
tecla en una sesión KDE Plasma/Wayland, KWin dispara un diálogo GRÁFICO — *"Control remoto: xdotool
está solicitando controlar dispositivos de entrada" → Permitir/Denegar* — que solo un humano frente
a la consola real puede resolver. Es el análogo Linux/Wayland exacto al permiso TCC de Accesibilidad
de macOS: una PRECONDICIÓN de una sola vez, no un bug del script. Hasta que se resuelve:
- El evento se **descarta en silencio** — `xdotool` sale con **exit 0 de todas formas** (protocolo
  fire-and-forget, no espera la decisión del diálogo). **El exit code NUNCA es evidencia de que el
  click/tecla aterrizó** — verifica SIEMPRE con un screenshot antes/después.
- El diálogo NO tiene timeout corto: quedó pendiente varios minutos en la prueba real sin cerrarse
  solo.
- Existe un atajo de configuración para el DUEÑO de la máquina (no algo que este kit haga solo, por
  ser un cambio de seguridad — de hecho el guard de permisos de Claude Code bloqueó el intento de
  aplicarlo por SSH durante esta verificación, correctamente):
  `kwriteconfig6 --file kwinrc --group Xwayland --key XwaylandEisNoPromptApps "xdotool"` +
  `qdbus6 org.kde.KWin /KWin reconfigure` — pre-autoriza `xdotool` sin volver a preguntar. Decisión
  del dueño de la máquina, no del script.
- **Solo afecta INPUT sintético** (click/tecla/mousemove vía XTest). Capturar pantalla, listar
  ventanas, mover/redimensionar ventanas y el portapapeles NO pasan por este gate — verificado que
  funcionan igual sin haber resuelto el diálogo pendiente.

### Límite real: xdotool/XWayland SOLO ve apps X11/XWayland, no Wayland nativas
**Verificado 2026-09-18:** al lanzar Kate (app Qt6/KDE nativa-Wayland) con `linux-ssh-launch.sh`, la
ventana abrió de verdad en pantalla (confirmado por screenshot) pero **`linux-ssh-list-windows.sh` no
la vio** — el compositor no la expone por XWayland. En cambio, apps que SÍ corren vía XWayland
(Steam y su navegador embebido, en la máquina de prueba) sí aparecen. No es un bug: es un límite
estructural de X11-sobre-Wayland. Para "ver qué hay" en apps Wayland nativas, el **screenshot** es la
única vía confiable — `list-windows`/`get-window-coordinates`/`send-click`-por-título/`close-window`
solo alcanzan ventanas X11/XWayland.

### Otros gotchas verificados
- **`wl-copy` se queda corriendo en segundo plano** (por diseño, para servir la selección) — correrlo
  en primer plano dentro de un comando SSH CUELGA la sesión esperando a que termine (nunca termina
  solo). `linux-ssh-clipboard.sh` ya lo lanza con `setsid ... & disown`.
- **`pgrep -f` auto-matchea su propio invocador**: un `-Name firefox` con `pgrep -f` matcheó también
  la shell que estaba corriendo el comando de PRUEBA (su propio argv contenía "firefox" porque ESE
  era el comando). `linux-ssh-kill-process.sh` usa `pgrep` SIN `-f` (matchea por `comm`, nombre
  corto) — mismo patrón ya documentado para `pkill -f` en la memoria del equipo, ahora confirmado
  también en `pgrep`.
- **`/proc/<pid>/environ` está bloqueado** (ptrace_scope) incluso same-user — el entorno de la
  sesión gráfica se deriva de rutas estándar (`XDG_RUNTIME_DIR`, sockets en ese dir) + el cmdline del
  compositor (legible por `ps` aunque `/proc/environ` no lo sea). Ver `lib-linux-ssh-env.sh`.
- **DPI-awareness: NO hizo falta.** A diferencia de Windows, Wayland/X11 entregan resolución FÍSICA
  tal cual — el screenshot verificado salió a resolución completa sin ningún equivalente a
  `SetProcessDPIAware()`.
- **Multi-monitor (QA 2026-09-18, ver cabecera de `linux-ssh-screenshot.sh`):** a diferencia de
  macOS, el modo default de spectacle/grim/gnome-screenshot/import YA es "todo el escritorio
  cosido en una imagen" — no hizo falta ninguna adaptación para el caso default. Lo que SÍ se
  agregó fue `-Display <output>` (recorte vía `kscreen-doctor`+`convert` en spectacle/KDE, nativo
  en grim) y `-ActiveWindow` (solo spectacle). `cachy` solo tiene 1 monitor físico — el recorte
  por-output se verificó mecánicamente (coincidió exacto con la imagen completa) pero el cosido
  visual de 2+ monitores reales queda sin confirmar.

### Paridad parcial documentada (no oculta)
- **`get-window-coordinates`** en Linux da el rectángulo/centro de la VENTANA, no de cada CONTROL
  individual (botón/checkbox) como su gemelo Windows — GTK/Qt dibujan sus widgets dentro de una sola
  X-window, sin "hijos" enumerables por API de ventanas. El equivalente real sería AT-SPI
  (accessibility bus) — SIN CONFIRMAR, queda como trabajo futuro si hace falta precisión por-control.
- **`read-text`/`read-uia` NO se portaron.** Windows los resuelve vía Win32 controls / UI Automation;
  Linux no tiene un mecanismo genérico equivalente sin AT-SPI (no garantizado instalado). En vez de
  fingir una implementación endeble, quedan explícitamente FUERA — usa el screenshot.

## macOS — COMPLETO, verificado LOCAL (pendiente sesión SSH genuina)
13 scripts en [`mac/`](mac/), patrón `mac-ssh-{acción}.sh`, gemelos estructurales de `win-ssh-*`.
Comparten `mac/lib-mac-ssh-env.sh` (`mac_console_user`/`mac_dispatch`). **Verificado LOCAL el
2026-09-18** en esta Mac (macOS 26.6.2) — ejecutando los scripts de verdad, no solo revisando
sintaxis.

| Script | Qué hace | Verificado |
|---|---|---|
| `mac-ssh-screenshot.sh` | Captura la pantalla (`screencapture -x`). Default = TODAS las pantallas, 1 archivo c/u (paridad adaptada con el VirtualScreen de Windows — ver gotcha multi-monitor). `-Display N` para UNA pantalla por número. `-Window "título"` para una ventana. `-B64`. | ✅ 3 pantallas REALES (Retina 2992×1934 + 2 externas 3440×1440 c/u), 3 PNG distintos con contenido genuinamente distinto; ✅ `-Display 2` dio la externa correcta |
| `mac-ssh-clipboard.sh` | `-Get`/`-Set "texto"` vía `pbcopy`/`pbpaste` — SIN permiso TCC de por medio. | ✅ round-trip set→get confirmado |
| `mac-ssh-list-windows.sh` | Enumera procesos+ventanas (nombre, rect) vía `System Events`. `-Filter`, `-Csv`. | ✅ enumeró procesos reales; ventanas probado contra proceso sin ventana abierta (lista vacía correcta) |
| `mac-ssh-get-processes-list.sh` | Lista procesos (top-N por RSS). NO necesita sesión de consola. `-Name`, `-Csv`. | ✅ listó procesos reales (fix real: ver gotcha `basename`/comm-con-espacios) |
| `mac-ssh-kill-process.sh` | Mata por `-Name`/`-Id` (`-WhatIf` primero). NO necesita sesión de consola. | ✅ `-WhatIf` confirmado contra proceso real |
| `mac-ssh-launch.sh` | Lanza una app (`open -a "<App>"` o `-Path` a `.app`/URL/archivo). `-Args`. | Construido sobre el mismo `mac_dispatch` ya verificado (screenshot/clipboard) |
| `mac-ssh-send-click.sh` | Click izq/der por coordenada `-X -Y` vía `cliclick` (`-Button right`, `-Double`, `-Window`). | Primitivo `cliclick` confirmado sin error; sin click en vivo sobre UI real (ver nota) |
| `mac-ssh-send-double-click.sh` | Atajo de send-click `-Double`. | Mismo mecanismo que send-click |
| `mac-ssh-send-keys.sh` | Teclea `-Keys "texto{ENTER}"` (mini-lenguaje + `#`=Cmd, adaptación Mac) — texto literal vía `cliclick t:` (fix 2026-09-18: `System Events keystroke` DESCARTA espacios, ver gotcha), teclas especiales/combos vía `key code`/`keystroke using`. | ✅ QA en vivo del usuario: funciona, espacios incluidos |
| `mac-ssh-get-window-coordinates.sh` | Rectángulo + CENTRO de cada CONTROL de una ventana (mejor paridad que Linux: Accessibility API expone UI elements). | Mecanismo estándar de Apple; no probado contra ventana con controles variados en esta pasada |
| `mac-ssh-move-window.sh` | Mueve/redimensiona la ventana de una app `-X -Y [-W -H]` vía `System Events`. | Construido sobre el mismo primitivo que get-window-coordinates |
| `mac-ssh-maximize-window.sh` | Maximiza (aproximado a bounds de pantalla)/restaura/minimiza (`-State`) por app. | Construido |
| `mac-ssh-close-window.sh` | Cierre GRACIOSO: activa la app + Cmd+W vía `keystroke`. | Construido sobre el primitivo `keystroke` ya confirmado |

### Precondición TCC (real, no evitable — verifícalo así, no lo escondas)
`screencapture` exige el permiso **"Grabación de pantalla"**, y `cliclick`/`System Events` exigen
**"Accesibilidad"**, concedidos UNA VEZ al proceso que los invoca (Terminal/sshd/lo que despache el
comando) vía System Settings → Privacidad y seguridad. No hay `tccutil` que lo pre-autorice para un
proceso lanzado por SSH — mismo patrón que la excepción de Red Local de macOS 26 ya documentada en
la memoria de máquina. **En esta Mac ambos permisos YA estaban concedidos** al proceso que corrió las
pruebas (por eso todo lo de arriba salió ✅ real) — el gap real de esta pasada es que **no se pudo
confirmar el caso de una sesión SSH genuina contra un proceso SIN el permiso ya concedido**: hacerlo
exigía agregar una llave a `~/.ssh/authorized_keys` de esta misma Mac para loopback SSH, y el guard de
permisos de Claude Code bloqueó esa acción por tocar autorización SSH (correctamente — es un cambio
de seguridad). Queda como la única precondición pendiente de verificar en una sesión SSH real.

### Otros gotchas verificados
- **El verbo AppleScript `System Events click at {x,y}` NO es confiable** — falló con error -25200 en
  esta máquina/versión de macOS (documentado en foros como inconsistente entre versiones). Por eso
  este kit usa **cliclick** (`brew install cliclick`) como ÚNICA vía de click, no como fallback —
  además de ser poco fiable, ese patrón AppleScript específico está asociado a automatización de
  clics en diálogos de permisos usada por malware Mac, así que tampoco se incluyó como código
  ejecutable de respaldo.
- **`basename` interpreta un `comm` que empieza con `-` como flag propio** (`illegal option`) — el
  `comm` de macOS suele ser la ruta completa al ejecutable y puede traer espacios (`Application
  Support`); `mac-ssh-get-processes-list.sh` reordena PID/RSS/CPU primero (numéricos, sin espacios) y
  usa `${var##*/}` en vez de `basename` para evitar ambos problemas a la vez.
- **`pgrep -f` auto-matchea su propio invocador** — mismo gotcha ya documentado para Linux;
  `mac-ssh-kill-process.sh` usa `pgrep` SIN `-f`.
- **DPI-awareness: NO hace falta.** macOS trabaja en puntos (independiente de la densidad Retina)
  para `cliclick`/`System Events`/`screencapture` — confirmado con el screenshot real (2992×1934
  nativo, sin truncar).
- **`launchctl asuser`** (el mecanismo previsto para despachar a la sesión de consola cuando quien
  invoca NO es esa sesión) queda implementado en `mac_dispatch()` pero **SIN CONFIRMAR en un SSH
  genuino** en esta pasada — ver precondición TCC arriba para el porqué. La primera vez que uses el
  kit contra una sesión SSH real, verifícalo y actualiza esta nota con fecha+resultado.
- **`System Events keystroke "texto con espacios"` DESCARTA los espacios** (hallado por QA en vivo
  del usuario 2026-09-18, macOS 26.6.2: `"a b c"` salía `"abc"`) — aislado, pasa igual por
  `mac_dispatch`/`launchctl asuser` directo, así que es el verbo `keystroke`, no el despacho.
  `mac-ssh-send-keys.sh` usa `cliclick t:` para texto literal (sí teclea espacios); `keystroke`
  queda solo para teclas especiales/combos (`key code`, `keystroke ... using {modificador down}`).
- **Multi-monitor (QA 2026-09-18, ver cabecera de `mac-ssh-screenshot.sh`):** a diferencia de
  Linux, `screencapture -x archivo.png` SIN flags captura SOLO la pantalla PRINCIPAL — confirmado
  en esta Mac (3 pantallas reales: Retina integrada + 2 externas) que el default daba exactamente
  lo mismo que `-D 1`. macOS no tiene forma nativa de coser 2+ monitores en una sola imagen — el
  default de `mac-ssh-screenshot.sh` ahora captura TODAS las pantallas, una imagen POR pantalla
  (`-1.png`, `-2.png`...), confirmado con las 3 pantallas reales de esta Mac (resoluciones y
  contenido distintos en cada archivo, no duplicados).

### Paridad parcial documentada (no oculta)
- **`read-text`/`read-uia` NO se portaron** (ni en Linux ni en Mac) — en Mac SÍ sería técnicamente
  viable vía Accessibility API (`value`/`title` de los UI elements, el mismo mecanismo que
  `get-window-coordinates` ya usa para posición/tamaño), pero no se construyó en esta pasada para
  mantener el mismo corte de alcance que Linux. Candidato de trabajo futuro, no un hueco escondido.
