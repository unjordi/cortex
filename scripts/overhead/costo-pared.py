#!/usr/bin/env python3
"""Costo de PARED honesto de los hooks, con corte temporal.

Dos correcciones metodologicas que cambian el resultado:
 1. Los hooks de un mismo evento corren en PARALELO (verificado: en un grupo, las diferencias entre
    timestamps de fin coinciden exactamente con las diferencias de durationMs -> arrancaron juntos).
    El costo real de un disparo es el MAXIMO del grupo, no la suma.
 2. La telemetria arrastra REGRESIONES YA ARREGLADAS. Con --desde se acota a la era vigente para
    describir el harness de HOY y no el de hace dos meses.

Uso: costo-pared.py [--desde YYYY-MM-DD]
"""
import json, os, glob, collections, re, sys

desde = None
if "--desde" in sys.argv: desde = sys.argv[sys.argv.index("--desde")+1]

GRUP=collections.defaultdict(list)
for f in sorted(glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl"))):
    for line in open(f,errors="replace"):
        if '"hook_' not in line: continue
        try: r=json.loads(line)
        except: continue
        a=r.get("attachment")
        if not isinstance(a,dict) or not isinstance(a.get("durationMs"),int): continue
        ts=(r.get("timestamp") or "")[:10]
        if desde and ts < desde: continue
        GRUP[(f,a.get("toolUseID") or id(line), a.get("hookEvent"))].append(a)

def nom(c):
    m=re.search(r'/hooks/([a-z0-9-]+)\.sh',c or "")
    if m: return m.group(1)
    return {"Cerebro: rehidratando estado del proyecto":"sesion-inicio",
            "DoD: verificando evidencia antes de cerrar":"dod-verificar",
            "Guard: confirmar antes de integrar a develop":"confirmar-merge-develop"}.get(c,c or "?")

pared=collections.Counter(); dom=collections.Counter(); vistas=collections.Counter()
tout=collections.Counter(); peor=collections.defaultdict(int); porev=collections.Counter()
for (f,tid,ev),hs in GRUP.items():
    top=max(hs,key=lambda a:a["durationMs"])
    pared[nom(top.get("command"))]+=top["durationMs"]; dom[nom(top.get("command"))]+=1
    porev[ev]+=top["durationMs"]
    for a in hs:
        n=nom(a.get("command")); vistas[n]+=1
        peor[n]=max(peor[n],a["durationMs"])
        if a.get("type")=="hook_cancelled": tout[n]+=1
tot=sum(pared.values()) or 1
print(f"VENTANA: {'desde '+desde if desde else 'todo el corpus'}   |  disparos de evento registrados: {len(GRUP)}")
print(f"{'hook':<26}{'apariciones':>12}{'dominó':>8}{'pared(s)':>10}{'%':>7}{'peor(ms)':>10}{'timeouts':>10}")
print("-"*84)
for h,ms in pared.most_common():
    print(f"{h:<26}{vistas[h]:>12}{dom[h]:>8}{ms/1000:>10.1f}{100*ms/tot:>6.1f}%{peor[h]:>10}{tout[h]:>10}")
print("-"*84)
print(f"{'TOTAL':<26}{'':>12}{'':>8}{tot/1000:>10.1f}   = {tot/3600000:.2f} h")
print("\nPor evento:"); 
for e,ms in porev.most_common(): print(f"  {e:<14}{ms/1000:>9.1f} s  ({100*ms/tot:.1f}%)")
