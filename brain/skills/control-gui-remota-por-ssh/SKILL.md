---
name: control-gui-remota-por-ssh
description: Ver y operar la GUI de escritorio de una máquina remota usando SOLO una sesión SSH (sin VNC/RDP disponible) — screenshot, clicks, teclado, inspección de ventanas/controles, portapapeles, lanzar/cerrar apps y procesos, todo scriptable y con evidencia (screenshot antes/después). Resuelve los DOS problemas duros que lo hacen no-trivial: (1) el AISLAMIENTO DE SESIÓN — una sesión SSH corre en otra logon-session y no ve el escritorio interactivo del usuario logueado — y (2) el DPI-AWARENESS — sin fijarlo, el screenshot sale truncado y los clicks se desvían. Windows: COMPLETO, 15 scripts `win-ssh-*.ps1` verificados en hardware real. Linux y macOS: solo el ANDAMIO del enfoque (xdotool/ydotool, cliclick/osascript) — SIN CONFIRMAR en máquina real, a construir. Úsalo cuando necesites ver/manejar una GUI de escritorio remota y NO tengas VNC/RDP/un navegador con visor web disponible — solo SSH; o como paso previo a `ingenieria-inversa-gui-db-navegador` (que asume navegador) cuando el objetivo es escritorio nativo, no web.
---

# Control de GUI remota por SSH

> El kit `win-ssh-*` está verificado en hardware real (2026-08-27) manejando una estación Windows
> sin noVNC disponible, solo por SSH. Es una capacidad GENÉRICA del cerebro — cualquier sesión/máquina
> del equipo la tiene, sin depender de qué repo o proyecto la necesitó primero.

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

## Linux y macOS — [POR CONSTRUIR · SIN CONFIRMAR]
**Ningún script de este par de plataformas existe todavía ni fue probado en hardware real.** Lo que
sigue es el ENFOQUE — gemelos ESTRUCTURALES de los `win-ssh-*` (misma firma de parámetros, mismo
orden de pasos, mismos nombres de acción, misma forma de salida) que alguien debe CONSTRUIR y
VERIFICAR en una máquina real antes de confiar en ellos. No los uses como si funcionaran; sigue
usando VNC/RDP/un navegador (`ingenieria-inversa-gui-db-navegador`) en Linux/Mac hasta que este kit
exista de verdad. Máquinas candidatas para verificar cuando se construya: la Mac de escritorio, y
la malla Linux (mamalona/deck/rp6).

### macOS — enfoque previsto
- **Captura de pantalla:** `screencapture` (nativo, sin dependencias) — ya opera sobre CUALQUIER
  sesión gráfica del Mac remoto si el proceso corre con los permisos correctos; no hay aislamiento
  de logon-session como en Windows (macOS es single-seat), pero SÍ hay una barrera de **permisos de
  Accesibilidad y Grabación de pantalla** por-app que hay que conceder una vez vía GUI (no hay
  `tccutil` que lo automatice para procesos por SSH, igual que con la excepción de Red Local de
  macOS 26 ya documentada en la memoria de máquina).
- **Click/teclado:** `cliclick` (CLI dedicado, brew) o `osascript` con `System Events` — ambos
  requieren esos mismos permisos de Accesibilidad concedidos a la app que los invoca (Terminal,
  sshd, o lo que despache el comando).
- **El equivalente al aislamiento de sesión:** una sesión SSH en macOS corre "headless" respecto al
  Aqua/WindowServer del usuario logueado salvo que se despache explícitamente a ESA sesión gráfica.
  El mecanismo previsto: `launchctl asuser <uid> <comando>` (o `sudo -u <usuario> launchctl asuser
  ...`) para correr el comando DENTRO del contexto de sesión gráfica del usuario con sesión activa —
  el análogo funcional del `schtasks /IT` de Windows. SIN CONFIRMAR: falta verificar en hardware real
  si esto basta o si además exige un bootstrap de sesión distinto (p. ej. vía `launchd` de usuario).
- **DPI-awareness:** macOS ya trabaja en "puntos" (coordenadas independientes de la densidad Retina)
  para `cliclick`/`osascript`/`screencapture` — probablemente NO hace falta un equivalente al
  `SetProcessDPIAware()` de Windows, pero **esto es una suposición sin verificar**, no un hecho
  confirmado como en Windows.
- **Nombres de script previstos** (mismo patrón, prefijo `mac-ssh-`): `mac-ssh-screenshot.sh`,
  `mac-ssh-send-click.sh`, `mac-ssh-send-keys.sh`, `mac-ssh-list-windows.sh` (vía `osascript`
  consultando `System Events` o la API de Accesibilidad), `mac-ssh-launch.sh` (`open -a`),
  `mac-ssh-close-window.sh`, `mac-ssh-get-processes-list.sh`/`mac-ssh-kill-process.sh` (`ps`/`kill`,
  no necesitan sesión gráfica, igual que sus gemelos Windows).

### Linux — enfoque previsto (dos familias según el compositor)
- **X11:** `xdotool` (click/teclado/mover-ventana/listar-ventanas) + `import` (ImageMagick) o `maim`
  (captura) — el kit más maduro y directo, análogo más cercano al de Windows. Requiere que el
  proceso SSH tenga `$DISPLAY` y `$XAUTHORITY` apuntando a la sesión gráfica del usuario logueado
  (normalmente `DISPLAY=:0` + el `.Xauthority` de ESE usuario) — el equivalente al `schtasks /IT`:
  sin esas dos variables correctas, `xdotool`/`import` no ven ni tocan esa sesión. SIN CONFIRMAR:
  cómo descubrir/exportar esas variables de forma robusta desde una sesión SSH separada (candidato:
  leerlas del entorno de un proceso ya corriendo en esa sesión gráfica, vía `/proc/<pid>/environ`
  del gestor de sesión o similar).
- **Wayland:** `ydotool` (click/teclado — necesita el daemon `ydotoold` corriendo y permisos sobre
  `/dev/uinput`) + `grim` (captura, solo compositores wlroots: Sway y similares; GNOME/KDE Wayland
  necesitan su propio mecanismo de captura vía portal). Bastante más fragmentado que X11 — cada
  compositor puede exigir su propio enfoque de captura/input. SIN CONFIRMAR en ningún compositor real
  todavía.
- **DPI-awareness:** Linux/X11 con escalado fraccional puede tener el mismo problema que Windows
  (coordenadas lógicas vs físicas descuadradas) — a verificar por compositor/escala real; no asumir
  que "no aplica" solo porque X11 es más simple que Windows en otros aspectos.
- **Nombres de script previstos** (prefijo `linux-ssh-`, con sufijo de compositor donde el enfoque
  diverge): `linux-ssh-screenshot.sh`, `linux-ssh-send-click.sh`, `linux-ssh-send-keys.sh`,
  `linux-ssh-list-windows.sh` (`xdotool search`), `linux-ssh-launch.sh`, `linux-ssh-close-window.sh`,
  `linux-ssh-get-processes-list.sh`/`linux-ssh-kill-process.sh` (`ps`/`kill`, sin sesión gráfica).

### Qué falta para que Linux/Mac dejen de ser andamio
1. Escribir cada script sobre una máquina real de la malla (no simulado), con la MISMA firma de
   parámetros que su gemelo `win-ssh-*` (mismos nombres de flag donde el concepto exista: `-X -Y`,
   `-Window`, `-Csv`, etc.) para que quien ya conoce el kit de Windows no tenga que re-aprender nada.
   Alguna incompatibilidad estructural (p. ej. `-B64`, `-User`, `-WorkDir`) puede no tener sentido
   1:1 — ajusta el parámetro, no lo fuerces, pero documenta el porqué del cambio en el propio script.
2. Verificar en vivo el equivalente al `schtasks /IT` (`launchctl asuser` en Mac; `$DISPLAY`/
   `$XAUTHORITY` en X11; el daemon de `ydotoold` en Wayland) — sin esto CONFIRMADO, un script que "se
   ejecuta sin error" puede estar tocando la nada (ninguna sesión gráfica real), como pasaría en
   Windows sin `/IT`.
3. Verificar DPI-awareness/escalado en al menos un caso real por plataforma.
4. Una vez verificados, mover este bloque a una tabla COMPLETA como la de Windows arriba, con fecha y
   máquina de verificación — el mismo estándar que ya cumple el kit de Windows.
