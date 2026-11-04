#!/usr/bin/env python3
"""dot2drawio.py — convierte un .dot de Graphviz a un .drawio editable en draw.io, PRESERVANDO layout y estilo.

Toma lo que `dot -Tjson` ya calculó (posiciones, tamaños, estilos, rutas de las aristas) y escribe mxGraph XML:
un vértice por nodo (forma/relleno/borde/etiqueta/color de texto), un contenedor por cada `cluster_*` con sus
nodos adentro (moverlo arrastra a sus hijos; un nodo va en el cluster más chico que lo contiene) y una arista por
edge con los puntos de la ruta de Graphviz. El resultado abre en draw.io YA ACOMODADO.

Uso:  python3 bin/dot2drawio.py docs/mapa-flujos.dot docs/mapa-flujos.drawio
Requiere: graphviz (`dot`) en el PATH. Gemelo de dot2yed.py (yEd). Parte del skill `diagramar`.
"""
import html, json, re, subprocess, sys


def die(m):
    sys.stderr.write(m + "\n")
    sys.exit(1)


def run_dot_json(dot_path):
    try:
        out = subprocess.run(["dot", "-Tjson", dot_path], capture_output=True, text=True, check=True)
    except FileNotFoundError:
        die("No encuentro `dot` (graphviz) en el PATH.")
    except subprocess.CalledProcessError as e:
        die("dot falló:\n" + e.stderr)
    return json.loads(out.stdout)


def attr(s):
    return html.escape(s, quote=True)


def etiqueta(raw):
    """Label de dot (con \\l / \\n) → HTML de draw.io con <br> y alineación."""
    raw = raw or ""
    if raw == "\\N":
        raw = ""
    if raw.lstrip().startswith("<"):  # etiqueta HTML de dot (label=<...>): draw.io la pinta tal cual con html=1
        return raw, "center"
    izq = "\\l" in raw
    lineas = re.split(r"\\[lnr]", raw)
    if lineas and lineas[-1] == "":
        lineas = lineas[:-1]
    return "<br>".join(html.escape(x) for x in lineas), ("left" if izq else "center")


def forma(shape, style):
    if shape == "diamond":
        return "rhombus;"
    if shape in ("ellipse", "oval", "circle"):
        return "ellipse;"
    if shape == "note":
        return "shape=note;size=12;"
    if shape in ("cylinder",):
        return "shape=cylinder3;boundedLbl=1;"
    redondo = "rounded" in (style or "") or shape not in ("box", "rect", "rectangle", "square")
    return "rounded=1;arcSize=12;" if redondo else "rounded=0;"


def estilo_comun(o, defecto_borde):
    s = ""
    st = o.get("style", "") or ""
    if "dashed" in st:
        s += "dashed=1;"
    if "dotted" in st:
        s += "dashed=1;dashPattern=1 3;"
    s += f"strokeColor={o.get('color', defecto_borde)};"
    s += f"strokeWidth={o.get('penwidth', '1')};"
    s += f"fontColor={o.get('fontcolor', '#000000')};"
    s += f"fontFamily={o.get('fontname', 'Helvetica')};"
    s += f"fontSize={str(o.get('fontsize', '12')).split('.')[0]};"
    return s


def main():
    if len(sys.argv) != 3:
        die("Uso: python3 bin/dot2drawio.py <entrada.dot> <salida.drawio>")
    dot_path, out_path = sys.argv[1], sys.argv[2]
    d = run_dot_json(dot_path)
    H = float(d["bb"].split(",")[3])
    objs = d.get("objects", [])
    por_gvid = {o["_gvid"]: o for o in objs}

    clusters = [o for o in objs if str(o.get("name", "")).startswith("cluster") and "bb" in o]

    def caja(c):  # bb de Graphviz → (x, y, w, h) con Y hacia abajo
        x0, y0, x1, y1 = map(float, c["bb"].split(","))
        return x0, H - y1, x1 - x0, y1 - y0

    area = {c["_gvid"]: caja(c)[2] * caja(c)[3] for c in clusters}
    # cluster más chico que contiene a cada nodo y a cada cluster (anidamiento)
    dueno_nodo = {}
    for c in sorted(clusters, key=lambda c: -area[c["_gvid"]]):
        for gv in c.get("nodes", []):
            dueno_nodo[gv] = c["_gvid"]
    padre_cluster = {}
    for c in clusters:
        cx, cy, cw, ch = caja(c)
        mejor = None
        for p in clusters:
            if p is c or area[p["_gvid"]] <= area[c["_gvid"]]:
                continue
            px, py, pw, ph = caja(p)
            if px <= cx and py <= cy and cx + cw <= px + pw and cy + ch <= py + ph:
                if mejor is None or area[p["_gvid"]] < area[mejor]:
                    mejor = p["_gvid"]
        padre_cluster[c["_gvid"]] = mejor
    origen = {}  # esquina absoluta de cada contenedor

    def cid(gv):
        return f"n{gv}"

    celdas = []
    pendientes = list(clusters)
    hechos = set()
    while pendientes:  # padres antes que hijos
        for c in list(pendientes):
            p = padre_cluster[c["_gvid"]]
            if p is not None and p not in hechos:
                continue
            x, y, w, h = caja(c)
            origen[c["_gvid"]] = (x, y)
            px, py = origen.get(p, (0, 0)) if p is not None else (0, 0)
            texto, _ = etiqueta(c.get("label", ""))
            relleno = c.get("fillcolor", "none") if "filled" in (c.get("style", "") or "") else "none"
            st = ("rounded=1;arcSize=4;container=1;collapsible=0;pointerEvents=0;html=1;whiteSpace=wrap;"
                  "verticalAlign=top;align=left;spacingLeft=8;fontStyle=1;"
                  f"fillColor={relleno};" + estilo_comun(c, "#8A8A8A"))
            celdas.append(f'<mxCell id="{cid(c["_gvid"])}" value="{attr(texto)}" style="{st}" vertex="1" '
                          f'parent="{cid(p) if p is not None else 1}"><mxGeometry x="{x - px:.1f}" y="{y - py:.1f}" '
                          f'width="{w:.1f}" height="{h:.1f}" as="geometry"/></mxCell>')
            hechos.add(c["_gvid"])
            pendientes.remove(c)

    n_nodos = 0
    for o in objs:
        if str(o.get("name", "")).startswith("cluster") or "pos" not in o:
            continue
        cx, cy = map(float, o["pos"].split(","))
        w = float(o.get("width", 1)) * 72.0
        h = float(o.get("height", 0.5)) * 72.0
        x, y = cx - w / 2.0, H - cy - h / 2.0
        dueno = dueno_nodo.get(o["_gvid"])
        px, py = origen.get(dueno, (0, 0)) if dueno is not None else (0, 0)
        texto, al = etiqueta(o.get("label", o.get("name", "")))
        relleno = o.get("fillcolor", "#FFFFFF") if "filled" in (o.get("style", "") or "") or "fillcolor" in o else "#FFFFFF"
        st = (forma(o.get("shape", "box"), o.get("style", "")) + "whiteSpace=wrap;html=1;"
              f"align={al};fillColor={relleno};" + estilo_comun(o, "#000000"))
        celdas.append(f'<mxCell id="{cid(o["_gvid"])}" value="{attr(texto)}" style="{st}" vertex="1" '
                      f'parent="{cid(dueno) if dueno is not None else 1}"><mxGeometry x="{x - px:.1f}" '
                      f'y="{y - py:.1f}" width="{w:.1f}" height="{h:.1f}" as="geometry"/></mxCell>')
        n_nodos += 1

    aristas = d.get("edges", [])
    for i, e in enumerate(aristas):
        if e.get("tail") not in por_gvid or e.get("head") not in por_gvid:
            continue
        texto, _ = etiqueta(e.get("label", ""))
        st = ("edgeStyle=none;rounded=1;html=1;endArrow=block;endFill=1;"
              + estilo_comun(e, "#555555"))
        if "dir" in e and e["dir"] == "none":
            st += "endArrow=none;"
        puntos = ""
        pos = e.get("pos", "")
        if pos:
            coords = [c for c in pos.split() if not c.startswith(("e,", "s,"))]
            pts = [tuple(map(float, c.split(","))) for c in coords]
            intermedios = pts[3:-1:3]  # extremos de cada tramo Bézier, sin el primero ni el último
            if intermedios:
                puntos = "<Array as=\"points\">" + "".join(
                    f'<mxPoint x="{px:.1f}" y="{H - py:.1f}"/>' for px, py in intermedios) + "</Array>"
        celdas.append(f'<mxCell id="e{i}" value="{attr(texto)}" style="{st}" edge="1" parent="1" '
                      f'source="{cid(e["tail"])}" target="{cid(e["head"])}"><mxGeometry relative="1" '
                      f'as="geometry">{puntos}</mxGeometry></mxCell>')

    xml = ('<mxfile><diagram name="Página-1"><mxGraphModel adaptiveColors="auto"><root><mxCell id="0"/>'
           '<mxCell id="1" parent="0"/>' + "".join(celdas) + "</root></mxGraphModel></diagram></mxfile>")
    open(out_path, "w", encoding="utf-8").write(xml)
    sys.stderr.write(f"OK → {out_path}  ({n_nodos} nodos, {len(clusters)} grupos, {len(aristas)} aristas)\n")


if __name__ == "__main__":
    main()
