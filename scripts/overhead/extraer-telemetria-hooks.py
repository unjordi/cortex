#!/usr/bin/env python3
"""Extrae la telemetria de ejecucion de hooks de los transcripts .jsonl de Claude Code.

Lee en STREAMING (linea a linea, sin cargar el archivo) y emite un TSV con una fila por
ejecucion de hook. Los transcripts pesan cientos de MB: nunca los cargues enteros.

Salida (TSV):  archivo  sesion  tipo  hookEvent  hookName  command  durationMs  timedOut  timeoutMs
"""
import json, os, sys

HOOK_TYPES = {"hook_success", "hook_non_blocking_error",
              "hook_error_during_execution", "hook_cancelled", "hook_blocking_error"}

def main(roots):
    out = sys.stdout
    out.write("archivo\tsesion\ttipo\thookEvent\thookName\tcommand\tdurationMs\ttimedOut\ttimeoutMs\n")
    files = []
    for root in roots:
        for dirpath, _, names in os.walk(root):
            for n in names:
                if n.endswith(".jsonl"):
                    files.append(os.path.join(dirpath, n))
    nfiles = 0
    for path in sorted(files):
        nfiles += 1
        base = os.path.basename(path)
        sesion = base[:-6]
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    # descarte BARATO antes de parsear: la inmensa mayoria de lineas no son hooks
                    if '"hook_' not in line:
                        continue
                    try:
                        rec = json.loads(line)
                    except Exception:
                        continue
                    att = rec.get("attachment")
                    if not isinstance(att, dict):
                        continue
                    t = att.get("type")
                    if t not in HOOK_TYPES:
                        continue
                    out.write("\t".join(str(x) for x in (
                        path, sesion, t,
                        att.get("hookEvent", ""),
                        str(att.get("hookName", "")).replace("\t", " "),
                        str(att.get("command", "")).replace("\t", " ").replace("\n", " "),
                        att.get("durationMs", ""),
                        att.get("timedOut", ""),
                        att.get("timeoutMs", ""),
                    )) + "\n")
        except Exception as e:
            print(f"# ERROR {path}: {e}", file=sys.stderr)
    print(f"# archivos procesados: {nfiles}", file=sys.stderr)

if __name__ == "__main__":
    main(sys.argv[1:] or [os.path.expanduser("~/.claude/projects")])
