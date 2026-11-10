# Revisión de 9e453fa (macOS) y 2dabf08 (KDE/GNOME) — claudio-master

Corrido por mí: swift build verde en fix/corpus-fp-bench; wrapper GNOME con terminales falsas; comando KDE por sh -c hasta un konsole falso; PATH de login en la cachy (claude y konsole presentes). Lógica OK en los 4 estados.

- BAJO · src/gnome-extension/tabs/limites.js reloginRun: si no hay ninguna de kgx/gnome-terminal/konsole/xterm, el wrapper sale 1 y D.spawn (fire-and-forget) no avisa → el botón no hace nada sin explicación. Reproductor: `env -i PATH=/bin bash --noprofile --norc -c "<wrapper>"; echo $?` → 1, sin salida.
- MENOR · macos/Sources/Cortex/QuotaModel.swift: isSnapshotStale y hasQuotaData quedan sin uso; no hay marca visual de "lectura preservada" (el pie con la edad cubre la decisión de unjordi). Decide si se usan o se quitan.

## d4ccfd1 (revisado por claudio 10:45)
- GNOME: wrapper corrido con terminales falsas: sin terminal → notify-send con el comando; con kgx → exec, sin notificación; sin terminal ni notify-send → calla (rc 0, aceptable). swift build verde. OK.
- MENOR (los 3 footers): `account = account_email ?? (basis == "oauth" ? "datos reales" : "estimado local")`. Con basis "cost" retirado, basis null = "no hay dato", y el pie diría "estimado local" sin que exista estimado. Debería decir algo como "sin dato".

## d4df43d — H18 (revisado por claudio 10:59, corrido en repos desechables con origin bare)
- VIEJO (c2d5664), parado en develop con --branch feat/x que trae una llave AWS: "gitleaks limpio … ..HEAD", rc 0 → el bug confirmado.
- NUEVO: feat/x → "leaks found: 1 … ..origin/feat/x", rc 1 (frena) · feat/limpia → limpio, rc 0 (deja pasar) · sin --branch y gh sin respuesta parado en develop → rehúsa con mensaje claro, rc 1 · --repo de otro repo → avisa y no declara limpio, rc 0 (CI de respaldo). OK en las dos direcciones.
- BAJO: el match de --repo contra la URL de origin es por subcadena (`*"$REPO"*`): `--repo unjordi/PowerScripts` también casa con `…/unjordi/PowerScripts-viejo.git`, y no ignora mayúsculas (GitHub sí) → con `--repo Unjordi/powerscripts` saltaría el gate local. Anclar al final (`*[/:]$REPO`) y comparar en minúsculas.
