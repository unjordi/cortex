# Feedback: el estado de `aviso-contexto` viaja por git — el brain no siembra su regla de ignore

**Fecha:** 2026-09-24 · **De dónde salió:** sesión `db-master` (potenciaDatabases), al encontrar 4 archivos
sucios en `git status` que no eran míos.
**A quién le toca:** cortex-master (hook `aviso-contexto` + el instalador/sincronizador del brain).

> ✅ **Esto SÍ está verificado contra el código y contra los 27 repos de `~/code`** (comandos abajo), salvo
> donde diga lo contrario. El hook lo abrí: `brain/hooks/aviso-contexto.sh`, líneas 37–49.

## El síntoma
`git status` de `potenciaDatabases` mostraba modificado
`.claude/memory/.contexto-aviso.d/582fff25-…_` — un marcador de sesión, **trackeado en git**. Había 4
archivos así en ese repo, uno por sesión, todos con una línea de contenido (un número).

## Qué escribe el hook (medido en el código)
```sh
# brain/hooks/aviso-contexto.sh:37-49
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel …)}"
MEM="$ROOT/.claude/memory"
AVISO_F="$MEM/.contexto-aviso"          # ← el diseño VIEJO: un solo archivo
AVISO_D="$MEM/.contexto-aviso.d"        # ← el diseño NUEVO: uno por session_id
if [ -n "$sid" ] && mkdir -p "$AVISO_D" …; then
  find "$AVISO_D" -type f -mtime +14 -delete   # purga a 14 días
  AVISO_F="$AVISO_D/$sid"
fi
```

**Es el ÚNICO hook que escribe estado en `.claude/memory/`.** Verificado barriendo `brain/hooks/*.sh` +
`brain/lib/*.sh`: las únicas rutas son `.contexto-aviso` y `.contexto-aviso.d`.

## La causa raíz
**El brain instala hooks, libs y skills, pero NO siembra ninguna regla de `.gitignore` para el estado que
esos hooks escriben.** `find brain/ -iname "*gitignore*"` → vacío; el único archivo de `brain/` que menciona
`contexto-aviso` es el hook mismo. Así que cada repo lo resolvió a mano, o no lo resolvió.

Encima, el estado **evolucionó de un archivo a un directorio** (`.contexto-aviso` → `.contexto-aviso.d/`) y
los `.gitignore` escritos a mano se quedaron con el patrón viejo. Git **no hace prefijo implícito**:
`.contexto-aviso` NO cubre `.contexto-aviso.d/`.

## Lo medido en los 27 repos de `~/code` con cerebro

| repo | patrón en su `.gitignore` | resultado |
|---|---|---|
| `plantilladotnet` | `.claude/memory/.contexto-*` | ✅ cubre ambos — **el único correcto, y por casualidad** |
| `axon` | `.claude/memory/.contexto-aviso` | ❌ no cubre el `.d/` |
| `potenciaDatabases` | `.contexto-aviso` + `.contexto-baseline` | ❌ no cubría el `.d/` (ver "lo que ya se tocó") |
| **los otros 24** | *(ninguno)* | ❌ sin regla |

Tres variantes distintas del mismo patrón, escritas a mano, para un estado que el brain crea solo.

Hoy el dir `.contexto-aviso.d/` existe en 2 repos (`plantilladotnet` 3 archivos, `potenciaDatabases` 4).
Los otros 25 aún no lo tienen creado — **pero lo tendrán en cuanto se abra una sesión ahí**, y 24 de ellos
no tienen regla que lo ignore. En `potenciaDatabases` los 4 llegaron a `git add` y se commitearon.

## Bonus: un patrón muerto
`potenciaDatabases` ignora también `.claude/memory/.contexto-baseline`. **Ningún hook escribe eso hoy** (el
barrido de arriba no lo encuentra) — es residuo de una versión anterior. Vale revisarlo al pasar.

## Los tres caminos que se le presentaron a unjordi *(no eligió — pidió parar y dejar el reporte)*

1. **Sacar el estado del repo.** Que el hook escriba en `~/.claude/memory/…/<slug>/` en vez de dentro del
   repo. Ningún repo se ensucia nunca y **ninguno necesita regla**. Es la norma global del propio brain
   aplicada a sí mismo — *"el entorno de MÁQUINA vive GLOBAL, jamás en un repo"* — y un marcador por
   `session_id` es exactamente eso. Cuesta tocar el hook y migrar lo existente.
2. **Sembrar el `.gitignore` desde el brain.** `install-brain.sh` / `sincronizar-cerebro.sh` aseguran
   `.claude/memory/.contexto-*` de forma idempotente. No toca el hook, unifica las 3 variantes; pero cada
   repo sigue cargando una regla por estado que no le pertenece.
3. **Solo parchar lo roto.** Unificar a mano `axon` y `potenciaDatabases`, limpiar los 2 repos con el dir.
   No repara la causa: el drift vuelve la próxima vez que el estado del hook evolucione.

**[INFER-mío]** La 1 es la que elimina la clase de bug en vez de taparla, y de paso hace que el brain
cumpla consigo mismo la norma que le exige a los repos. La 2 es la menos invasiva. No es mi decisión.

## Lo que YA se tocó (para que no se diagnostique dos veces)
Solo en **`potenciaDatabases`**, antes de entender que era un problema del brain y no de ese repo:
- el patrón pasó de `.claude/memory/.contexto-aviso` a `.claude/memory/.contexto-aviso*`;
- los 4 marcadores salieron del índice con `git rm --cached` (siguen en disco, ya ignorados).

Ambos commits están en la rama `churn-sae-Webapi` de ese repo. **Es un parche local**: si se adopta el
camino 1 o el 2, conviene revertirlo o alinearlo al patrón canónico (`.contexto-*`, como
`plantilladotnet`). **Ningún otro repo se tocó** — unjordi pidió parar y dejar esto escrito.

## Cómo re-medirlo sin escarbar
```sh
# el patrón de cada repo y cuántos marcadores tiene trackeados
for r in $(ls -d ~/code/*/.claude | sed 's|/.claude||'); do
  printf "%-28s trk=%-3s %s\n" "$(basename $r)" \
    "$(git -C "$r" ls-files '.claude/memory/.contexto-aviso.d/' | wc -l)" \
    "$(grep -hE 'contexto-aviso' "$r/.gitignore" 2>/dev/null | tr '\n' ' ')"
done

# qué regla ignora (o no) el dir, en un repo dado
git -C <repo> check-ignore -v .claude/memory/.contexto-aviso.d/x

# todo el estado que los hooks dejan dentro de un repo
grep -rhoE '\$(MEM|MEMDIR)"?/\.[a-z0-9._-]+' brain/hooks/*.sh brain/lib/*.sh | sed 's|.*/||' | sort -u
```
