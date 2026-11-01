#!/usr/bin/env bash
# sesion-inicio.sh — SessionStart hook. Rehidrata el "cerebro" del repo al abrir
# sesión (source=startup), al retomar (resume) y DESPUÉS de una compactación de contexto
# (source=compact). NO bloquea: inyecta additionalContext con la rama, la norma de git y
# la orden de leer la memoria antes de tocar código o declarar nada terminado.
# Antídoto a "se me va la onda al cambiar de sesión/compu o cuando el sprint es largo".
# Tier GLOBAL: lo instala el bootstrap en ~/.claude/hooks; corre en TODA sesión. Rehidrata en TODA sesión
# que arranque DENTRO de un repo git; fuera de un repo git calla (gate abajo) — no es un "cerebro del repo"
# que aplique. Genérico: sirve para cualquier stack (semilla plantillaRepoVacio). El aviso de
# MIGRACIÓN/paridad NO vive aquí (es dominio del proyecto consumidor —p. ej. un repo .NET—, no del
# cerebro portable): va en el sesion-inicio del propio repo consumidor, no en esta versión genérica.
set -u

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
# Corre en TODA sesión (hook global), también en ~/Downloads y otras carpetas que NO son repo. El "cerebro
# del repo" (rama, norma de git, ritual de memoria) solo aplica DENTRO de un repo git → fuera, calla
# (rc 0, sin inyección).
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
MEM="$ROOT/.claude/memory"
branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")

lines=()
lines+=("🧠 CEREBRO DEL REPO — léelo ANTES de tocar código o declarar algo terminado.")
lines+=("Rama actual: ${branch}.")
lines+=("Ojo: lo que ves/muestras es de ESTA rama; en otra rama puede diferir. Si algo «desaparece» al cambiar de rama (p. ej. el backlog o un archivo), NO es pérdida — es el working tree rotando; avísalo, no lo trates como borrado.")
case "$branch" in
  develop|main) lines+=("⚠️ Estás en una rama PROTEGIDA: no se commitea ni pushea aquí. Saca una ramita feat/… desde develop.");;
esac
lines+=("")
lines+=("NORMA DE GIT (dura, la hace cumplir el hook merge-develop-guard): NUNCA push a develop/main; todo va a ramitas (feat/fix/chore/docs) → MR → develop; main es release-only (normalmente lo promueve el humano en la web de GitLab; por CLI solo con OK súper-explícito, lo vigila merge-develop-guard).")
lines+=("→ FLUJO DE GIT: en una RAMITA de trabajo, commitea y pushea a la ramita LIBREMENTE, sin preguntar ('¿commiteo? ¿pusheo?' → no preguntes, hazlo). El ÚNICO punto donde te DETIENES a confirmar es CERRAR EL SLICE / integrar a develop: antes del MR (a) verifícalo tú — la verificación técnica que aplique a tu stack (build/tests/lint) verde + memoria al día (el hook Stop lo checa) y (b) el merge a develop exige confirmación EXPRESA del usuario (lo hace cumplir el hook merge-develop-guard). Release a main = decisión humana en la web.")
lines+=("")
lines+=("RITUAL ANTI-PÉRDIDA-DE-HILO:")
lines+=("1) Lee .claude/memory/MEMORY.md (índice) y las memorias del proyecto que liste (dónde quedó el avance: hecho/pendiente/fuera-por-decisión).")
lines+=("2) Si el repo tiene AGENTS.md (contrato de arquitectura), léelo antes de crear o modificar código.")
lines+=("3) NO declares nada 'listo/en producción' sin la verificación técnica que aplique (build/tests/lint) + la memoria actualizada + confirmación del usuario. La «Definición de LISTO» es NORMA y su mecanismo es el TRATO/CONTRATO (no un hook): comunica el estatus honesto —qué quedó verificado y qué falta— y no declares cierre sin (1) QA del usuario o (2) su OK expreso.")

# Resumen del estado (si el proyecto ya tiene un archivo de estado; tolera varios nombres de convención)
for f in estado-proyecto estado-y-pendientes estado; do
  if [ -f "$MEM/$f.md" ]; then
    resumen=$(grep -m1 -iE '^\*\*Resumen|^description:' "$MEM/$f.md" 2>/dev/null | sed 's/<!--.*-->//; s/^description:[[:space:]]*//; s/^"//; s/"$//')
    [ -n "${resumen:-}" ] && { lines+=(""); lines+=("ESTADO ($f.md): ${resumen}"); }
    break
  fi
done

ctx=$(printf '%s\n' "${lines[@]}")

if command -v jq >/dev/null 2>&1; then
  jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
else
  printf '%s\n' "$ctx"
fi
exit 0
