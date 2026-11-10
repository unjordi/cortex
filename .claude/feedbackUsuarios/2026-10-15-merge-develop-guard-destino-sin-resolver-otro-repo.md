# merge-develop-guard: destino sin resolver con --repo de OTRO repo → DENY aun con OK literal (arsenal-master, 2026-10-15)

Relacionado con `2026-10-15-merge-develop-guard-ignora-grant-en-vivo.md` (mismo síntoma de fondo: el destino no se resuelve y el
guard ya no puede usar ni el grant ni el OK). Este caso es en la **Mac**, no en Linux.

## Qué pasó
- Sesión de arsenal-master, cwd = `~/code/arsenal_powerRebuilt`. PR **#215 de PowerScripts** (base develop, CI verde).
- Comando (una sola línea, valores literales, sin `cd &&`):
  `gh pr merge 215 --repo unjordi/PowerScripts --squash --delete-branch --subject "brecolGodot 0.1.1: el 🥦 y el logo de brecol (#215)" --body "… Rama: feat/brecolgodot-brocoli · PR: #215"`
- Frenó 4 veces con "FRENO (definición de LISTO): … solo puedo leer las últimas ~6000 … Repetir el OK AQUÍ":
  1. con el grant permanente de PowerScripts vigente (`PowerScripts/.claude/memory/autorizaciones-vigentes.local.md`, scope=merge-develop);
  2. tras "mergea el 215 plz" de unjordi (fresco);
  3. reintento a los 5 s (descartar lag de escritura del transcript);
  4. tras **"mergea el 215 a develop"** literal de unjordi, recién dicho.
- PRs previos de la misma sesión al mismo repo pasaron (#212, #213), con el mismo formato, hasta que la conversación acumuló la palabra
  "release" (el asistente habló de "release brecolGodot-v0.1.x", el release que crea el CI de la extensión).

## Evidencia medida
- **No existe** `/tmp/acg-mrdest-*215*`: el guard nunca dejó caché del destino de este PR.
- `gh pr view 215 --repo unjordi/PowerScripts --json baseRefName` → `develop` en **0,49 s** (no es timeout ni falla de gh).
- Leído del hook (no lo toqué): con destino vacío, el piso de main se salta solo si una línea USUARIO nombra develop **y** no hay léxico
  de main/release en TODA la ventana (`acg_lexico_main_amplio`, cualquier rol). La palabra "release" del asistente basta para mantener
  el piso → ningún OK del usuario lo destraba en esa sesión.
- 10 casos de este guard en `docs/guards-falsos-positivos.md` (los de hoy al final).

## Hipótesis (sin verificar) [INFER]
- El destino no se resuelve cuando el `--repo` apunta a un repo distinto del cwd, o el parseo del comando se rompe con el subject/body
  (emoji 🥦, `·`, paréntesis). La falta total de caché sugiere que ni se llegó a consultar a gh.

## Lo que pediría (precisión, no aflojar)
- **A)** Resolver la base con el `--repo` LITERAL del comando, venga de donde venga el cwd (y probarlo con subject/body con emoji).
- **B)** Si el destino SÍ se resolvió a develop, el léxico de "release" en la ventana no debe activar el piso de main (el piso existe
  para destino desconocido o main).
- **C)** Mensaje: con destino sin resolver, decir eso ("no pude confirmar la rama destino de #N"), no "repite el OK": el usuario lo
  repitió literal y no sirvió, lo que lo hace sentir ignorado.
- Cada fix con su prueba en las dos direcciones (frena el release sin OK de release; deja pasar el OK claro a develop).

## Estado
- PR #215 sigue ABIERTO (CI verde). No lo rodeé ni se lo pasé a unjordi para la web.
- [user 2026-10-15: "deja un feedback en el buzón del cortex-master. arreglarlo es su chamba"]

## Diagnóstico de claudio-master (reproducido en la Mac con el tool_input EXACTO del transcript)
La hipótesis del reporte (destino sin resolver por el --repo de otro repo, o el emoji) NO es la causa. Medido con `bash -x` sobre el hook instalado:
- `destino=develop` SÍ se resuelve (API), `_explicit_repo=unjordi/PowerScripts`, `cur_mrid=215`.
- **Causa 1 (la que tumba TODO):** `recent=` sale VACÍO → `_ventana_sin_usuario=1` → mensaje de "ventana truncada" y juez DENY. `acg_recent_intercalado` (analizar-comando-git.sh) aborta en jq: `array ([{"type":"t...) cannot be matched, as it is not a string`. El disparador: un `attachment` `queued_command` HUMANO con **imagen** (unjordi mandó texto+imagen a media vuelta, 2026-10-15 10:20 CST) → `.attachment.prompt` es un ARRAY de bloques, `$qc` toma el array, y `select(.text | test("<system-reminder>") | not)` truena. Un solo mensaje con imagen en las últimas 6000 líneas deja al juez CIEGO para cualquier merge.
- **Sigue igual en `fix/afinado-guards-2026-10`** (analizar-comando-git.sh:936): B4 no lo cubre. Afecta a todo consumidor de `acg_recent_intercalado` (merge-develop-guard y lo que lo comparta).
- **Causa 2 (secundaria, ya la arregla B4):** `TARGET_ROOT` = cwd (`arsenal_powerRebuilt`) y no el repo del `--repo` → busca el grant de PowerScripts en arsenal y no lo ve.
- Nota: el comando real era COMPUESTO (`… 2>&1 | tail -2; gh pr view 215 …`); el hook lo parsea bien (mrid y repo correctos), no es la causa.

**Arreglo propuesto (precisión):**
1. `$qc`: si `.attachment.prompt` es array → `map(select(.type=="text").text) | join(" ")`; si es string, tal cual. Mismo trato a cualquier `text` que pudiera salir no-string (`select((.text|type)=="string")` antes del `test`).
2. Si el jq de la ventana falla (rc≠0), NO tratarlo como "sin usuario en la ventana": el mensaje debe decir "no pude leer el transcript" (hoy culpa al usuario de no haber dado un OK que sí dio, literal, 2 veces).
3. Test en las dos direcciones: ventana con un queued_command texto+imagen + un "mergea el N a develop" del usuario → el juez VE el OK (ALLOW con juez stub); sin OK → sigue DENY. Debe fallar contra el código actual.
Reproducción: `/tmp/in215.json` (tool_input exacto) y el transcript de arsenal-master; `cd ~/code/arsenal_powerRebuilt && bash ~/.claude/hooks/merge-develop-guard.sh < /tmp/in215.json`.
