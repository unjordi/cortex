// Pestaña 5 · Cerebro — port de "Tab 5" + BrainHealth/BrainTier de main.qml. La ESTRUCTURA (tiers,
// piezas, textos) se lee del catálogo del plasmoide (lib/catalogo-cerebro.js); el ESTADO de cada pieza
// sale de ~/.claude vía brain-scan.sh. Curita 🩹 = brain-scan.sh heal; ⬆ = re-instalar desde el clon.
import St from 'gi://St';
import Gio from 'gi://Gio';
import Clutter from 'gi://Clutter';
import Pango from 'gi://Pango';

import * as F from '../lib/fmt.js';
import * as W from '../lib/widgets.js';
import * as K from '../lib/catalogo-cerebro.js';
import * as C from '../lib/cerebro.js';

const GREEN = '#3aa76d';
const MAP_URL = 'https://github.com/unjordi/cortex/blob/main/docs/mapa-cerebro.md';
const SMALL = 'font-size: 0.85em;';

// Primera lectura al cargar la extensión (como el Component.onCompleted del QML): así el badge 🩹/⬆
// del panel aparece sin haber abierto antes la pestaña.
function boot(ctx) {
    const s = C.initState(ctx.state);
    if (!s.booted) {
        s.booted = true;
        C.scan(ctx);
        C.checkUpdate(ctx);
    }
    return s;
}

// Al entrar a la pestaña: re-lee ~/.claude y chequea versión (throttle 15 min) — onCurrentTabChanged del QML.
export function onShow(ctx) {
    const s = C.initState(ctx.state);
    s.booted = true;
    C.scan(ctx);
    C.checkUpdate(ctx);
}

export function panelBadge(ctx) {
    const s = boot(ctx);
    return [C.healthOf(ctx).incomplete ? '🩹' : '', s.upd.available ? '⬆' : ''].filter(Boolean).join(' ');
}

// Pie del riel: ⬆ y 🩹 SOLO cuando aplican (mismo orden que el plasmoide: ⬆ primero).
export function railButtons(ctx) {
    const s = boot(ctx);
    const out = [];
    if (s.upd.available)
        out.push({glyph: '⬆', tip: 'Nueva versión del widget disponible — actualizar', onClick: () => C.runUpdate(ctx)});
    if (C.healthOf(ctx).incomplete)
        out.push({glyph: '🩹', tip: 'Al cerebro global le falta una pieza — curar (instala lo que falta)', onClick: () => C.heal(ctx)});
    return out;
}

// W.label + que el texto largo ENVUELVA en vez de cortarse con "…" (St.Label elipsa por defecto).
function lbl(text, style = '', opts = {}) {
    const l = W.label(text, style, opts);
    if (opts.wrap !== false) {
        l.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        l.clutter_text.line_wrap_mode = Pango.WrapMode.WORD_CHAR;
    }
    return l;
}

// St.Button centra a su hijo: el contenido de las hojas/banners debe ir a lo ancho, alineado a la izquierda.
function fillButton(child) {
    child.x_expand = true;
    child.x_align = Clutter.ActorAlign.FILL;
    return new St.Button({child, x_expand: true, x_align: Clutter.ActorAlign.FILL, can_focus: true, reactive: true});
}

function header(ctx) {
    const row = W.hbox('', {style: 'spacing: 6px;'});
    try {
        row.add_child(new St.Icon({gicon: Gio.FileIcon.new(Gio.File.new_for_path(C.paths(ctx.extPath).icon)),
            icon_size: 16, y_align: Clutter.ActorAlign.CENTER}));
    } catch {}
    row.add_child(lbl('Cerebro global', 'font-weight: bold; font-size: larger;', {expand: true, wrap: false}));
    row.add_child(W.button('🗺 mapa', () => {
        try {
            Gio.AppInfo.launch_default_for_uri(MAP_URL, null);
        } catch (e) {
            logError(e, 'cortex: no pude abrir el mapa');
        }
        ctx.closeMenu();
    }, {tip: 'Abre el mapa del cerebro (docs/mapa-cerebro.md) en tu navegador'}));
    return row;
}

// Banner ⬆ (naranja @16 %): solo si hay versión nueva, se está actualizando o hay un resultado.
function updateBanner(ctx) {
    const u = ctx.state.upd;
    if (!u.available && !u.running && !u.message)
        return null;
    let text;
    if (u.running)
        text = '… Actualizando… (al terminar, cierra sesión y vuelve a entrar)';
    else if (u.message)
        text = u.message;
    else if (u.canSelf)
        text = `⬆ Actualizar widget (${u.localShort} → ${u.remoteShort})`;
    else
        text = `⬆ Hay versión nueva (${u.remoteShort}) — actualiza con bootstrap.sh`;
    const box = W.vbox('', {style: `background-color: ${F.withAlpha(F.ACCENT, 0.16)}; border-radius: 6px; padding: 6px 8px; spacing: 4px;`});
    box.add_child(lbl(text, `color: ${F.ACCENT}; font-weight: bold; ${SMALL}`));
    // GNOME Shell no tiene tooltips: lo que el plasmoide pone en el tooltip va como línea tenue.
    if (!u.running && !u.message) {
        box.add_child(lbl(u.canSelf
            ? `Corre git fetch + checkout -B main origin/main + install.sh --gnome en ${u.repoPath}. GNOME carga la versión nueva al volver a entrar a la sesión.`
            : C.manualHint(u), `opacity: 0.7; ${SMALL}`));
    }
    if (!(u.canSelf && u.available && !u.running))
        return box;
    const btn = fillButton(box);
    btn.connect('clicked', () => C.runUpdate(ctx));
    return btn;
}

// Recuadro de salud BINARIO: ✓ verde completo / 🩹 rojo incompleto, versión, hora y la curita.
function healthBox(ctx) {
    const s = ctx.state;
    const ready = s.brain !== null;
    const h = C.healthOf(ctx);
    const allGood = ready && h.active === h.total;
    const healing = s.heal === 'running';
    const box = W.vbox('', {style: 'background-color: rgba(255,255,255,0.05); border-radius: 6px; padding: 6px 8px; spacing: 6px;'});

    const l1 = W.hbox('', {style: 'spacing: 6px;'});
    l1.add_child(lbl(allGood ? '✓' : '🩹', `color: ${allGood ? GREEN : F.DANGER}; font-weight: bold;`, {wrap: false}));
    l1.add_child(lbl(ready ? (allGood ? 'Cerebro global completo y activo' : 'Tu cerebro global está incompleto')
        : 'leyendo tu ~/.claude…', `font-weight: bold; ${SMALL}`, {expand: true}));
    const ver = s.brain && s.brain.version ? `${s.brain.version}` : '';
    if (ver)
        l1.add_child(lbl(`· v${ver}`, `opacity: 0.5; ${SMALL}`, {wrap: false}));
    if (s.scannedAt)
        l1.add_child(lbl(`leído ${s.scannedAt}`, 'opacity: 0.4; font-size: 0.78em;', {wrap: false}));
    box.add_child(l1);

    // La curita solo si hay algo que curar (sano → sin botón: el sello verde ya lo dice).
    if (h.missing > 0) {
        const l2 = W.hbox('', {style: 'spacing: 8px;'});
        const tint = F.DANGER;
        const b = new St.Button({label: healing ? '… Curando…' : `🩹 Curar cerebro global (${h.missing})`,
            can_focus: true, reactive: !healing, x_align: Clutter.ActorAlign.START});
        b.set_style(`color: ${tint}; font-weight: bold; ${SMALL} background-color: ${F.withAlpha(tint, 0.16)}; ` +
            `border-radius: 6px; padding: 3px 10px;${healing ? ' opacity: 0.7;' : ''}`);
        b.connect('clicked', () => C.heal(ctx));
        l2.add_child(b);
        if (s.heal === 'ok' || s.heal === 'error') {
            l2.add_child(lbl(s.heal === 'ok' ? '✓ curado' : '✗ error (¿jq / ruta del install-brain.sh?)',
                'opacity: 0.6; font-size: 0.78em;', {wrap: false}));
        }
        box.add_child(l2);
        box.add_child(lbl('Corre install-brain.sh: copia/cablea hooks globales, skills y normas en tu ~/.claude. Idempotente.',
            'opacity: 0.45; font-size: 0.78em;'));
    }
    return box;
}

// Una hoja: cabecera clickeable (conector · punto · emoji · nombre · ▸) + desc; al tocar despliega el
// chip del evento + detalle + estado. Solo una abierta a la vez; se alterna SIN re-render (no salta el scroll).
function leaf(ctx, cat, tier, it, key, last, openRef) {
    const s = ctx.state;
    const st = K.status(cat, s.brain, it.name);
    const col = W.vbox('', {style: 'spacing: 2px;'});

    const head = W.hbox('', {style: 'spacing: 5px;'});
    head.add_child(lbl(last ? '└─' : '├─', `font-family: monospace; color: ${tier.color}; opacity: 0.55;`, {wrap: false}));
    const d = K.dot(st);
    if (d)
        head.add_child(lbl(d, `color: ${K.dotColor(st)}; ${SMALL}`, {wrap: false}));
    head.add_child(lbl(it.emoji, '', {wrap: false}));
    head.add_child(lbl(it.name, 'font-family: monospace; font-weight: bold;', {expand: true}));
    const chev = lbl(s.expandedKey === key ? '▾' : '▸', `opacity: 0.35; ${SMALL}`, {wrap: false});
    head.add_child(chev);
    const headCol = W.vbox('', {style: 'spacing: 1px;'});
    headCol.add_child(head);
    headCol.add_child(lbl(it.desc, `opacity: 0.62; ${SMALL} padding-left: 26px;`));
    const btn = fillButton(headCol);
    col.add_child(btn);

    const detail = W.vbox('', {style: 'spacing: 3px; padding-left: 26px; padding-right: 4px;'});
    const chip = lbl(it.event, `color: ${tier.color}; font-weight: bold; font-family: monospace; font-size: 0.78em; ` +
        `background-color: ${F.withAlpha(tier.color, 0.15)}; border-radius: 3px; padding: 1px 5px;`,
    {wrap: false});
    chip.x_align = Clutter.ActorAlign.START;
    chip.x_expand = false;
    detail.add_child(chip);
    detail.add_child(lbl(it.detail, `opacity: 0.75; ${SMALL}`));
    if (st) {
        const r = W.hbox('', {style: 'spacing: 4px;'});
        r.add_child(lbl(K.dot(st), `color: ${K.dotColor(st)}; ${SMALL}`, {wrap: false}));
        r.add_child(lbl(K.statusLabel(st), `color: ${K.dotColor(st)}; ${SMALL}`));
        detail.add_child(r);
    }
    detail.visible = s.expandedKey === key;
    col.add_child(detail);

    const self = {key, detail, chev};
    if (detail.visible)
        openRef.cur = self;
    btn.connect('clicked', () => {
        const prev = openRef.cur;
        if (prev && prev !== self) {
            prev.detail.visible = false;
            prev.chev.text = '▸';
        }
        const open = !detail.visible;
        detail.visible = open;
        chev.text = open ? '▾' : '▸';
        openRef.cur = open ? self : null;
        s.expandedKey = open ? key : '';
    });
    return col;
}

// Un tier: espina de color a la izquierda + encabezado (emoji, TÍTULO en su color, subtítulo) + hojas vivas.
function tierBox(ctx, cat, tier, ti, openRef) {
    const items = tier.items.filter(it => K.isLive(cat, ctx.state.brain, it.name));
    const row = W.hbox('', {style: 'spacing: 8px;'});
    const spine = new St.Widget({y_expand: true});
    spine.set_style(`width: 3px; border-radius: 1px; background-color: ${tier.color};`);
    row.add_child(spine);
    const col = W.vbox('', {x_expand: true, style: 'spacing: 4px;'});
    const h = W.hbox('', {style: 'spacing: 6px;'});
    h.add_child(lbl(tier.emoji, 'font-size: 1.1em;', {wrap: false}));
    h.add_child(lbl(tier.title, `font-weight: bold; color: ${tier.color};`, {wrap: false}));
    col.add_child(h);
    col.add_child(lbl(tier.subtitle, `opacity: 0.6; ${SMALL}`));
    items.forEach((it, i) => col.add_child(leaf(ctx, cat, tier, it, `${ti}-${i}`, i === items.length - 1, openRef)));
    row.add_child(col);
    return row;
}

// ➕ OTROS: hooks cableados en settings.json fuera del catálogo.
function extrasBox(ctx, cat) {
    const ex = K.extras(cat, ctx.state.brain);
    if (ex.length === 0)
        return null;
    const row = W.hbox('', {style: 'spacing: 8px;'});
    const spine = new St.Widget({y_expand: true});
    spine.set_style('width: 3px; border-radius: 1px; background-color: rgba(255,255,255,0.3);');
    row.add_child(spine);
    const col = W.vbox('', {x_expand: true, style: 'spacing: 4px;'});
    const h = W.hbox('', {style: 'spacing: 6px;'});
    h.add_child(lbl('➕', 'font-size: 1.1em;', {wrap: false}));
    h.add_child(lbl('OTROS', 'font-weight: bold; opacity: 0.5;', {wrap: false}));
    col.add_child(h);
    col.add_child(lbl('hooks cableados en tu settings.json, fuera del catálogo del cerebro', `opacity: 0.6; ${SMALL}`));
    for (const name of ex) {
        const r = W.hbox('', {style: 'spacing: 5px;'});
        r.add_child(lbl('●', `color: ${GREEN}; opacity: 0.55; ${SMALL}`, {wrap: false}));
        r.add_child(lbl(name, 'font-family: monospace;', {wrap: false}));
        col.add_child(r);
    }
    row.add_child(col);
    return row;
}

export function build(ctx) {
    C.initState(ctx.state);
    const box = W.vbox('cortex-tab', {x_expand: true});
    box.set_style(`width: ${ctx.contentWidth}px; spacing: 12px;`);
    box.add_child(header(ctx));
    box.add_child(lbl('Guardarraíles + gobernanza + normas de Claude Code. Viaja por git, aplica en toda máquina. ' +
        'De más duro (arriba) a más leve (abajo). Toca una pieza para ver su evento y un ejemplo.', `opacity: 0.6; ${SMALL}`));

    const banner = updateBanner(ctx);
    if (banner)
        box.add_child(banner);

    const cat = C.catalog(ctx.extPath);
    if (!cat.ok) {
        box.add_child(lbl(`No pude leer el catálogo del cerebro: ${cat.error}`, `color: ${F.DANGER}; ${SMALL}`));
        return box;
    }
    box.add_child(healthBox(ctx));

    const openRef = {cur: null};
    cat.tiers.forEach((t, i) => box.add_child(tierBox(ctx, cat, t, i, openRef)));
    const ex = extrasBox(ctx, cat);
    if (ex)
        box.add_child(ex);

    box.add_child(lbl('Instalado por install-brain.sh · probado por test-brain.sh · sin jq los hooks fallan ABIERTO (no bloquean).',
        'opacity: 0.45; font-size: 0.78em;'));
    return box;
}
