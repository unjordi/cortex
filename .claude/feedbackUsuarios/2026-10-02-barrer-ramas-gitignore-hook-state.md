# barrer-ramas (y aviso-contexto) escriben estado per-máquina sin gitignorearlo → rompen CDs que verifican árbol-limpio

**De:** axon-master (Cachy) · **Fecha:** 2026-10-02 · **Severidad:** media (rompió un CD 6 veces seguidas)

## El problema (medido en vivo)
Los hooks del cerebro escriben **dotfiles de ESTADO per-máquina** dentro de `.claude/memory/` en cada
merge/sesión, pero **el bootstrap/gitignore del cerebro NO los ignora**. Vistos ensuciando el working tree:
- `.claude/memory/.ramas-huerfanas-estado` — lo escribe **`barrer-ramas`** en cada merge detectado.
- `.claude/memory/.contexto-aviso.d/<session>_` — lo escribe **`aviso-contexto`**.
- `.claude/memory/.barrer-ramas/<pid>.log` + `.worktrees.log` — logs del barrido.

Como `.claude/memory/` es **tracked** (el cerebro viaja), estos dotfiles aparecen como **untracked →
árbol SUCIO**. En un repo con CD que verifica "lo construido ES un commit" (odysseus, `verificar-despliegue`
eje ÁRBOL), eso **tumba el deploy en rojo repetidamente**: hoy el `deploy-axon` falló **6/6 corridas** —
el deploy del axon SÍ ocurría (eje INTEGRADO ✅), pero la verificación veía el árbol de odysseus sucio por
`.ramas-huerfanas-estado` (+ otros) y salía exit 1. Lo cacé porque unjordi notó "mis mejoras no se
despliegan": sí se desplegaban, el CD mentía en rojo por higiene de árbol.

## Por qué es del cerebro, no del repo
Si `barrer-ramas` ESCRIBE ese archivo en cada merge, **debería venir gitignoreado desde el bootstrap**
(unjordi: *"si lo escribe barrer-ramas en cada merge, debería estar gitignoreado desde un principio"*).
Parcharlo por-repo (como tuve que hacer en odysseus, PRs #95/#96) es un band-aid que cada clon repite.

## El fix propuesto (para que el master de cortex decida)
Que el bootstrap/`install-brain` del cerebro **añada al `.gitignore` del repo** (o que los hooks escriban
a una ruta ya ignorada, p.ej. `.claude/memory/.state/`) estos patrones:
```
.claude/memory/.ramas-huerfanas-estado
.claude/memory/.contexto-aviso.d/
.claude/memory/.barrer-ramas/
```
Alternativa más limpia: que TODO el estado volátil de hooks viva bajo UN prefijo ya gitignoreado
(`.claude/memory/.state/…`), así un solo patrón lo cubre y no hay que enumerar cada hook nuevo.

## Alcance observado
Pasa en axon Y odysseus (ambos clones del cerebro en la Cachy). El parche por-repo quedó en odysseus
(#95 `.env.bak*`+`.wt-*/`, #96 los dotfiles de hook). axon aún los escribe sin gitignorear (lo vengo
limpiando a mano cada merge esta sesión) — candidato al mismo fix cuando el cerebro lo resuelva de raíz.
