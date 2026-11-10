# Las ramas REEMPLAZADAS (-rebased, -v2, -v3) quedan huérfanas en origin

**De:** claudio-master · 2026-10-28 · prioridad por fricción: media (barrido manual en cada ronda)

## Qué pasó
En la ronda del 28-oct quedaron 7 ramas viejas en origin (`fix/buzon-*`, `fix/retirar-proteger-autorizaciones{,-v2}`).
`cerrar-slice` sí borró las que mergeó (`--delete-branch`), pero las versiones anteriores de esas mismas ramas
no tuvieron PR mergeado: se re-cortaron con otro nombre porque el clasificador frena el force-push sobre la rama original.

## Por qué ningún mecanismo las ve
- `cerrar-slice` borra solo la rama del PR que mergea.
- `limpiar.sh ramas` usa señales positivas (ancestro, `Rama:` del squash, PR mergeado, patch sin `+`). Una copia
  reemplazada no da ninguna: el squash dice `Rama: …-v3` y la `-v2` no tiene PR mergeado.

## Propuesta (señal positiva, squash-safe)
`git merge-tree --write-tree origin/develop origin/<rama>` produce el MISMO árbol que `origin/develop^{tree}`
⇒ la rama no aporta nada ⇒ se puede borrar. Medido: 3 de 7 dieron árbol idéntico. Las otras 4 diferían solo en
`bitacora.md` (la misma línea con otra redacción, merge=union); quizá convenga ignorar `bitacora.md` al comparar.
Y en `cerrar-slice`: al mergear `X-vN`, ofrecer el barrido de `X`, `X-rebased` y `X-v<k>` (k<N) que pasen esa prueba.

## Decisión de unjordi (2026-10-28)
[user: "ok, va. acepto tu recomendación"] sobre la recomendación de claudio:
- El SQUASH a develop se queda como está (no se cambia la mecánica de integración).
- `merge-tree` entra como señal POSITIVA adicional en `limpiar.sh ramas`: árbol idéntico ⇒ borrable;
  árbol distinto NO prueba que aporte (medido: 4 de 7 ramas ya integradas dieron distinto porque develop
  siguió tocando los mismos archivos) ⇒ revisar o mirar el estado del PR.
- Causa raíz a atacar también: cuando el clasificador frena el force-push, la rama se re-corta con sufijo en vez de
  rebasearse en su mismo nombre; eso fabrica las huérfanas.
