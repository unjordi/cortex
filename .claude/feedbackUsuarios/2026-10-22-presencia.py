import subprocess,sys,os
R=os.path.expanduser('~/code/cortex')
def g(*a,cwd=R):return subprocess.run(['git',*a],cwd=cwd,capture_output=True,text=True).stdout
cat=subprocess.Popen(['git','cat-file','--batch'],cwd=R,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
def blob(spec):
    cat.stdin.write((spec+'\n').encode());cat.stdin.flush()
    h=cat.stdout.readline().decode().split()
    if len(h)<3 or h[1]=='missing':return ''
    d=cat.stdout.read(int(h[2]));cat.stdout.read(1);return d.decode('utf8','replace')
def added(diff):
    out={};f=None
    for l in diff.splitlines():
        if l.startswith('+++ '):f=l[6:] if l.startswith('+++ b/') else None;continue
        if f and l.startswith('+') :
            s=l[1:].strip()
            if len(s)>=12:out.setdefault(f,set()).add(s)
    return out
def commits(base):
    c=g('log','--first-parent','--format=%h %ad %s','--date=short',f'{base}..origin/develop').splitlines()
    c+=g('log','--format=%h %ad %s','--date=short','origin/develop..fix/corpus-fp-bench').splitlines()[:1]
    return [x for x in c if x]
def measure(name,diff,base):
    a=added(diff);tot=sum(len(v) for v in a.values())
    if not tot:print(f'{name}: sin líneas añadidas');return
    best=(0,'');cache={}
    for c in commits(base):
        h=c.split()[0];hit=0
        for f,ls in a.items():
            t=blob(f'{h}:{f}')
            hit+=sum(1 for l in ls if l in t)
        if hit>best[0]:best=(hit,c)
    print(f'{name}: máx {best[0]}/{tot} ({best[0]*100//tot}%) en {best[1][:110]}')
for spec in sys.argv[1:]:
    if spec.startswith('WT:'):
        wt=spec[3:];base=g('rev-parse','HEAD',cwd=wt).strip()
        d=g('diff','HEAD',cwd=wt)
        for u in g('ls-files','--others','--exclude-standard',cwd=wt).split():
            d+=f'\n+++ b/{u}\n'+''.join('+'+x+'\n' for x in open(os.path.join(wt,u),errors='replace').read().splitlines())
        measure('sucio '+os.path.basename(wt),d,base)
    else:
        mb=g('merge-base','origin/develop',spec).strip()
        measure(spec,g('diff',mb,spec),mb)
