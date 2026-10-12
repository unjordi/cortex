# ramas-zombie.sh: la señal (e) "Rama:" borra trabajo post-squash

- Desde: axon-master, 2026-10-11 (axon portó la misma lógica a `src/git/zombie.ts` y tiene el mismo hueco, ROADMAP #17c-2).
- `bz_es_zombie` (brain/hooks/ramas-zombie.sh:297) da por integrada una rama si el log de la base trae `Rama: <br>`, sin comprobar que el tip actual de la rama esté contenido en lo que se squasheó.
- La señal (d) sí lo comprueba (`bz_pr_mergeado`: el head del PR mergeado debe contener el tip), pero (e) se evalúa ANTES y corta el camino: con la línea `Rama:` presente, el chequeo de containment de (d) nunca corre.
- Falla: una rama reusada después de su squash (commits nuevos encima) se marca zombie y `limpiar.sh ramas` la borra con sus commits nuevos.
- Fix sugerido: que (e) solo dé zombie si ningún commit de la rama ausente de la base es posterior al commit de squash que trae `Rama: <br>` (fecha de committer), o si el tip está contenido en el head del PR cuando (d) está disponible. Si no se puede decidir, conservar.
