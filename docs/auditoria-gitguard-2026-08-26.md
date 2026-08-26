# Auditoría adversarial — git-branch-guard (turno nocturno 2026-08-26)

> **Método:** tripla híbrida — qwen3.8:27b propone vectores de evasión (lente adversarial), Claude los
> VERIFICA POR EJECUCIÓN contra el guard REAL en un sandbox git (mismo enfoque que `brain/test-brain.sh`,
> con el dedupe neutralizado vía `HOME` vacío para ejercitar la copia de `brain/`). Alcance: los guards de
> git (`git-branch-guard.sh` + la lib `analizar-comando-git.sh`). **Read-only**: NO se tocó `brain/` ni se
> arregló nada — dictamen INSUMO, los fixes esperan OK explícito de unjordi (Integridad de guardarraíles:
> cambiar un guard de supervisión exige OK para ESE control, y solo de PRECISIÓN).

## Veredicto
El guard es **robusto** en su núcleo: cazó correctamente `$(echo develop)`, `"develop"` entrecomillado,
`HEAD:develop`, `+develop`, `--all`/`--mirror`, `--repo=…/develop` (ignora el valor de `--repo`), el push
PELÓN en develop/main, y NO se dispara en falso con `--tags`, `developer`, `my-develop-branch`,
`feat/develop-x`. **1 hallazgo NUEVO de precisión (falso positivo)** + confirmación de los residuos M3 ya
documentados (falsos negativos aceptados con backstop server-side).

## Hallazgo NUEVO · FALSO POSITIVO sobre ramas `*/develop` y `*/main` — BAJO-MEDIO, CONFIRMADO POR EJECUCIÓN
- **Dónde:** `analizar-comando-git.sh`, `acg_push_destino_base` — el regex
  `git[[:space:]]+push[^;&|]*[[:space:]:/+](main|develop)([[:space:]]|$|[)>&|;])`. La clase separadora
  `[[:space:]:/+]` incluye `/`, que además de `origin/develop` matchea el **slash interno del path de una
  rama local legítima**.
- **Qué:** un `git push` de una rama cuyo nombre TERMINA en `/develop` o `/main` se BLOQUEA en falso.
- **Prueba ejecutada** (sandbox, guard real):
  | comando | resultado | ¿correcto? |
  |---|---|---|
  | `git push origin feat/develop` | **DENY** | ✗ FALSO POSITIVO |
  | `git push origin hotfix/main` | **DENY** | ✗ FALSO POSITIVO |
  | `git push origin feature/develop` | **DENY** | ✗ FALSO POSITIVO |
  | `git push -u origin fix/develop` | **DENY** | ✗ FALSO POSITIVO |
  | `git push origin release/main` | **DENY** | ✗ FALSO POSITIVO |
  | `git push origin --delete feat/develop` | **DENY** | ✗ FALSO POSITIVO |
  | `git push origin feat/develop-x` | ALLOW | ✓ (sufijo rompe el match) |
  | `git push origin developer` | ALLOW | ✓ (substring) |
  | `git push origin develop` / `main` / `HEAD:develop` | DENY | ✓ (verdaderos) |
- **Impacto:** un dev con una rama `release/main`, `hotfix/main`, `feature/develop`, `fix/develop`… NO puede
  pushearla ni borrarla — el guard la confunde con la base. Nombres poco comunes pero legítimos; muerde
  justo cuando alguien los usa. La PRECISIÓN del guard importa tanto como su existencia (norma "toda norma
  nace con su mecanismo" + corpus de falsos positivos).
- **Por qué es sutil el fix:** `refs/heads/develop` (que SÍ debe bloquear) y `feat/develop` (que NO) ambos
  terminan en `/develop`; distinguirlos por regex del último segmento es ambiguo. Una vía: tratar `develop`/
  `main` como protegidas solo cuando son el TOKEN de rama completo, `HEAD:develop`, `refs/heads/develop`, o
  el destino de un refspec `src:dst` — no cuando son el sufijo de un path `foo/develop` que es el nombre
  COMPLETO de la rama-fuente. Requiere distinguir el refspec `origin <branch>` del `origin src:dst`.
- **Integridad de guardarraíles:** es un cambio de PRECISIÓN (menos falsos positivos), del tipo permitido —
  PERO exige OK explícito de unjordi para ESE control, y su test (cada fix nace con su caso en `test-brain.sh`).
  Toca el ruleset COMPARTIDO cortex↔axon → re-derivar la paridad 84/84 de axon.

## Residuos M3 confirmados (ya documentados — falsos NEGATIVOS aceptados)
Re-confirmados por ejecución esta noche (no son nuevos; viven en el backlog de axon como M3, ACEPTADOS con
backstop de ramas protegidas server-side):
- `BRANCH=develop; git push origin $BRANCH` → **ALLOW** (variable no expandida — el guard ve el literal).
- `git push origin dev\elop` → **ALLOW** (backslash-escape; el shell lo vuelve `develop`, el guard ve `dev\elop`).
Estos son evasiones por ofuscación de shell inherentes a un guard basado en análisis de string (no ejecuta el
shell). El backstop real: ramas protegidas server-side en GitLab. NO perseguir indefinidamente (modo de falla
del skill `auditar-coherencia-cerebro`); documentados y aceptados.

## Qué NO se auditó (pendiente, para una pasada con OK/tiempo)
- `secret-scan.sh` + `detectar-secretos.sh` (44/44 en test-brain, no re-fuzzeado esta noche).
- `confirmar-merge-develop.sh` (422 líneas, target-aware) y `merge-squash-guard.sh`.
- Coherencia doc↔código (dimensión C) y suficiencia operativa del cerebro de cortex.
- La pasada colectiva (costura entre guards).
