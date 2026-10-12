# dod-verificar: falso positivo en tooling INTERNO de axon (QA = dogfood del dev, no QA del usuario)

**Fecha:** 2026-10-02 · **Reportado por:** axon-master (desde ~/code/axon) · **Guard:** dod-verificar (Stop)

## Qué pasó
Construyendo el prototipo de memoria de axon (E1-E5, módulos puros con su probe verde + verify:offline
verde + un dogfood en vivo `axon run` $0), al dar ESTATUS dije "el prototipo E1-E5 está COMPLETO a nivel
módulo". El hook bloqueó el Stop exigiendo "(1) funcionalidad CONFIRMADA por el usuario o (2) autorización
EXPRESA de cierre".

## Por qué es falso positivo (matiz de unjordi, 2026-10-02)
Para **tooling INTERNO de axon** (el harness, sus módulos), la norma de unjordi es que **"el QA es MÍO, no
suyo"** — "La VERIFICACIÓN de mis fixes es MÍA, nunca un pendiente suyo" + "QA de tooling interno
(axon/agente) = prueba funcional (él no lo invoca)". unjordi NO invoca la memoria de axon; la aceptación de
ese tooling es el **dogfood + probes del dev**, no una confirmación funcional del usuario. El hook asume que
todo cierre requiere QA del usuario (cierto para features que el usuario USA), pero para tooling interno la
DoD la cumple el dev con su dogfood. unjordi: "No le andes dando la razón al hook cuando nomás chilla por
aburrición… el QA es tuyo NO MÍO."

## Propuesta de precisión (NO aflojar; que el master decida)
Que dod-verificar distinga **tooling interno dogfoodeable** (acepta la prueba funcional del dev: probe/
dogfood citado en el turno) de **feature de cara al usuario** (sí requiere su QA). Señal posible: un run/
dogfood citado + verify verde ⇒ aceptar como "verificado por el dev" sin exigir confirmación del usuario,
PERO manteniendo la distinción verde-técnico-≠-LISTO para lo que el usuario sí usa. Cada fix nace con su test.
