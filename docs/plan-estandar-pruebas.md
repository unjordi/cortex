# Plan — protocolo de pruebas unificado (2026-11-14)

Rebanada de claudio-master [user: "en TODOS los proyectos tengo el mismo problema: miles de pruebas que pasan en verde pero no revisan nada útil"; "esta rebanada sí quiero que la armes tú porfavor, y que incluya actualizar la plantilladotnet"; la pasada corre "al cierre de cada epica, y como uno de los pasos de cerrar-slice"; revisión semántica de CADA ítem].

1. ✅ Skill global `estandar-pruebas` (cortex `brain/skills/estandar-pruebas/`, tier global en el MANIFEST): §1–§10, firmas R1–R8, revisión semántica de cada ítem (§8), pasada de limpieza (§9). Fuentes: `axon/docs/estandar-pruebas.md`, «Lo que un banco VERDE no prueba» de `auditar-proceso-algoritmo`, informe de games-master (`~/juegos/.claude/projects/ikaruga-psp/pasada-limpieza-pruebas-2026-11-13.md`).
2. ✅ La norma global de pruebas (`brain/norms/global-claude-md.md`) apunta al skill.
3. ✅ `mandato-loop` → PRUEBAS apunta al skill; §7 = revisión semántica de CADA ítem; §8 = la pasada.
4. ✅ `auditar-proceso-algoritmo` deja de duplicar las formas del banco verde y apunta al skill.
5. ✅ `cerrar-slice` §1: paso «Pasada de pruebas del slice», con el rojo contra la base citado por prueba nueva.
6. ✅ Mecanismo `cerrar-slice/contraprueba.sh` + sus casos en `test-brain.sh` (prueba buena → 0, tautología → 1, archivo inexistente → 2, sin worktrees colgados).
6b. ✅ Cableado (lo destapó la revisión semántica del 6: definido ≠ cableado): `cerrar-slice.sh` frena el merge de un slice que AGREGA pruebas sin una línea `Contraprueba:` en el mensaje (`_contraprueba_gate`, con `_rango_slice`/`_repo_es_cwd` extraídos del gate de gitleaks y compartidos). Casos en `test-brain.sh`: con prueba y sin cita frena, con cita pasa, sin pruebas no exige. Cierra cuando `test-brain.sh` completo da 0 FAIL.
7. ⬜ Revisión semántica de los pasos 1–6 (abajo) (§8 del skill, cada uno con la suya) y MR de cortex a develop; queda instalado en la Mac y la cachy por la herramienta de release (widget/updater), no con `install-brain.sh` a mano.
8. ⬜ Plantilla .NET (rama `docs/pruebas-por-caso-de-uso`): `agregar-tests` reescrita desde el caso de uso con contraprueba; AGENTS.template §6 sin la meta de cobertura. Cierra con su MR y el OK de unjordi.
9. ⬜ Pasada §9 sobre las pruebas de la plantilla (27 archivos), como piloto: auditoría por prueba con veredicto por aserto, arreglos y retiros con su contraprueba, revisión semántica de cada uno. Cierra con `docs/auditoria-pruebas.md` en la plantilla y su batería en verde; va en la misma rama que el paso 8.
10. ⬜ Avisos: axon-master (su `docs/estandar-pruebas.md` queda como su §6 y sus casos), games-master (su informe quedó integrado), cortex-master (cambios en `mandato-loop`, `cerrar-slice` y `auditar-proceso-algoritmo`).

## Revisión semántica de cada paso (§8)
- **1 · skill.** Porqué: que un agente que escribe pruebas en cualquier repo tenga el estándar. Falla posible: es opt-in y puede no cargarse; lo cubren la norma global (siempre en contexto) que apunta a él, `mandato-loop` y el paso de `cerrar-slice`. Vecinos: `axon/docs/estandar-pruebas.md` sigue diciendo lo mismo con casos de axon (paso 10 lo reduce a su §6).
- **2 · norma global.** Una línea que apunta; no duplica el contenido. Sin efecto lateral.
- **3 · mandato-loop.** §7 ahora dice de CADA ítem y §8 es la pasada; la línea del piso de cada fila ya citaba la revisión semántica (PRUEBAS §7): coherente.
- **4 · auditar-proceso-algoritmo.** Se pierden las narraciones de casos (historia); las reglas quedan en el estándar (§2, §3, §5), incluida «definido ≠ cableado», que no estaba y se agregó.
- **5 · cerrar-slice §1.** Paso nuevo con la cita del rojo. Falla posible: depender de que quien cierra se acuerde → resuelto en 6b.
- **6 · contraprueba.sh.** Mide el efecto (corre la prueba contra la base), las dos direcciones (buena → 0, tautología → 1), escenario comprobado (la prueba pasa contra el arreglo) y limpieza. Límite declarado en su salida: una prueba que falla por no compilar contra la base también «falla»; el script pide comprobar que falla el aserto.
- **6b · gate.** Frena por la AUSENCIA de la cita, no juzga su contenido (no puede: eso es criterio de la pasada). Archivos de prueba detectados por ruta/nombre en los AGREGADOS del slice; una prueba nueva dentro de un archivo existente no la ve (la cubre la pasada §9 de cerrar-slice).
