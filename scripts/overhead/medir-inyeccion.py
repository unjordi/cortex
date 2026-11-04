#!/usr/bin/env python3
"""Mide el texto que los hooks INYECTAN en la ventana (additionalContext / systemMessage).

Es INVERSION DELIBERADA, no grasa: inyectar cuesta una vez; NO inyectar cuesta cada vez que el
modelo va a buscarlo (Reads, greps, turnos de mas). Se mide como DATO para entender el arranque.
Lo unico reportable como defecto es el mismo contenido inyectado DOS veces, o contenido stale.
"""
import json, os, glob, collections, re, sys
CH_PER_TOK = 4.0   # aprox. conservadora para texto en espanol
por_hook=collections.defaultdict(list)
por_sesion=collections.defaultdict(lambda: collections.Counter())
textos=collections.defaultdict(list)
for f in sorted(glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl"))):
    for line in open(f,errors="replace"):
        if '"hook_' not in line: continue
        try: r=json.loads(line)
        except: continue
        a=r.get("attachment")
        if not isinstance(a,dict): continue
        out=a.get("stdout") or ""
        if not out.strip(): continue
        try: j=json.loads(out)
        except: continue
        ctx=(j.get("hookSpecificOutput") or {}).get("additionalContext") or j.get("systemMessage") or ""
        if not ctx: continue
        m=re.search(r'/hooks/([a-z0-9-]+)\.sh',a.get("command") or "")
        n=m.group(1) if m else {"Cerebro: rehidratando estado del proyecto":"sesion-inicio",
                                "DoD: verificando evidencia antes de cerrar":"dod-verificar"}.get(a.get("command"),a.get("command") or "?")
        por_hook[n].append(len(ctx))
        por_sesion[(f,a.get("toolUseID"))][n]+=len(ctx)
        if len(textos[n])<3: textos[n].append(ctx)
print("TEXTO INYECTADO POR HOOK  —  INVERSION DELIBERADA (no es overhead, no se recorta)")
print(f"{'hook':<26}{'inyecciones':>12}{'mediana KB':>12}{'max KB':>9}{'~tokens med':>13}")
print("-"*74)
tot=0
for n,v in sorted(por_hook.items(),key=lambda kv:-sorted(kv[1])[len(kv[1])//2]):
    v2=sorted(v); med=v2[len(v2)//2]; tot+=sum(v)
    print(f"{n:<26}{len(v):>12}{med/1024:>12.1f}{max(v)/1024:>9.1f}{int(med/CH_PER_TOK):>13}")
print("-"*74)
print(f"total inyectado en todo el corpus: {tot/1048576:.1f} MB  (~{int(tot/CH_PER_TOK/1000)} k tokens acumulados)")
# arranque tipico: suma por grupo SessionStart
ss=[sum(c.values()) for k,c in por_sesion.items() if len(c)>1]
if ss:
    ss.sort(); print(f"\nbloque de un ARRANQUE completo (varios hooks juntos): mediana {ss[len(ss)//2]/1024:.1f} KB · max {ss[-1]/1024:.1f} KB")
print("\n=== DUPLICACION: mismo contenido por DOS hooks en el MISMO disparo ===")
dup=0
for k,c in por_sesion.items():
    if len(c)>1: dup+=1
print(f"  disparos donde >1 hook inyecto a la vez: {dup}")
# solape textual real entre hooks
import itertools
firmas={n:set(re.findall(r'[A-Za-zÀ-ÿ]{6,}', " ".join(t[:1]))) for n,t in textos.items() if t}
for a,b in itertools.combinations(sorted(firmas),2):
    A,B=firmas[a],firmas[b]
    if not A or not B: continue
    j=len(A&B)/len(A|B)
    if j>0.25: print(f"  solape lexico {j:.0%}  {a} <-> {b}")
