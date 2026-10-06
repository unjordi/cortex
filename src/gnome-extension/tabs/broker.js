// Pestaña 6 · Broker — port de "Tab 6: Broker" + BrokerKnob/BrokerFila + el PromptDialog
// confirmarBroker de main.qml. Estado y comandos en lib/broker.js (los mismos del QML).
// Reglas que se conservan del plasmoide:
//   · el TOKEN nunca se muestra — solo presencia y longitud (lo garantiza broker-scan.sh);
//   · lo que MUTA va por la herramienta oficial (migrador / broker-knobs.sh / systemctl);
//   · los knobs se dibujan GENÉRICOS del spec (broker-knobs.tsv): un knob nuevo aparece solo.
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Pango from 'gi://Pango';

import * as W from '../lib/widgets.js';
import * as B from '../lib/broker.js';
import {ACCENT, DANGER} from '../lib/fmt.js';

const OK = '#5fb98e';
const WARN = '#d6a15b';
const SMALL = 'font-size: smaller;';
const MONO = 'font-family: monospace;';

// Al entrar a la pestaña se re-lee el estado real (onCurrentTabChanged del QML, idx 6).
export function onShow(ctx) {
    const st = B.init(ctx.state);
    // Una edición a medio hacer no sobrevive a cerrar el popup (Esc) o salir de la pestaña.
    st.editing = '';
    st.drafts = {};
    B.scanBroker(ctx);
    B.scanKnobs(ctx);
}

// Párrafo que ENVUELVE: St.Label recorta con «…» por default aunque line_wrap esté encendido.
function para(text, style = '') {
    const l = W.label(text, style);
    l.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
    return l;
}

function small(text, style = '') {
    return para(text, `${SMALL} ${style}`);
}

// Una línea que se recorta EN MEDIO (rutas largas), como elide: Text.ElideMiddle.
function elided(text, style = '', expand = true) {
    const l = W.label(text, style, {expand, wrap: false});
    l.clutter_text.ellipsize = Pango.EllipsizeMode.MIDDLE;
    return l;
}

function spacer() {
    return new St.Widget({x_expand: true});
}

// Botón con ícono simbólico + texto opcional. `enabled=false` ⇒ no reactivo y atenuado.
function btn(icon, text, onClick, {enabled = true, tip = '', flat = false} = {}) {
    const b = new St.Button({style_class: flat ? '' : 'cortex-btn', can_focus: enabled, reactive: enabled});
    b.set_style(flat ? 'padding: 2px 4px; border-radius: 6px;' : '');
    const row = W.hbox('', {style: 'spacing: 6px;'});
    if (icon)
        row.add_child(new St.Icon({icon_name: icon, icon_size: 14, y_align: Clutter.ActorAlign.CENTER}));
    if (text)
        row.add_child(new St.Label({text, y_align: Clutter.ActorAlign.CENTER}));
    b.set_child(row);
    if (tip)
        b.accessible_name = tip;
    if (!enabled)
        b.opacity = 110;
    b.connect('clicked', () => {
        if (b.reactive)
            onClick();
    });
    return b;
}

function setEnabled(b, on) {
    b.reactive = on;
    b.can_focus = on;
    b.opacity = on ? 255 : 110;
}

// Recuadro con fondo tenue (los Rectangle con color Qt.rgba del QML).
function panel(bg, spacing = 4) {
    const p = W.vbox('', {x_expand: true});
    p.set_style(`background-color: ${bg}; border-radius: 6px; padding: 8px 10px; spacing: ${spacing}px;`);
    return p;
}

function sectionTitle(text) {
    return small(text, 'opacity: 0.6;');
}

// BrokerFila: etiqueta · valor monoespaciado (recortado en medio) · nota de veredicto.
function fila(etiqueta, valor, nota, notaColor) {
    const r = W.hbox('', {x_expand: true, style: 'spacing: 6px;'});
    const e = small(etiqueta, 'opacity: 0.6; min-width: 52px;');
    e.clutter_text.line_wrap = false;
    r.add_child(e);
    r.add_child(elided(valor, `${SMALL} ${MONO}`));
    if (nota) {
        const n = small(nota, `font-weight: bold;${notaColor ? ` color: ${notaColor};` : ''}`);
        n.clutter_text.line_wrap = false;
        r.add_child(n);
    }
    return r;
}

function header(ctx, st) {
    const r = W.hbox('', {x_expand: true, style: 'spacing: 6px;'});
    r.add_child(W.heading('Broker de terminal'));
    r.add_child(spacer());
    if (st.scannedAt)
        r.add_child(small(`leído ${st.scannedAt}`, 'opacity: 0.45;'));
    r.add_child(btn('view-refresh-symbolic', '', () => B.scanBroker(ctx),
        {tip: 'Re-leer el estado del servicio', flat: true}));
    return r;
}

function estado(d) {
    const p = panel(d.activo ? 'rgba(94, 186, 143, 0.13)' : 'rgba(219, 54, 69, 0.13)');
    const r = W.hbox('', {style: 'spacing: 6px;'});
    r.add_child(W.label(d.activo ? '●' : '○', `color: ${d.activo ? OK : DANGER}; font-size: 1.3em;`));
    r.add_child(W.label(d.estadoTexto, 'font-weight: bold;', {wrap: false}));
    if (d.arranqueTexto)
        r.add_child(small(d.arranqueTexto, 'opacity: 0.6;'));
    p.add_child(r);
    if (d.detalle)
        p.add_child(small(d.detalle, 'opacity: 0.7;'));
    // La unidad legacy sigue en disco tras la migración; si REVIVE hay dos brokers peleándose.
    if (d.legacyActiva) {
        p.add_child(small('⚠ axon-term-broker.service (la unidad anterior) está ACTIVA: dos brokers se pelean el mismo endpoint.',
            `color: ${DANGER}; font-weight: bold;`));
    }
    return p;
}

function endpoint(d) {
    const c = W.vbox('', {x_expand: true, style: 'spacing: 4px;'});
    c.add_child(sectionTitle('Endpoint'));
    // TRES estados, no dos: null es "no se pudo medir", que NO es "no escucha".
    const esc = d.escucha === true ? ['escuchando', OK] : d.escucha === false ? ['no escucha', DANGER] : ['sin medir', ''];
    c.add_child(fila('TCP', d.tcp, esc[0], esc[1]));
    c.add_child(fila('Socket', d.socketRuta, d.socketNota, d.socketOk ? OK : DANGER));
    // Nunca el valor del token: solo presencia y longitud.
    c.add_child(fila('Token', d.tokenTexto, d.tokenPresente ? '' : 'el broker no arranca sin él', DANGER));
    return c;
}

function verificacion(ctx, st) {
    const c = W.vbox('', {x_expand: true, style: 'spacing: 4px;'});
    const r = W.hbox('', {style: 'spacing: 8px;'});
    const running = st.verify === 'running';
    r.add_child(btn('object-select-symbolic', running ? 'Verificando…' : 'Verificar',
        () => B.verificarBroker(ctx), {enabled: !running}));
    if (st.verify === 'ok' || st.verify === 'error') {
        r.add_child(small(st.verify === 'ok' ? '✅ las 8 comprobaciones pasan' : '❌ falló alguna',
            `font-weight: bold; color: ${st.verify === 'ok' ? OK : DANGER};`));
    }
    c.add_child(r);
    c.add_child(small('Corre `migrar-term-broker.sh --verificar`: /health por el socket y por TCP con el token real, un 401 sin token, un /run que de verdad ejecuta, y los permisos del socket.',
        'opacity: 0.5;'));
    // El texto TAL CUAL del migrador (texto plano: St.Label no interpreta markup salvo use_markup).
    if (st.verifyOut) {
        // Ancho FIJO: sin él, el ancho natural de una línea larga empuja toda la pestaña fuera del popup.
        const sv = new St.ScrollView({
            hscrollbar_policy: St.PolicyType.AUTOMATIC,
            vscrollbar_policy: St.PolicyType.AUTOMATIC,
        });
        sv.set_width(ctx.contentWidth - 10);
        // Alto explícito (el ScrollView no hereda el natural de su hijo): ~16 px/línea, tope 220
        // como el gridUnit*16 del QML, + margen para la barra horizontal.
        const lineas = st.verifyOut.split('\n').length;
        sv.set_height(Math.min(220, lineas * 16 + 28));
        const out = W.label(st.verifyOut, `${SMALL} ${MONO}`, {wrap: false});
        out.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;   // NoWrap: se desplaza, no se recorta
        const inner = W.vbox('', {style: 'background-color: rgba(255,255,255,0.06); border-radius: 6px; padding: 6px;'});
        inner.add_child(out);
        sv.set_child(inner);
        c.add_child(sv);
    }
    return c;
}

// Confirmación EN LÍNEA de parar/reiniciar (el PromptDialog del QML): matar las terminales
// abiertas no se dispara con un clic suelto, y se dice la consecuencia con nombre y apellido.
function confirmacion(ctx, st) {
    const stop = st.confirmar === 'stop';
    const p = panel('rgba(219, 54, 69, 0.16)', 6);
    p.add_child(para(stop ? '¿Parar el broker?' : '¿Reiniciar el broker?', 'font-weight: bold;'));
    p.add_child(small(stop
        ? 'Se cerrarán TODAS las terminales abiertas: sus shells son procesos hijos del broker. El servicio no volverá solo hasta que lo arranques (o hasta la próxima sesión, si está habilitado).'
        : 'Se cerrarán TODAS las terminales abiertas: sus shells son procesos hijos del broker. El servicio vuelve a levantar enseguida, pero las sesiones NO se recuperan.'));
    const r = W.hbox('', {style: 'spacing: 8px;'});
    r.add_child(spacer());
    r.add_child(btn('', 'Cancelar', () => {
        st.confirmar = '';
        ctx.rerender();
    }));
    r.add_child(btn(stop ? 'media-playback-stop-symbolic' : 'view-refresh-symbolic', stop ? 'Parar' : 'Reiniciar',
        () => B.accionBroker(ctx, st.confirmar), {enabled: st.accion !== 'running'}));
    p.add_child(r);
    return p;
}

function pedir(ctx, st, cual, desde) {
    st.confirmar = cual;
    st.confirmarDesde = desde;
    ctx.rerender();
}

// BrokerKnob: todo lo que decide su forma sale del spec (tipo, rango, editable, 0 apaga, advertencia).
function knobRow(ctx, st, knob) {
    const editable = knob.gui === 'edita';
    // `actual` vacío = nadie lo configuró ⇒ manda el default del código.
    const enDefault = !knob.actual || `${knob.actual}`.length === 0;
    const efectivo = enDefault ? `${knob.default ?? ''}` : `${knob.actual}`;

    // Dos renglones (el popup mide ~370 px, no los ~11 gridUnit de etiqueta del QML):
    //   1) etiqueta · default|personalizado   2) campo + guardar + deshacer, o el valor solo-lectura.
    const col = W.vbox('', {x_expand: true, style: 'spacing: 2px;'});
    const r1 = W.hbox('', {x_expand: true, style: 'spacing: 6px;'});
    const r = W.hbox('', {x_expand: true, style: 'spacing: 6px; padding-left: 4px;'});

    // Etiqueta; al pasar el ratón, la línea de ayuda muestra el nombre EXACTO de la env var
    // (el ToolTip del QML; St no tiene tooltips).
    const et = W.label(knob.etiqueta, '', {expand: true, wrap: false});
    et.clutter_text.ellipsize = Pango.EllipsizeMode.END;
    et.reactive = true;
    et.track_hover = true;
    r1.add_child(et);

    if (editable) {
        const editando = st.editing === knob.env && !st.guardando;
        const valorCampo = () => (editando && entry ? entry.get_text() : efectivo);
        let entry = null;
        const save = btn('document-save-symbolic', '', () => B.guardarKnob(ctx, knob.env, valorCampo()),
            {tip: `Guardar en ${st.knobs ? st.knobs.archivo : ''}`, flat: true,
                enabled: editando && (st.drafts[knob.env] ?? efectivo) !== efectivo});
        if (editando) {
            // El St.Entry se crea VACÍO y recibe el texto ya con el foco: un St.Entry sin foco con
            // texto mapeado dispara 2 Clutter-CRITICAL (clutter_input_focus_*) por campo en cada
            // re-pintado (cada 10 s). Por eso hay a lo sumo UN campo vivo: el que se está editando.
            entry = new St.Entry({
                hint_text: `${knob.default ?? ''}`,   // vacío ⇒ vuelve al default (el escritor hace unset)
                can_focus: true,
                style: 'width: 90px; padding: 2px 6px;',
            });
            const ct = entry.clutter_text;
            const alMapear = ct.connect('notify::mapped', () => {
                if (!ct.mapped)
                    return;
                ct.disconnect(alMapear);
                ct.grab_key_focus();
                entry.set_text(st.drafts[knob.env] ?? efectivo);
                ct.set_cursor_position(-1);
            });
            entry.clutter_text.connect('text-changed', () => {
                st.drafts[knob.env] = entry.get_text();
                setEnabled(save, entry.get_text() !== efectivo);
            });
            entry.clutter_text.connect('activate', () => B.guardarKnob(ctx, knob.env, entry.get_text()));
            r.add_child(entry);
        } else {
            // Campo en reposo: el valor EFECTIVO; un clic lo vuelve editable partiendo de lo que hay.
            const campo = new St.Button({can_focus: !st.guardando, reactive: !st.guardando,
                style: 'width: 90px; padding: 2px 6px; border-radius: 6px; background-color: rgba(255,255,255,0.07);'});
            const t = W.label(efectivo, '', {wrap: false});
            t.x_expand = true;
            t.clutter_text.ellipsize = Pango.EllipsizeMode.START;
            campo.set_child(t);
            campo.x_align = Clutter.ActorAlign.START;
            t.x_align = Clutter.ActorAlign.END;
            campo.accessible_name = `Editar ${knob.env}`;
            campo.connect('clicked', () => {
                st.editing = knob.env;
                st.drafts[knob.env] = efectivo;
                ctx.rerender();
            });
            r.add_child(campo);
        }
        r.add_child(save);
        if (!enDefault) {
            r.add_child(btn('edit-undo-symbolic', '', () => {
                st.editing = '';
                B.guardarKnob(ctx, knob.env, '');
            }, {tip: `Volver al default (${knob.default ?? ''})`, flat: true, enabled: !st.guardando}));
        }
        r.add_child(spacer());
    } else {
        // Solo-lectura: el valor, y por qué no se toca aquí.
        r.add_child(elided(efectivo, `${SMALL} ${MONO}`));
        const m = small('solo a mano', 'opacity: 0.5;');
        m.clutter_text.line_wrap = false;
        r.add_child(m);
    }
    // Se marca cuándo el valor es el DEFAULT y cuándo alguien lo cambió.
    const badge = small(enDefault ? 'default' : 'personalizado',
        enDefault ? 'opacity: 0.4;' : `color: ${ACCENT}; opacity: 0.75;`);
    badge.clutter_text.line_wrap = false;
    r1.add_child(badge);
    col.add_child(r1);
    col.add_child(r);

    let ayuda = knob.ayuda || '';
    if (knob.cero_apaga)
        ayuda += '  ·  0 lo APAGA.';
    if (knob.min !== null && knob.min !== undefined && knob.max !== null && knob.max !== undefined)
        ayuda += `  ·  entre ${knob.min} y ${knob.max}.`;
    const ayudaL = small(ayuda, 'opacity: 0.55; padding-left: 4px;');
    et.connect('notify::hover', () => {
        ayudaL.text = et.hover ? `${knob.env}  (en ${st.knobs.archivo || 'el .env'})` : ayuda;
        ayudaL.set_style(et.hover ? `${SMALL} ${MONO} opacity: 0.8; padding-left: 4px;` : `${SMALL} opacity: 0.55; padding-left: 4px;`);
    });
    col.add_child(ayudaL);
    // La advertencia NO se mezcla con la ayuda: es el riesgo concreto de cambiarlo.
    if (knob.advertencia)
        col.add_child(small(`⚠ ${knob.advertencia}`, `color: ${WARN}; padding-left: 4px;`));
    return col;
}

function ajustes(ctx, st) {
    const c = W.vbox('', {x_expand: true, style: 'spacing: 6px;'});
    const h = W.hbox('', {x_expand: true, style: 'spacing: 6px;'});
    h.add_child(sectionTitle('Ajustes'));
    h.add_child(spacer());
    if (st.knobs && st.knobs.archivo) {
        const a = elided(st.knobs.archivo, `${SMALL} ${MONO} opacity: 0.35; max-width: 230px;`, false);
        h.add_child(a);
    }
    c.add_child(h);

    if (!st.knobs) {
        c.add_child(para('Leyendo los ajustes…', 'opacity: 0.6;'));
        return c;
    }

    // El aviso que NO se puede omitir: el .env ya cambió, el broker que corre no.
    if (st.reinicioPendiente) {
        const p = panel('rgba(232, 135, 74, 0.18)', 6);
        p.add_child(small('Los cambios están guardados, pero el broker que CORRE sigue con los valores viejos. Reinícialo para aplicarlos — recuerda que eso cierra las terminales abiertas.'));
        const r = W.hbox('');
        r.add_child(spacer());
        r.add_child(btn('view-refresh-symbolic', 'Reiniciar', () => pedir(ctx, st, 'restart', 'aviso'),
            {enabled: st.accion !== 'running'}));
        p.add_child(r);
        c.add_child(p);
        if (st.confirmar && st.confirmarDesde === 'aviso')
            c.add_child(confirmacion(ctx, st));
    }

    if (st.knobsMsg)
        c.add_child(small(st.knobsMsg, `color: ${DANGER};`));

    // Un bloque por grupo, en el orden del spec; el grupo se OMITE si no tiene knobs.
    for (const g of B.grupos(st.knobs)) {
        const ks = B.knobsDe(st.knobs, g.clave);
        if (ks.length === 0)
            continue;
        c.add_child(small(g.titulo !== undefined ? g.titulo : g.clave, 'font-weight: bold; opacity: 0.75; padding-top: 4px;'));
        for (const k of ks)
            c.add_child(knobRow(ctx, st, k));
    }

    c.add_child(small('Dejar un campo vacío devuelve ese ajuste a su default. El token no se edita aquí a propósito, y los cuatro del endpoint tampoco: cambiarlos rompe al cliente en contenedor, o expone el broker a la red.',
        'opacity: 0.45; padding-top: 4px;'));
    return c;
}

function servicio(ctx, st, d) {
    const c = W.vbox('', {x_expand: true, style: 'spacing: 6px;'});
    c.add_child(sectionTitle('Servicio'));
    const r = W.hbox('', {style: 'spacing: 6px;'});
    const libre = st.accion !== 'running';
    r.add_child(btn('media-playback-start-symbolic', 'Arrancar', () => B.accionBroker(ctx, 'start'),
        {enabled: libre && !d.activo}));
    r.add_child(btn('view-refresh-symbolic', 'Reiniciar', () => pedir(ctx, st, 'restart', 'servicio'),
        {enabled: libre}));
    r.add_child(btn('media-playback-stop-symbolic', 'Parar', () => pedir(ctx, st, 'stop', 'servicio'),
        {enabled: libre && d.activo}));
    r.add_child(spacer());
    if (!libre)
        r.add_child(W.label('…', 'opacity: 0.6;'));
    c.add_child(r);
    if (st.confirmar && st.confirmarDesde === 'servicio')
        c.add_child(confirmacion(ctx, st));
    if (st.accionMsg)
        c.add_child(small(st.accionMsg, `color: ${DANGER};`));
    c.add_child(small('Parar o reiniciar MATA las terminales abiertas: las sesiones son procesos hijos del broker (KillMode=control-group).',
        'opacity: 0.5;'));
    return c;
}

// El núcleo re-crea el ScrollView en cada re-pintado (tick de 10 s): se guarda y se restaura el
// desplazamiento para que la pestaña —larga, por los knobs— no salte arriba mientras se edita.
function preservarScroll(box, st) {
    let vivo = true, enganchado = false;
    box.connect('destroy', () => {
        vivo = false;
    });
    box.connect('notify::mapped', () => {
        if (!vivo || !box.mapped || enganchado)
            return;
        const adj = box.get_parent()?.vadjustment;
        if (!adj)
            return;
        enganchado = true;
        let pendiente = st.scrollY || 0;
        // Se restaura cuando el layout ya dio el alto real (antes de asignar, upper vale 0).
        const intentar = () => {
            if (!vivo || pendiente <= 0 || adj.upper <= adj.page_size)
                return;
            adj.value = Math.min(pendiente, adj.upper - adj.page_size);
            pendiente = 0;
        };
        adj.connect('changed', intentar);
        adj.connect('notify::value', () => {
            if (vivo && box.mapped && pendiente <= 0)
                st.scrollY = adj.value;
        });
        intentar();
    });
}

export function build(ctx) {
    const st = B.init(ctx.state);
    const d = B.derivados(st);
    const box = W.vbox('cortex-tab', {x_expand: true});
    box.set_width(ctx.contentWidth - 10);   // margen para la barra de desplazamiento
    preservarScroll(box, st);

    box.add_child(header(ctx, st));

    // Sin dato todavía: se DICE, en vez de pintar un estado inventado.
    if (!d.cargado) {
        box.add_child(para('Leyendo el estado del servicio…', 'opacity: 0.6;'));
    } else {
        box.add_child(estado(d));
        box.add_child(endpoint(d));
    }
    box.add_child(verificacion(ctx, st));
    box.add_child(ajustes(ctx, st));
    box.add_child(servicio(ctx, st, d));
    return box;
}
