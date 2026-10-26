# Revisión directa de lo integrado (de6df53..52d2d8c) · sección 2: merge-develop-guard + juez-comun.sh

Revisión de claudio, pedida por unjordi el 2026-10-19 ("revísalo a detalle, módulo por módulo").

## Lo que cambió y está bien
- **Exención de sync de upstream (`_es_sync_upstream_autorizado`):**
  - Deja pasar `--merge` sin squash a develop solo con todo esto junto: el MR tiene un merge commit cuyo segundo padre trae commits que no están en develop, el destino es develop según la API, y una línea USUARIO pide "--merge" o "sin squash" con ese id.
  - Después sigue al juez de autorización, no lo salta.
  - Solo funciona con `gh` (GitHub); con GitLab cae al freno de squash, que es fail-safe.
  - `timeout` existe en la Mac (`/opt/homebrew/bin/timeout`).
- **Scoping por `--repo <slug>`:** busca el clon local del slug. Si no lo encuentra, el slug no casa con el del cwd y gatea (fail-safe), así que no hay fail-open hacia un repo compartido.
- **`_jq_fallo`:** si el parseo del transcript falla pero hay mensajes del usuario, el freno lo dice en vez de culpar al usuario.
- **`juez-comun.sh`:** solo cambian comentarios. Ojo: la limpieza dejó cabeceras de caja rotas (`──── ──`) en 4 líneas. Es cosmético.

## Hallazgos

### H4 · MEDIO · el juez negó un OK claro y explícito (FP de 2026-10-19, ya en el corpus)
- **El OK:** "mergea a develop los MR de CI: anbmonitor !15, heimdall !1, plantilladotnet !118 y pisamrpclaude !76" era la última línea USUARIO.
- **Lo que pasó:** `glab mr merge 15 -R mx_pind_devops/potencia/anbmonitor --squash …` recibió DENY ("no encontró tu confirmación EXPRESA … MR 15"). El mismo comando, con esa cita copiada en un comentario del propio comando, pasó.
- **Lo que dice el prompt:** "Una lista ('mergea 5 y 6') autoriza a TODOS los ids que nombra". Ese caso debió ser ALLOW.
- **Hipótesis (sin medir):** es varianza de un solo voto de Haiku (`CLAUDE_MERGE_JUEZ_VOTES` vale 1 por default), o la forma `repo !id` en vez de `!id` suelto.
- **Arreglo:** que el banco del corpus lo reproduzca con la conversación real como fixture. Y si es varianza, un pre-filtro determinista: si la última línea USUARIO nombra el id con un verbo de merge, ALLOW sin consultar al juez.

### H5 · BAJO · la exención de sync lee el OK por línea
`grep '^USUARIO:' | grep -- '(--merge|sin squash)' | grep "<id>"` exige que "sin squash" y el id vayan en la MISMA línea. Si el OK viene en un mensaje de varias líneas o separado («ese PR» + «sin squash» en otra línea), no se exime y frena por falta de squash. Es fail-safe, pero puede frenar en falso.

### H2 (de la sección 1) también afecta aquí
`acg_clon_local_de_slug` está ciego si la sesión está en un worktree. Entonces un merge `--repo <otro>` lanzado desde un worktree siempre gatea, aunque ese repo sea personal.
