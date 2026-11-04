# Propuesta: guard de datos personales (contenido de máquina en git)

De: claudio-master · 2026-10-07 · unjordi lo ubicó en cortex ("es no es de heimdall o dotnet sino de cortex").

## Hueco
La norma dura "El entorno de MÁQUINA vive GLOBAL, jamás en un repo" solo tiene mecanismo por NOMBRE de
archivo (`entorno-maquina-guard` avisa de un `entorno-maquina.md` en el `.claude/memory/` de un repo).
Nada revisa el CONTENIDO: rutas de un `$HOME`, IPs de una LAN, usuarios, nombres de disco. `secret-scan`
solo caza llaves/tokens.

## Evidencia
`heimdall-net/docker-compose.samba.yml:43` monta `/run/media/unjordi/SteamAndFiles:/tank:ro` (el disco
de Steam de la cachy) en el compose del producto; pasó por git sin que nada lo frenara.

## Prior art (ya probado)
`~/code/nas-a-demanda/scripts/verificar-sin-datos-personales.sh` (Carlitos, repo público AliazCIA/nas-a-demanda):
pre-commit con dos capas:
1. Reglas GENERALES en el repo: rutas/archivos que nunca van a git (`.env`, `appdata/`, BDs, llaves, respaldos).
2. Patrones PERSONALES en `privado/patrones-personales.txt`, una regex por renglón, que vive SOLO en la
   máquina del dueño (la lista misma es dato personal). Sin el archivo, la capa se omite.
Modos: árbol completo, `--staged` (pre-commit), `--instalar`.

## Encaje sugerido [INFER-mío, decide cortex-master]
Guard `both` junto a `secret-scan` (mismo punto: commit/push, solo lo agregado), con la capa personal
leída de un archivo per-máquina fuera de git (p. ej. junto a la memoria global), sembrable por el bootstrap
desde lo que ya sabe de la máquina (usuario, hostname, rutas de `$HOME`, IPs de la LAN/WG).
