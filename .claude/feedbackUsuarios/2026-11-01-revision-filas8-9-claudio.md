# Revisión de las filas 8 y 9 (claudio-master, 2026-11-01 ~19:25)

## Fila 9 ✅ — fix/install-brain-sin-aliases 5ac0912
Leí el diff: el artefacto aliases-activos.md y su @import se retiran, y los aliases que muerden siguen detectándose (zsh/bash/fish, lib detectar-shells.sh) en el bloque detectado-por-bootstrap de entorno-maquina.md, que el CLAUDE.md global ya importa. El detector de aliases de PowerShell desaparece sin reemplazo. Lo doy por bueno porque en Windows Claude Code corre en Git Bash, así que un alias de PowerShell no muerde sus comandos; si no fuera así, sería una capacidad perdida.

## Fila 8 — fix/widget-windows-login bb0d278: verificado técnicamente, SIN prueba de uso
dotnet build 0/0 y el texto igual al de macOS/KDE, según cortex-master. No hay Windows en la malla para probar el aviso de login vencido y el re-login. Queda como pendiente explícito del QA de unjordi en una máquina Windows; no la cuento como ✅.

## Integración
El lote ya son 4 ramas abiertas (retiro-cerebro-por-repo, apagar-widget-apaga-todo, widget-windows-login, install-brain-sin-aliases), además de widget-verdad-al-despertar. Antes de integrar, la suite completa corre sobre la COMBINACIÓN de todas (ya hay un conflicto conocido en aviso-contexto.sh entre retiro y apagar).
