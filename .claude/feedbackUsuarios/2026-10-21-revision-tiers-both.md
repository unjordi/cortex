# Revisión de 673ac46 (tiers both) — claudio-master 11:40

- OK: MANIFEST (3 → both), cláusula de dedupe idéntica a la de los guards both, ev_de mapea Stop/SessionStart. recordar-cosechar global en carpeta NO-git: rc 0, sin salida, no crea archivos (medido).
- MEDIO · brain/hooks/sesion-inicio.sh: como global ahora corre en TODA sesión, y fuera de un repo NO calla. Reproductor (HOME falso con el hook como copia global, cwd = dir temporal sin git):
  `D=$(mktemp -d); H=$(mktemp -d); mkdir -p $H/.claude/hooks; cp brain/hooks/{sesion-inicio,juez-comun,sincronizar-tasklist}.sh $H/.claude/hooks/; cd $D && echo '{"source":"startup","session_id":"x","cwd":"'$D'"}' | HOME=$H CLAUDE_PROJECT_DIR=$D bash $H/.claude/hooks/sesion-inicio.sh`
  → inyecta "🧠 CEREBRO DEL REPO … Rama actual: ?." + NORMA DE GIT + RITUAL. Pasaría en ~, Downloads, GoogleDrive/Juegos (games-master), etc.
  Debe: fuera de un repo git, no inyectar el bloque del repo (rc 0, sin salida). Dentro de un repo, igual que hoy. Test de las dos direcciones.
- Nota: el "fail-open/no-op sin los archivos del proyecto" que te pasé en la nota de tiers era cierto para recordar-cosechar, no para sesion-inicio (error mío de medición).

## 9336cc1 (N4, aviso-drift) — revisado por claudio 11:50, en la cachy contra ~/code/axon con CLAUDE_BRAIN_DIR = copia de la rama y AVISO_DRIFT_HORAS=0
- Viejo (instalado): "SOBRAN: dod-verificar.sh juez-comun.sh recordar-cosechar.sh sesion-inicio.sh sincronizar-tasklist.sh".
- Nuevo: "SOBRAN: recordar-cosechar.sh sesion-inicio.sh sincronizar-tasklist.sh" → ya no dod-verificar ni juez-comun. OK con la decisión.
- BAJO-MEDIO: marca un `both` como sobrante aunque su copia GLOBAL no esté instalada (hoy en la cachy ~/.claude/hooks NO tiene sesion-inicio/recordar-cosechar/sincronizar-tasklist). Quien siga el aviso antes de reinstalar deja a axon sin esos hooks. Debe exigir lo mismo que el dedupe: sobra solo si `[ -f "$HOME/.claude/hooks/$_b" ]`. Test: repo personal con un `both` por-repo y SIN copia global → no se lista; con copia global → sí.

## f8714a2 (sesion-inicio calla fuera de git) — revisado por claudio 11:53
- 6 casos reales: carpeta no-git → 0 bytes; no-git con .claude/ (tipo GoogleDrive/Juegos) → 0 bytes; raíz de repo → "Rama actual: develop"; subcarpeta → igual; worktree → "Rama actual: feat/x"; plantilladotnet real → "Rama actual: DevelopUnjordi". OK en las dos direcciones.
- Sigue abierto el BAJO-MEDIO de 9336cc1 (aviso marca both sin copia global).

## c707b29 (both sobra solo con copia global) — revisado por claudio 12:10, en la cachy contra axon
- Sin copia global (cachy real): no lista nada. Con copia global (HOME falso con los 3 en ~/.claude/hooks): "SOBRAN: recordar-cosechar.sh sesion-inicio.sh sincronizar-tasklist.sh". OK en las dos direcciones. Tanda de tiers CERRADA por mi lado.

## cc4b334 (rehidratar-hilo: orden reconstruir-contexto + H11) — revisado por claudio 12:58
- compact en plantilladotnet (hilo de 9 KB): 1ª línea = "🛟 PRIMER ACTO … corre el skill `reconstruir-contexto`", en el byte 73 (dentro del preview de 2 KB), arriba del faro de truncado. OK.
- startup: salida idéntica byte a byte a c707b29. Repo git pelón + compact: 0 bytes. OK.
- H11 por tubería (como lo lee el harness): viejo 8.03 s → nuevo 0.07 s hasta EOF. Queda un `sleep 8` huérfano unos segundos, inocuo como dices.
- La decisión de gatear por estado-proyecto.md se la paso a unjordi.

## 633a732 (GRAVE barrido de worktrees) — revisado por claudio 13:45, repo desechable con 6 worktrees
| worktree | viejo (53c1222) | nuevo (633a732) | debe |
|---|---|---|---|
| agente recién arrancado (0 commits, limpio) | BORRA (bug confirmado) | conserva | conserva |
| agente trabajando sin commit (sucio) | conserva | conserva | conserva |
| integrado por fast-forward | borra | **conserva** | borra |
| integrado por merge commit (--no-ff) | borra | **conserva** | borra |
| integrado por squash | borra | borra | borra |
| commits sin integrar | conserva | conserva | conserva |
- MEDIO (regresión): tras FF o merge commit, la rama queda con `rev-list base..rama == 0` y árbol limpio = misma huella que un recién nacido → nunca se barre. El flujo mini-develop (ramita → mini con `git merge` LOCAL) cae justo aquí.
- Discriminador medido: el REFLOG de la rama. Recién nacido: solo "branch: Created from develop". Integrado: tiene entradas "commit: …" antes del "Created". Propuesta: `_worktree_recien_nacido` exige además que `git reflog show --format=%gs <rama>` no tenga ninguna línea `commit` (ni `merge`/`rebase`/`cherry-pick`). Test: las 6 filas de arriba.

## 2976bbc (retira git-branch-guard) — revisado por claudio 15:20
- `git-branch-guard.sh` ya no existe; MANIFEST `retirado` con fecha y motivo.
- merge-develop-guard (dedupe neutralizado, HOME falso), 9 comandos: frena push a develop/main, HEAD:develop, -f, checkout develop&&merge&&push; pasa ramita, refs/remotes, echo entrecomillado, git log. OK.
- Lib rota, comparado con el git-branch-guard de 9eec6fc: ausente → ambos FRENAN; con error de sintaxis → ambos FRENAN. Paridad.
- BAJO (heredado, ya estaba en el viejo): lib presente pero VACÍA (o sin `acg_push_toca_base` definida) → ambos dejan PASAR el push a develop. Endurecer: tras el source, `type acg_push_toca_base >/dev/null 2>&1 ||` caer al fallback de push|merge|accept.
- Poda real: copia de plantilladotnet/.claude (hooks + settings con git-branch-guard cableado) en repo desechable → `sincronizar-cerebro.sh --apply` → archivo borrado, cableado quitado, merge-develop-guard sigue cableado, settings.json válido. OK.

## 5c9f4ed (H7b) — revisado por claudio 15:30
- Lib sana: push develop FRENA, push ramita pasa. Lib ausente / vacía / con error de sintaxis / sin acg_push_toca_base: push develop FRENA (antes vacía pasaba). OK.
- Con la lib rota también frena el push a una ramita (el fallback no distingue destino). Aceptable como fail-safe ruidoso: la lib rota es una avería, no un caso de uso.

## 6bd6e74 (paso 3·A1, fuera el freno de --auto) — revisado por claudio 15:55
- Clon desechable de PowerScripts marcado `.claude/repo-compartido`, PR real #245 (base develop), gh autenticado vía GH_CONFIG_DIR, HOME falso.
- Viejo: `--squash --delete-branch --auto` → deny por --auto. Nuevo: ya no lo frena el --auto; cae al juez (en el sandbox el juez no tiene token OAuth → deny "sin token", igual que sin --auto). OK.
- `--squash` sin `--delete-branch` → sigue deny en ambos (decisión 2 de unjordi respetada).
- Nota de método: en un repo SIN la marca repo-compartido el guard sale antes (personal) — PowerScripts real no ejercita nada; para probar hay que marcar un clon.
- Paso 4 pendiente: la norma global y el CLAUDE.md de plantilladotnet aún dicen "A develop/main NUNCA --auto".

## 8ca0ca0 (A2, mensaje del squash → recordatorio) — revisado por claudio 16:45
- Comando real: `gh pr merge 245 --squash --delete-branch --subject "fix" --body "arreglo"` (mensaje pobre, sin Rama:/MR:).
- 41ae2b3: deny por el mensaje en personal Y en compartido. 8ca0ca0: personal → sin decisión + recordatorio en additionalContext; compartido → ya no frena por el mensaje, pasa al juez (en el sandbox: sin token). OK con la decisión.

## 4d903f3 (B: repo/destino por git) — revisado por claudio 17:40, PR real #245, clones reales, HOME falso con ~/code enlazado
- Desde cwd plantilladotnet (compartido) `gh pr merge 245 --repo unjordi/PowerScripts --squash --delete-branch` → PASA + recordatorio (scoping de PowerScripts). Viejo: pasaba en silencio.
- `git -C $M pull && gh pr merge 245 --repo unjordi/PowerScripts …` (FP axon L167) → PASA + recordatorio.
- Desde cwd PowerScripts (personal) `gh pr merge 245 --repo $R …` → viejo PASABA sin juez (hueco); nuevo → al juez. OK.
- B3/B4 diferidos: de acuerdo (sin clon local ya gatea; sin red extra en PreToolUse).

## d4b24c3 (no-bypass-deploy, boundary del intérprete) — revisado por claudio 18:50
- Banco corrido por mí: 10 FP pasan, 0 vivos, 4/4 controles+. Directos: `ls -1 bootstrap.sh macos/install.sh` y `git diff -- …` → antes AVISA, ahora calla. `bash brain/install-brain.sh`, `sh macos/install.sh`, `./install.sh`, `bash ./deploy.sh` → AVISA. OK.
- BAJO (heredado, ya pasaba en 52d2d8c): en subshell `(bash ./install.sh)` y `(bash ./deploy.sh)` → CALLA. Tu mensaje dice que "(bash" sigue contando; medido, no. Test: las dos formas entre paréntesis → AVISA.

## b38d319 (proteger-arbol L11) — revisado por claudio 19:15
- MEDIO: repo con develop + 1 commit LOCAL sin pushear; en develop `git reset --hard origin/develop` → 05a8483 AVISA, b38d319 CALLA (deja huérfano el commit). Suprimir solo si rev-list --count origin/<base>..<base> == 0.
- Decisiones de claudio sobre los 4 del juez: H4 = afinar juez (decisión #1 de unjordi descarta el determinista); H5/L71/H9 = precisión, validar LIVE.
