#!/usr/bin/env python3
"""Cronometra cada hook CABLEADO como lo invoca el harness: JSON por stdin, HOME real, repo real.

Mide la RUTA SILENCIOSA (payload benigno) — la que corre en >99% de las llamadas y que la
telemetria de los transcripts NO registra (esa solo guarda los hooks que HABLAN).

OJO metodologico: cronometrar desde bash llamando `python3`/`date` por iteracion mete ~20 ms de
ruido propio y triplica la lectura. Se mide desde un solo proceso Python con time.perf_counter.
"""
import json, os, subprocess, sys, time, statistics

HOME = os.path.expanduser("~")
GH = f"{HOME}/.claude/hooks"

def payload(repo, event, tool, extra=None):
    d = {"session_id": "bench", "transcript_path": "/dev/null", "cwd": repo,
         "hook_event_name": event, "tool_name": tool, "tool_input": extra or {}}
    if event == "PostToolUse":
        d["tool_response"] = {"stdout": "x"}
    return json.dumps(d).encode()

def bench(path, pay, n=25):
    if not os.path.isfile(path):
        return None
    ts = []
    for _ in range(n):
        t = time.perf_counter()
        try:
            subprocess.run(["bash", path], input=pay, capture_output=True, timeout=30)
        except subprocess.TimeoutExpired:
            ts.append(30000.0); continue
        ts.append((time.perf_counter() - t) * 1000)
    ts.sort()
    return (statistics.mean(ts), ts[0], ts[len(ts)//2], ts[-1])

def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 25
    RH = f"{repo}/.claude/hooks"
    pb = payload(repo, "PreToolUse", "Bash", {"command": "ls -la"})
    pe = payload(repo, "PreToolUse", "Edit", {"file_path": f"{repo}/README.md", "old_string": "a", "new_string": "b"})
    pt = payload(repo, "PreToolUse", "Task", {"subagent_type": "Explore", "prompt": "x"})
    po = payload(repo, "PostToolUse", "Bash", {"command": "ls -la"})

    grupos = [
      ("GLOBAL · PreToolUse matcher=Bash  (corre en CADA Bash)", [
        (h, f"{GH}/{h}.sh", pb) for h in
        ["entorno-maquina-guard","no-bypass-deploy","git-branch-guard","merge-squash-guard",
         "confirmar-merge-develop","recordar-dashboard","secret-scan","proteger-arbol","rama-vieja"]]),
      ("GLOBAL · PreToolUse matcher=Edit|Write", [("proteger-fuente-cerebro", f"{GH}/proteger-fuente-cerebro.sh", pe)]),
      ("GLOBAL · PreToolUse matcher=Task|Agent", [(h, f"{GH}/{h}.sh", pt) for h in ["limite-gasto","delegacion-gate"]]),
      ("GLOBAL · PostToolUse", [(h, f"{GH}/{h}.sh", po) for h in ["recordar-orquestar","hud-stale","aviso-contexto","barrer-ramas"]]),
      ("POR-REPO · PreToolUse matcher=Bash  (copia que solo hace dedupe y sale)", [
        (f"repo/{h}", f"{RH}/{h}.sh", pb) for h in
        ["git-branch-guard","merge-squash-guard","confirmar-merge-develop","recordar-dashboard",
         "secret-scan","entorno-maquina-guard","no-bypass-deploy"]]),
      ("POR-REPO · PostToolUse", [("repo/hud-stale", f"{RH}/hud-stale.sh", po)]),
    ]
    print(f"repo={repo}  n={n}  (ms)")
    tot_pre_bash = tot_post_bash = 0.0
    for titulo, items in grupos:
        print("\n" + "=" * 78); print(titulo); print("=" * 78)
        print(f"{'hook':<32}{'media':>8}{'min':>8}{'p50':>8}{'max':>8}")
        sub = 0.0
        for nom, path, pay in items:
            r = bench(path, pay, n)
            if r is None:
                print(f"{nom:<32}{'NO-INSTALADO':>32}"); continue
            m, lo, p50, hi = r; sub += m
            print(f"{nom:<32}{m:>8.1f}{lo:>8.1f}{p50:>8.1f}{hi:>8.1f}")
        print(f"{'  SUBTOTAL (serie)':<32}{sub:>8.1f}")
        if "PreToolUse matcher=Bash" in titulo: tot_pre_bash += sub
        if "PostToolUse" in titulo: tot_post_bash += sub
    print("\n" + "#" * 78)
    print(f"IMPUESTO POR LLAMADA Bash (si SERIE): Pre {tot_pre_bash:.0f} ms + Post {tot_post_bash:.0f} ms"
          f" = {tot_pre_bash + tot_post_bash:.0f} ms")
    print("#" * 78)

main()
