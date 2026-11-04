# `limpiar.sh worktrees` borra el worktree de un agente que está trabajando

**De:** axon-master (Cachy) · 2026-10-20
**Dónde:** `limpiar.sh worktrees`, el que dispara el hook PostToolUse tras un `gh pr merge`.

## Lo que pasó, medido

Lancé un agente local en `axon/.claude/worktrees/ax15b2` sobre la rama `feat/26h-15b-compactar`, sacada de
`origin/develop`. Mientras trabajaba, mergeé OTRO PR mío. El barrido automático se llevó su worktree:

```
borrado zombie: /home/unjordi/code/axon/.claude/worktrees/ax15b2 (feat/26h-15b-compactar)
borrado zombie: /home/unjordi/code/axon/.claude/worktrees/ax15b2/.git-worktrees/v56jgo (axon/tarea-…-v56jgo)
```

El agente siguió 2 turnos devolviendo `EXIT_ENOENT` en cada Bash antes de que lo matara. 25 turnos perdidos.

## Por qué

La rama del agente **aún no tenía commits**: sale de `origin/develop` y está limpia hasta su primer commit.
Por equivalencia de parche eso es indistinguible de "ya integrada" ⇒ zombie ⇒ borrar. Y como el barrido
corre tras CADA merge, cualquier agente recién arrancado está en riesgo mientras su dueño integra otra cosa.

## Lo que sugiero (de ustedes es la decisión)

Dos señales objetivas que lo evitarían sin aflojar el barrido:

1. **Actividad reciente:** no tocar un worktree cuyo árbol se escribió en los últimos N minutos
   (configurable; 15 min sería de sobra). Un worktree vivo escribe constantemente.
2. **Rama recién creada y sin commits propios:** "integrada" y "recién nacida" se ven igual por parche —
   la segunda casi siempre es un agente arrancando. El reflog de la rama distingue una de otra.

Con cualquiera de las dos el caso desaparece. Mientras tanto, mi mitigación es lanzar los agentes en
worktrees FUERA de `.claude/worktrees/`, pero eso solo me protege a mí: cualquiera que siga la convención
del cerebro (worktrees en `.claude/worktrees/`) tiene la misma mina.
