#!/usr/bin/env python3
"""Mide el impuesto REAL de un evento: los hooks corren en PARALELO (verificado con los timestamps
de los transcripts), asi que el costo de pared es ~max(duraciones) + contencion de arrancar N
procesos bash a la vez, NO la suma. Compara: 1 hook solo · el grupo completo en paralelo · la suma.
"""
import json, os, subprocess, sys, time, statistics
from concurrent.futures import ThreadPoolExecutor

HOME = os.path.expanduser("~")
GH = f"{HOME}/.claude/hooks"

def pay(repo, event, tool, ti):
    d = {"session_id":"bench","transcript_path":"/dev/null","cwd":repo,
         "hook_event_name":event,"tool_name":tool,"tool_input":ti}
    if event=="PostToolUse": d["tool_response"]={"stdout":"x"}
    return json.dumps(d).encode()

def run_one(path, p):
    t=time.perf_counter()
    subprocess.run(["bash",path],input=p,capture_output=True,timeout=60)
    return (time.perf_counter()-t)*1000

def grupo(nombre, paths, p, n=15):
    paths=[x for x in paths if os.path.isfile(x)]
    solos=[]
    for path in paths:
        ts=[run_one(path,p) for _ in range(5)]
        solos.append(statistics.median(ts))
    par=[]
    for _ in range(n):
        t=time.perf_counter()
        with ThreadPoolExecutor(max_workers=len(paths)) as ex:
            list(ex.map(lambda x: run_one(x,p), paths))
        par.append((time.perf_counter()-t)*1000)
    par.sort()
    print(f"\n{nombre}")
    print(f"  procesos lanzados        : {len(paths)}")
    print(f"  suma en serie (hipotetica): {sum(solos):7.1f} ms")
    print(f"  el mas lento solo         : {max(solos):7.1f} ms   <- piso teorico si fuera paralelo perfecto")
    print(f"  PARALELO REAL medido      : {statistics.median(par):7.1f} ms  (min {par[0]:.1f} / max {par[-1]:.1f})")
    print(f"  sobrecosto por contencion : {statistics.median(par)-max(solos):7.1f} ms")
    return statistics.median(par)

repo = sys.argv[1] if len(sys.argv)>1 else os.getcwd()
RH=f"{repo}/.claude/hooks"
pb=pay(repo,"PreToolUse","Bash",{"command":"ls -la"})
po=pay(repo,"PostToolUse","Bash",{"command":"ls -la"})
pre = [f"{GH}/{h}.sh" for h in ["entorno-maquina-guard","no-bypass-deploy","git-branch-guard",
       "merge-squash-guard","confirmar-merge-develop","recordar-dashboard","secret-scan",
       "proteger-arbol","rama-vieja"]] + \
      [f"{RH}/{h}.sh" for h in ["git-branch-guard","merge-squash-guard","confirmar-merge-develop",
       "recordar-dashboard","secret-scan","entorno-maquina-guard","no-bypass-deploy"]]
post = [f"{GH}/{h}.sh" for h in ["recordar-orquestar","hud-stale","aviso-contexto","barrer-ramas"]] + [f"{RH}/hud-stale.sh"]
a=grupo("PreToolUse / Bash  (9 globales + 7 por-repo)", pre, pb)
b=grupo("PostToolUse / Bash (4 globales + 1 por-repo)", post, po)
print("\n" + "#"*72)
print(f"IMPUESTO DE PARED POR LLAMADA Bash (ruta silenciosa) = {a+b:.0f} ms")
print("#"*72)
