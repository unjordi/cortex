// Broker de terminal — estado y ACCIONES de la pestaña Broker (port de las funciones scanBroker,
// scanKnobs, guardarKnob, verificarBroker y accionBroker + sus DataSources en main.qml).
// Los comandos son los MISMOS del QML, carácter por carácter: aquí no se reimplementa nada del broker;
// se delega a broker-scan.sh / broker-knobs.sh / el migrador / systemctl, como en el plasmoide.
import GLib from 'gi://GLib';

import * as D from './data.js';
import {fmtBytes, shq} from './fmt.js';

// Instalado: el instalador copia los helpers a la RAÍZ de la extensión. En desarrollo
// (dev-anidado.sh enlaza src/gnome-extension tal cual) no están ahí → se usan los del plasmoide,
// que son la fuente. broker-knobs.sh encuentra su spec (.tsv) relativo a SÍ MISMO, así que con
// resolver el script basta para que lea el spec canónico de src/widget-spec/.
export function helper(extPath, name) {
    const cands = [
        GLib.build_filenamev([extPath, name]),
        GLib.build_filenamev([extPath, '..', 'plasmoid', 'contents', name]),
    ];
    return cands.find(p => GLib.file_test(p, GLib.FileTest.EXISTS)) || cands[0];
}

// Estado inicial de la pestaña (vive en ctx.state, sobrevive los re-renders del popup).
export function init(st) {
    if (st.init)
        return st;
    Object.assign(st, {
        init: true,
        scan: null,            // brokerState: JSON de `broker-scan.sh scan`, null = aún sin dato
        scannedAt: '',         // "hh:mm" del último escaneo bueno
        verify: '',            // '' | 'running' | 'ok' | 'error'
        verifyOut: '',         // texto TAL CUAL del migrador
        accion: '',            // '' | 'running'
        accionMsg: '',
        confirmar: '',         // '' | 'stop' | 'restart' — confirmación en línea pendiente
        knobs: null,           // JSON de `broker-knobs.sh list`
        knobsMsg: '',          // motivo del rechazo de la última escritura
        guardando: false,
        reinicioPendiente: false,
        editing: '',           // env del knob cuyo campo está abierto (a lo sumo uno)
        drafts: {},            // env → texto en edición (el popup se re-pinta cada 10 s)
    });
    return st;
}

export const cmd = {
    scan: extPath => `bash ${shq(helper(extPath, 'broker-scan.sh'))} scan`,
    knobsList: extPath => `bash ${shq(helper(extPath, 'broker-knobs.sh'))} list`,
    // `valor` vacío ⇒ unset (vuelve al default del código). El valor va SIEMPRE por shq.
    knobSet: (extPath, env, valor) => {
        const sub = `${valor}`.trim() === '' ? `unset ${shq(env)}` : `set ${shq(env)} ${shq(`${valor}`)}`;
        return `bash ${shq(helper(extPath, 'broker-knobs.sh'))} ${sub} 2>&1`;
    },
    // 2>&1: los ❌ del migrador salen por stderr y son justo lo que hay que mostrar.
    verificar: migrador => `bash ${shq(migrador)} --verificar 2>&1`,
    accion: cual => `systemctl --user ${cual} cortex-term-broker.service 2>&1`,
};

export async function scanBroker(ctx) {
    const st = ctx.state;
    const r = await D.sh(cmd.scan(ctx.extPath));
    if (r.ok && r.stdout) {
        try {
            st.scan = JSON.parse(r.stdout);
            st.scannedAt = GLib.DateTime.new_now_local().format('%H:%M');
        } catch {}   // deja el estado previo si el parse falla
    }
    ctx.rerender();
}

export async function scanKnobs(ctx) {
    const st = ctx.state;
    const r = await D.sh(cmd.knobsList(ctx.extPath));
    if (r.ok && r.stdout) {
        try {
            st.knobs = JSON.parse(r.stdout);
        } catch {}
    }
    ctx.rerender();
}

// El escritor valida contra el spec y sale != 0 si rechaza, con el motivo por stdout: eso se muestra.
export async function guardarKnob(ctx, env, valor) {
    const st = ctx.state;
    st.guardando = true;
    st.knobsMsg = '';
    ctx.rerender();
    const r = await D.sh(cmd.knobSet(ctx.extPath, env, valor));
    st.guardando = false;
    if (r.ok) {
        st.reinicioPendiente = true;
        st.knobsMsg = '';
        delete st.drafts[env];
        if (st.editing === env)
            st.editing = '';
    } else {
        st.knobsMsg = `${r.stdout || r.stderr || 'no se pudo escribir'}`.trim();
    }
    // Se RE-LEE siempre: lo que se pinta sale del archivo, no de haber pedido el cambio.
    await scanKnobs(ctx);
}

// Las comprobaciones REALES las corre el migrador instalado. El VEREDICTO es su exit code.
export async function verificarBroker(ctx) {
    const st = ctx.state;
    const m = st.scan && st.scan.migrador ? st.scan.migrador.ruta : '';
    if (!m) {
        st.verify = 'error';
        st.verifyOut = 'No encuentro el migrador instalado. Corre ./install.sh --con-term-broker desde el clon de cortex.';
        ctx.rerender();
        return;
    }
    st.verify = 'running';
    st.verifyOut = '';
    ctx.rerender();
    const r = await D.sh(cmd.verificar(m));
    st.verifyOut = `${r.stdout || ''}${r.stderr || ''}`;
    st.verify = r.ok ? 'ok' : 'error';
    ctx.rerender();
}

// start | stop | restart. HONESTO: el exit 0 de systemctl dice que ACEPTÓ la orden, no que el
// servicio quedó arriba — por eso se RE-ESCANEA y lo que se pinta sale del escaneo.
export async function accionBroker(ctx, cual) {
    const st = ctx.state;
    st.accion = 'running';
    st.accionMsg = '';
    st.confirmar = '';
    ctx.rerender();
    const r = await D.sh(cmd.accion(cual));
    st.accion = '';
    st.accionMsg = r.ok ? '' : `✗ ${`${r.stderr || r.stdout || 'systemctl falló'}`.trim()}`;
    await scanBroker(ctx);
}

// ── Derivados (las readonly property brokerXxx del QML) ──

export function derivados(st) {
    const s = st.scan;
    const u = s && s.unidad ? s.unidad : null;
    const e = s && s.endpoint ? s.endpoint : null;
    const out = {
        cargado: s !== null,
        activo: u ? u.activa === true : false,
        legacyActiva: s && s.legacy ? s.legacy.activa === true : false,
        estadoTexto: 'sin dato',
        arranqueTexto: '',
        detalle: '',
        tcp: e ? `127.0.0.1:${e.puerto}` : '',
        socketRuta: e && e.socket ? e.socket : '—',
        socketOk: e ? e.socket_existe === true && e.socket_permisos === '600' : false,
        socketNota: '',
        tokenPresente: s && s.token ? s.token.presente === true : false,
        // `null` = no se pudo medir; se pinta distinto de un false ("no escucha").
        escucha: e ? e.escuchando_tcp : null,
    };
    if (u) {
        out.estadoTexto = !u.en_disco ? 'no instalado' : (u.estado ? u.estado : (u.activa ? 'activo' : 'inactivo'));
        out.arranqueTexto = u.habilitada ? '· arranca con la sesión' : '· NO arranca con la sesión';
        const partes = [];
        if (u.desde)
            partes.push(`desde ${u.desde}`);
        if (u.pid !== null && u.pid !== undefined)
            partes.push(`pid ${u.pid}`);
        if (u.memoria_bytes !== null && u.memoria_bytes !== undefined) {
            partes.push(`RAM ${fmtBytes(u.memoria_bytes)}${
                u.memoria_pico_bytes ? ` (pico ${fmtBytes(u.memoria_pico_bytes)})` : ''}`);
        }
        if (u.reinicios !== null && u.reinicios !== undefined && u.reinicios > 0)
            partes.push(`${u.reinicios} reinicio(s)`);
        out.detalle = partes.join(' · ');
    }
    if (e) {
        if (!e.socket_existe)
            out.socketNota = 'no existe';
        else
            out.socketNota = e.socket_permisos === '600' ? `0600 · ${e.socket_dueno}`
                : `permisos ${e.socket_permisos} (¡esperaba 600!)`;
    }
    // Nunca el valor del token: solo presencia y longitud.
    out.tokenTexto = out.tokenPresente ? `presente (${s.token.chars} caracteres)` : 'AUSENTE';
    return out;
}

// Grupos en el orden del spec (filas @grupo) y knobs por grupo — nada hardcodeado aquí.
export function grupos(knobs) {
    return knobs && knobs.grupos ? knobs.grupos : [];
}

export function knobsDe(knobs, grupo) {
    return knobs && knobs.knobs ? knobs.knobs.filter(k => k.grupo === grupo) : [];
}
