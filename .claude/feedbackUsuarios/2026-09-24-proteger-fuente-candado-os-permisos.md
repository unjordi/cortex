# Feedback: `proteger-fuente-cerebro` es advisory/evadible → evaluar candado DURO de permisos de OS

**Fecha:** 2026-09-24 · **De dónde salió:** sesión `claudio-master` (plantilladotnet), conversación con unjordi.
**A quién le toca:** cortex-master (hook `proteger-fuente-cerebro` + `install-brain`).

## Motivo
Hoy `proteger-fuente-cerebro` solo **AVISA** (advisory). Una sesión de Claude puede ignorarlo o evadirlo, y editar la FUENTE intocable del brain global. No hay candado duro que lo impida — solo la disciplina del guard.

## Propuesta (idea de unjordi, sólida)
Respaldar el hook con un candado a nivel de **OS**, más fuerte que cualquier guard:
- Usuario dedicado **`claude`** dueño de los archivos **intocables** del brain (`chown claude`, sin write para otros).
- `install-brain` corre **opcionalmente con `sudo -u claude`** — es quien tiene la llave de escritura.
- Como claude-cli corre con el usuario normal (unjordi), **sin el bit de write no toca esos archivos ni queriendo ni sin querer**. Y desde el Bash tool Claude **no tiene `sudo` ni tty** → un Claude renegado **tampoco puede escalar** a `claude`. Queda encerrado en los permisos del usuario. El hook se puede ignorar; esto no.

## Diseño / gotchas a resolver (no bloqueantes)
- **Trazar la línea intocable-vs-vivo:** intocables (hooks, skills del brain, `brain/`, normas de `CLAUDE.md`) → de `claude`, read-only. Lo que el harness SÍ escribe como el usuario (`settings.json`, `projects/`, sesiones, cache, memoria de trabajo) → **se queda del usuario** o se rompe Claude Code.
- **Dirs también:** borrar/crear un archivo necesita write en el *directorio*, no en el archivo → los dirs intocables van a `claude` (subdir de `claude` dentro del `$HOME` del usuario, factible).
- **Multi-OS, por eso "opcional":** Linux trivial (`useradd`); macOS más pesado (usuario oculto vía `dscl`, o `chflags uchg` como alternativa sin usuario aparte); Windows es otro modelo (ACLs). Opcional per-OS.
- **El updater oficial** (widget ⬆) tendría que escalar a `claude` para escribir.
- **Fuera de alcance a propósito:** el humano sudoer puede sobreescribir deliberadamente con `sudo` — la protección frena la escritura NO privilegiada (el Claude), no al humano.

## Encuadre
No reemplaza al hook: es la **defensa DURA que lo respalda** (defensa en profundidad). El hook sigue como aviso temprano; los permisos son el muro.
