#!/usr/bin/env python3
"""Cuenta llamadas de herramienta por sesion (para multiplicar por el impuesto silencioso medido)
y suma el tiempo de hooks REGISTRADO (el que hablo) por sesion. Streaming, nunca carga el archivo."""
import json, os, glob, collections, sys, re
TAX_BASH = 60.0   # ms de pared medidos (PreToolUse+PostToolUse en paralelo, ruta silenciosa)
TAX_OTRO = 35.0   # ms: sin los 9+7 de matcher=Bash, solo el grupo PostToolUse sin matcher
rows=[]
for f in sorted(glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl"))):
    tools=collections.Counter(); hooksum=0.0; hookn=0
    for line in open(f,errors="replace"):
        if '"tool_use"' in line:
            for m in re.finditer(r'"type":"tool_use","id":"[^"]*","name":"([A-Za-z_]+)"', line):
                tools[m.group(1)]+=1
        if '"hook_' in line:
            try: r=json.loads(line)
            except: continue
            a=r.get("attachment")
            if isinstance(a,dict) and isinstance(a.get("durationMs"),int):
                hooksum+=a["durationMs"]; hookn+=1
    tot=sum(tools.values())
    if tot==0 and hookn==0: continue
    b=tools.get("Bash",0)
    silencioso=(b*TAX_BASH + (tot-b)*TAX_OTRO)/1000
    rows.append((os.path.basename(f)[:8], os.path.basename(os.path.dirname(f))[:34], tot, b, silencioso, hooksum/1000, hookn))
rows.sort(key=lambda r:-(r[4]+r[5]))
print(f"{'sesion':<10}{'proyecto':<36}{'tools':>7}{'Bash':>7}{'silenc.(s)':>12}{'registrado(s)':>14}{'n':>6}")
print("-"*92)
for r in rows[:18]: print(f"{r[0]:<10}{r[1]:<36}{r[2]:>7}{r[3]:>7}{r[4]:>12.0f}{r[5]:>14.0f}{r[6]:>6}")
print("-"*92)
print(f"{'TOTAL':<46}{sum(r[2] for r in rows):>7}{sum(r[3] for r in rows):>7}{sum(r[4] for r in rows):>12.0f}{sum(r[5] for r in rows):>14.0f}{sum(r[6] for r in rows):>6}")
print(f"\nGRAN TOTAL de tiempo de hooks en el corpus: {(sum(r[4] for r in rows)+sum(r[5] for r in rows))/3600:.2f} horas")
print(f"  de eso, ruta silenciosa (inevitable hoy): {sum(r[4] for r in rows)/3600:.2f} h")
print(f"  de eso, hooks que HABLARON (registrado) : {sum(r[5] for r in rows)/3600:.2f} h")
