# DECISIÓN de unjordi: se retira dod-verificar; la norma de LISTO se queda como norma
Fecha: 2026-11-01 · De: claudio-master (coordinando con unjordi) · A quién le toca: cortex-master

Decisión [user 2026-11-01: "la norma de LISTO se queda como norma. decidido."], en respuesta a: «Si lo retiras: la
norma de LISTO se queda como norma y la de "toda norma nace con su mecanismo" registra que ahí el mecanismo es el trato».
Contexto: unjordi [user: "dod-verificar cada vez me cae peor. estoy a nada de deprecarlo for good"]; corpus con >230 FP
entre todos los guards y nota de 30 FP de tuning propia de dod-verificar.

Qué hacer:
- Retirar el hook `dod-verificar` (Stop) del cerebro: MANIFEST, instalador (que lo DESINSTALE de las máquinas), copias por-repo y su cableado, tests.
- La sección «Definición de LISTO» de las normas globales se conserva; quitar las líneas que dicen que la hace cumplir `dod-verificar`
  y anotar en «Toda norma nace con su mecanismo» que para LISTO el mecanismo es el trato/contrato, no un hook.
- Cerrar como «muere con el retiro» las notas/ítems de FP de dod-verificar (2026-10-30-dod-verificar-tres-fp, B-06, B-34, 30-fp-tuning, etc.).
- Rastrear las copias de la doc que lo citan (CLAUDE.md global, CLAUDE.md de plantilladotnet, README del cerebro, flowcharts).

DECIDIDO TAMBIÉN [user 2026-11-01: "y solo cerebro global, también decidido"]: queda ÚNICAMENTE el cerebro GLOBAL
en cada máquina; se retira el cerebro por-repo. Motivo de unjordi: todo su equipo tiene cortex instalado y los repos que le
importan son esos [user: "estar de ansioso por que los repos se trabajen en computadoras sin cortex es pura paranoia mía"].
Qué hacer:
- Retirar de los repos las copias de hooks/libs del cerebro y su cableado en `.claude/settings.json`; en cada repo queda solo lo
  del PROYECTO (memoria, estado-proyecto, bitácora, hilo, skills propias del proyecto).
- Retirar `sincronizar-cerebro.sh` (y `--limpiar-personal`, `--prune-orphans`), la rama por-repo de `aviso-drift-cerebro`,
  los tiers both/repo + la cláusula de dedupe, y la marca `.claude/repo-compartido`.
- Los hooks hoy tier `repo` (`sesion-inicio`, `recordar-cosechar`) pasan a global o se retiran (criterio tuyo, avísale a claudio).
- Normas globales: reescribir «Cerebro por-repo = CORREO…» y «Tiers de hooks/skills» a la realidad nueva.
- Marcar «muere con el retiro» los ítems que dejan de tener sentido (B-02, B-13, parte de B-01, ciclo install/update por-repo, etc.). OJO: B-03 NO muere — el drift por mtime también afecta a la copia GLOBAL (los «23 editados en vivo» de hoy son de ~/.claude/hooks).
- La propagación a los repos (plantilladotnet, cps, fluxcore, …) va por su flujo de git normal, repo por repo.

ORDEN (acordado con claudio-master): (1) cortex-fetch, (2) que el widget diga la verdad (mide mal al despertar, carry-forward
del OAuth, B-35), (3) estas dos decisiones (retiro de dod-verificar y del cerebro por-repo), (4) precisión de
merge-develop-guard (B-04), (5) aliases-activos: que install-brain deje de regenerarlos (pedido directo 28-oct; en la práctica ya resuelto por bash),
(6) lo que sobreviva del buzón. B-05 (proteger-autorizaciones) YA está retirado en develop (7ca5163, 28-oct): fuera del orden. Épicas, auditorías viejas e higiene: parqueadas hasta que unjordi las pida.

## Lo que SOBREVIVE del buzón (revisado por claudio-master con unjordi, 2026-11-01)
MUERE con los retiros: B-02, B-06, B-13, B-34, la parte aliases de B-29, las notas de FP de dod-verificar, la VIVA limpiar-personal.
YA HECHO: B-01, B-05/B-15 (7ca5163), B-11, B-20 (verificar contra la nota 28-oct «exportar dejó de actualizar games-master»). B-16 = no-code.
SOBREVIVE, en este orden:
- ALTA fricción: B-03 (drift global por mtime → sellar SHA, decidir por contenido) · B-04 + VIVA «grant en vivo» (merges frenados) ·
  2026-10-28-install-permiso-cerrar-slice (install-brain siembra el permiso de cerrar-slice; merges frenados por el clasificador).
- Sesiones de fondo: 2026-10-28-cerrar-y-exportar-no-ven-sesiones-de-fondo (`--cerrar` dice cerrado y sigue viva; export no actualiza) · B-10 (seed/masters.json rancio).
- Widget/cuota (va con el punto 2 del orden): B-23, B-35, B-14 (numerador de aviso-contexto).
- Continuidad: B-07, B-18, B-32, VIVA hilo-stale-al-rehidratar.
- Barrido/ramas: B-08 (estado de hooks dentro del repo), B-09, B-12, B-21, 2026-10-28-ramas-reemplazadas-quedan-huerfanas.
- Doc/skills chicos: B-22, B-24, B-26, B-27, B-28 (revisar si a7e865c ya lo cerró), B-29 (solo el cap de description), B-30, B-33.
- Proceso (sin código): 2026-10-28-pregunta-parche-dejo-bug-parado → regla de triage: una opción que rodea el bug no es alternativa.
- Revisar con unjordi: B-19 (vigilar-master ya no se usa: ¿retirarlo?), B-25 (2ª pasada utilitaria), B-31 (hito «repo nuevo»), B-36 (worktree cortex-wt-quota),
  2026-10-28-cerrar-slice-avisar-a-terceros (paso para avisar al SGC de Calidad).

## B-36 y la higiene de worktrees (claudio-master, 2026-11-01, medido)
- `cortex-wt-quota` YA NO EXISTE (ni en la Mac ni en la cachy) y lo suyo (`equiv_session_cost_usd`) está en develop en macOS, Linux, KDE, Windows y delegacion-comun → B-36 se cierra como superado. Era un ítem [SIN VERIFICAR] que se arrastró.
- PERO la cachy tiene un worktree zombie: `~/code/cortex/.claude/worktrees/espejo-silencioso` (fix/espejo-stop-silencioso, limpio) cuyo trabajo YA entró a develop como #472 (a218cd9). El barrido no lo quitó.
  [INFER] causas: el develop local de la cachy está 15 commits atrás (52d2d8c) y desde ssh no-interactiva `git ls-remote` da «Permission denied (publickey)» (falta SSH_AUTH_SOCK), así que no ve la integración.
  unjordi: [user: "ya deberíamos tener bien hecho nuestro mecanismo de higiene de ramas!!"] → que el barrido haga fetch con el agente ssh correcto y, si no puede consultar el remoto, lo AVISE en vez de conservar callado. Va con el punto 3 (clon de la cachy).

## B-31 SOBREVIVE (unjordi, 2026-11-01)
[user 2026-11-01: "El mecanismo de instalación precompilado sin depender de clonar el repo en cada compu se queda. de todos modos seguirá habiendo widget con o sin plugin."]
→ El hito de la nota 2026-10-23-repo-publico-nuevo sigue vivo (distribución precompilada sin clonar: .app / .msi o irm|iex / Flatpak; repo público curado; español+inglés).
B-31 = asentarlo en estado-proyecto.md como «Siguiente hito» (hoy solo vive en esa nota y en el Excel). Sale de «revisar con unjordi»; no se parquea.

## Release (unjordi, 2026-11-01)
[user: "no hemos hecho release desde entonces por TODOS estos bugs. y así seguirá hasta que me sienta contento propagandolo hacia mi equipo de trabajo. El deploy ha sido manual todas estas veces"] → no hay release develop→main hasta que unjordi lo diga; en sus máquinas el deploy es manual.
