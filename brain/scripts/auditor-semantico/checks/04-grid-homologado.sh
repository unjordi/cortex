#!/usr/bin/env bash
# 04-grid-homologado.sh
#
# Hallazgo que lo originó: auditoría de MegaFlux (2026-07-15) — `FlotaEnOperacionPage.razor`
# ligaba `<MudTable Items="Filtradas">` a una PROPIEDAD calculada (`Filtradas => _todos.Where(...)`),
# no a un campo materializado. MudTable evalúa `Items` una vez POR FILA — así, el filtrado
# LINQ se recalculaba en cada fila renderizada (antipatrón O(n²) que AGENTS.md §13.11 pide
# evitar explícitamente). En el mismo commit, otra página (`CentrosTrabajoPage.razor`) sí
# usaba el patrón correcto — la inconsistencia pasó sin que ningún test la atrapara (un test
# unitario no renderiza suficientes filas para notar el costo).
#
# Qué verifica: toda página `.razor` con `<MudTable Items="Xxx"` debe ligar Xxx a un CAMPO
# materializado (Xxx es, por definición, un dato ya calculado si no hay una propiedad `=>`
# con su nombre — un campo NUNCA se recomputa por sí solo) o, si Xxx es una propiedad
# `=>` (posiblemente en varias líneas), su cuerpo NO debe traer operadores LINQ
# (`.Where(`, `.OrderBy(`, `.Select(`, `.Filtrar(`, etc.) — eso sí se recalcula en cada
# acceso, es decir, por fila.
#
# Nota de diseño (2026-07-15, tras correr esto contra MegaFlux): la primera versión de este
# check exigía encontrar la declaración en una sola línea y, si no la hallaba, lo marcaba
# como "no se pudo verificar" — eso generó 9 falsos "inciertos" contra código sano (campos
# planos `private List<T> _x = [];`, que NUNCA tienen un `=>` porque son datos, no getters) y
# además se comió el propio bug real (`Filtradas =>` con el `.Where(...)` en la línea
# SIGUIENTE, no en la misma). Ahora: sin declaración `=>` en el archivo = campo plano = OK
# (nada que reportar); con declaración `=>`, se acumula el cuerpo hasta el primer `;` sin
# importar cuántas líneas ocupe.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib-formato.sh"

hallazgos=0
out=/tmp/auditor-semantico-04.out
: > "$out"

paginas=$(find . -type d -iname "Pages" 2>/dev/null | grep -iE "blazorwasm|blazor")

for dir in $paginas; do
	[ -d "$dir" ] || continue
	while IFS= read -r archivo; do
		props=$(grep -noE '<MudTable[^>]*\bItems="@?([A-Za-z_][A-Za-z0-9_]*)"' "$archivo" \
			| sed -E 's/.*Items="@?([A-Za-z_][A-Za-z0-9_]*)".*/\1/')
		[ -z "$props" ] && continue

		while IFS= read -r prop; do
			[ -z "$prop" ] && continue
			# ¿hay una propiedad "prop =>" en el archivo? Si NO, es un campo plano (materializado
			# por definición — un campo nunca se recomputa solo) y no hay nada que reportar.
			linea=$(grep -nE "\b${prop}\b[ \t]*=>" "$archivo" | head -1 | cut -d: -f1)
			[ -z "$linea" ] && continue

			# acumula el cuerpo desde la línea de la declaración hasta la primera que traiga ";"
			# (el cuerpo de una propiedad expression-bodied puede ocupar varias líneas).
			cuerpo=$(awk -v inicio="$linea" 'NR>=inicio { c = c " " $0; if ($0 ~ /;/) { print c; exit } }' "$archivo")

			if echo "$cuerpo" | grep -qE '\.(Where|OrderBy|OrderByDescending|Select|Filtrar|Take|Skip)\('; then
				echo "${archivo}:${linea}: \"${prop}\" se calcula con LINQ directo en el getter (recomputado por MudTable EN CADA FILA — antipatrón O(n²), ver AGENTS.md §13.11). Debe ser un passthrough a un campo materializado (\"${prop} => _${prop,,};\") recalculado solo al cambiar filtros/datos. ${SUFIJO_REVISAR_CAPA2}" >> "$out"
			fi
		done <<< "$props"
	done < <(find "$dir" -name "*.razor" -print)
done

hallazgos=$(wc -l < "$out" | tr -d ' ')
if [ "$hallazgos" -gt 0 ]; then
	cat "$out"
fi
rm -f "$out"

reportar_candidatos "$hallazgos"
exit $?
