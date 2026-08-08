#!/usr/bin/env bash
# 03-dapper-dateonly-handler.sh
#
# Hallazgo que lo originó: gotcha real en varios proyectos derivados de la plantilla —
# `Microsoft.Data.SqlClient` devuelve columnas SQL `date`/`time` como `DateTime`, y Dapper
# no sabe convertirlas al `DateOnly`/`TimeOnly` de un DTO record sin un `SqlMapper.TypeHandler`
# registrado. Los tests de aplicación (repos mockeados) pasan sin problema — el 500 solo
# aparece contra SQL Server real, así que sobrevive hasta el smoke E2E si nadie lo checa antes.
#
# Qué verifica: si existe algún tipo `DateOnly`/`TimeOnly` en Shared/Domain (candidato a
# viajar por un DTO leído con Dapper), debe existir un `SqlMapper.AddTypeHandler` (o una clase
# `ManejadorDapper*`) para ESE tipo, registrado en la capa de infraestructura.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib-formato.sh"

hallazgos=0
out=/tmp/auditor-semantico-03.out
: > "$out"

shared_domain_dirs=$(find . -maxdepth 1 -type d \( -iname "*.shared" -o -iname "*.domain" \) 2>/dev/null)
infra_dirs=$(find . -maxdepth 1 -type d -iname "*.infrastructure" 2>/dev/null)

for tipo in DateOnly TimeOnly; do
	usa_tipo=0
	for dir in $shared_domain_dirs; do
		[ -d "$dir" ] || continue
		if grep -rlqE "\b${tipo}\??\b" --include="*.cs" "$dir" 2>/dev/null; then
			usa_tipo=1
		fi
	done
	[ "$usa_tipo" -eq 0 ] && continue

	tiene_handler=0
	for dir in $infra_dirs; do
		[ -d "$dir" ] || continue
		if grep -rlqE "AddTypeHandler.*${tipo}|ManejadorDapper${tipo}" --include="*.cs" "$dir" 2>/dev/null; then
			tiene_handler=1
		fi
	done

	if [ "$tiene_handler" -eq 0 ]; then
		echo "El proyecto usa ${tipo} en Shared/Domain pero no se encontró un SqlMapper.AddTypeHandler<${tipo}> (o clase ManejadorDapper${tipo}) registrado en *.infrastructure — sospechoso #1 de 500 al listar contra SQL Server real (los tests con repos mockeados no lo atrapan). ${SUFIJO_REVISAR_CAPA2}" >> "$out"
	fi
done

hallazgos=$(wc -l < "$out" | tr -d ' ')
if [ "$hallazgos" -gt 0 ]; then
	cat "$out"
fi
rm -f "$out"

reportar_candidatos "$hallazgos"
exit $?
