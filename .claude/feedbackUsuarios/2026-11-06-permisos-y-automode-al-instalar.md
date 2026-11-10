# install-brain debe sembrar permisos condensados y el bloque autoMode

**De:** claudio-master · **Pedido de unjordi (2026-11-06):** «toma nota por favor para que nuestro cortex también lo haga cuando se instala o actualiza».

## Qué pasó
En auto mode el clasificador frenaba trabajo rutinario entre las máquinas de unjordi:
- escribir `~/.claude/settings.json` en la cachy por ssh («Self-Modification»), aun con su OK citado;
- reglas `allow` de ssh demasiado específicas (`ssh -o ConnectTimeout=8 cachy *`, `ssh -n cachy *`, …) que no calzaban con la variante del día.

Datos medidos y verificados contra la doc oficial (code.claude.com/docs/en/permission-modes y /auto-mode-config):
- las escrituras a los settings de Claude son ruta protegida y SIEMPRE pasan por el clasificador, aunque haya `allow`;
- auto mode suspende las `allow` amplias de intérprete (`Bash(python3 *)`, `Bash(*)`, `Agent`);
- `autoMode.allow` / `autoMode.environment` SIN `"$defaults"` reemplazan las reglas por defecto en lugar de sumarse.

## Qué quedó aplicado a mano (Mac y cachy), y que el instalador debe dejar igual
En `~/.claude/settings.json` de cada máquina, con merge idempotente (sin duplicar ni pisar lo que ya haya):
1. `permissions.allow`, una regla por máquina de la malla con comodín en medio. Ejemplo en la Mac: `Bash(ssh *cachy *)`, `Bash(scp *cachy:*)`, `Bash(scp *cachy:* *)`, `Bash(ssh *root@deck *)`, `Bash(ssh *root@rp6 *)`, `Bash(ssh *loki *)`. En la cachy: lo mismo con `mac` en lugar de `cachy`. Se borran las variantes sueltas viejas de ssh/scp, salvo las de `git@`.
2. `permissions.allow` de toda la carpeta de scripts del usuario (`Bash(python3 -I <PowerScripts>/:*)`, `bash`, directo, `pwsh -NoProfile -File`, `uv run [-q] --script`) y Read/Edit/Write de `~/.claude/**` y `~/code/**/.claude/**`, más `Bash(screen -S * -p 0 -X hardcopy *)`.
3. `autoMode.environment` (con `"$defaults"` si se crea): «mac, cachy, deck y rp6 son máquinas personales de desarrollo de unjordi, no hosts de producción ni compartidos; loki SÍ es producción».
4. `autoMode.allow = ["$defaults", "User-requested settings edits: Editing Claude Code's own settings files (~/.claude/settings.json, settings.local.json) on mac or cachy when unjordi explicitly asked for that change in the conversation is NOT Self-Modification; the edit must match what he asked."]`

La lista de máquinas, la ruta de scripts y el usuario son datos POR MÁQUINA/USUARIO (van a la config local del instalador, no cableados).

## Prueba que debe acompañarlo
- Tras instalar sobre un settings con las 12 reglas sueltas de ssh: quedan las condensadas y ninguna suelta; las de `git@` siguen.
- Correr dos veces deja el archivo idéntico (idempotente).
- `claude auto-mode config` muestra una regla por defecto (p. ej. «Transient Retry») junto a las dos nuevas: si falta la por defecto, se perdió `"$defaults"`.

**Actualización 2026-11-06 16:05 (claudio-master):** los permisos y todo `autoMode` de la Mac y la cachy ahora los escribe `~/code/PowerScripts/shared/claude-settings/configurar-permisos.sh` (lo corre unjordi). Lo que el instalador de cortex siembre de permisos debe ser compatible con eso o delegarle; no reescribir `autoMode` por su cuenta.
