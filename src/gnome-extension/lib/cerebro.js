// Acciones de la pestaña Cerebro: escaneo (brain-scan.sh scan), curita (brain-scan.sh heal) y
// autoupdate ⬆. Port de scanBrain/healBrainGlobal/checkUpdate/resolveRepoPath/runUpdate de main.qml,
// con los MISMOS comandos. Todo asíncrono y fail-open (sin red / sin version.json / sin clon → no molesta).
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import * as D from './data.js';
import {shq} from './fmt.js';
import * as K from './catalogo-cerebro.js';

const SLUG = 'unjordi/cortex';
const THROTTLE_MS = 15 * 60 * 1000;   // GitHub anónimo: como mucho 1 chequeo / 15 min
export const UPDATE_LOG = '/tmp/cortex-update.log';
export const BOOTSTRAP_ONE_LINER = 'curl -fsSL https://raw.githubusercontent.com/unjordi/cortex/main/bootstrap.sh | bash';

// CORTEX_DRY_RUN=1 en el entorno del Shell: heal/update solo REGISTRAN el comando (journal) y simulan
// éxito, para el QA en el Shell anidado sin mutar ~/.claude ni el clon.
const DRY_RUN = GLib.getenv('CORTEX_DRY_RUN') === '1';

const exists = p => GLib.file_test(p, GLib.FileTest.EXISTS);

// Ruta REAL de la extensión. En desarrollo es un symlink al árbol fuente y Gio normaliza "x/.." de
// forma léxica, así que hay que seguir el enlace antes de buscar ../plasmoid.
function realExtPath(extPath) {
    try {
        const info = Gio.File.new_for_path(extPath)
            .query_info('standard::is-symlink,standard::symlink-target', Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
        if (info.get_is_symlink()) {
            const t = info.get_symlink_target();
            return GLib.path_is_absolute(t) ? t : GLib.build_filenamev([GLib.path_get_dirname(extPath), t]);
        }
    } catch {}
    return extPath;
}

// Instalado: install.sh copia brain-scan.sh, brain/, version.json y el main.qml del plasmoide (como
// plasmoid-main.qml) a la raíz de la extensión. En desarrollo (dev-anidado.sh) se usan los del árbol.
export function paths(extPath) {
    const real = realExtPath(extPath);
    const pick = (...c) => c.find(exists) || c[0];
    return {
        script: pick(`${real}/brain-scan.sh`, `${real}/../plasmoid/contents/brain-scan.sh`),
        catalog: pick(`${real}/plasmoid-main.qml`, `${real}/../plasmoid/contents/ui/main.qml`),
        version: `${real}/version.json`,   // ausente (desarrollo / build viejo) ⇒ updater en "a mano"
        icon: `${real}/icons/cortex.svg`,
    };
}

// El catálogo se lee UNA vez por sesión del Shell (cambia solo al reinstalar, y eso exige re-login).
let _catalog = null;
export function catalog(extPath) {
    if (_catalog)
        return _catalog;
    const p = paths(extPath).catalog;
    try {
        const [, bytes] = Gio.File.new_for_path(p).load_contents(null);
        _catalog = {ok: true, ...K.parseQml(new TextDecoder().decode(bytes))};
    } catch (e) {
        _catalog = {ok: false, error: `${e.message} (${p})`};
    }
    return _catalog;
}

function hhmm() {
    return GLib.DateTime.new_now_local().format('%H:%M');
}

async function act(label, argv) {
    if (DRY_RUN) {
        log(`cortex[dry-run] ${label}: ${JSON.stringify(argv)}`);
        return {ok: true, status: 0, stdout: '', stderr: ''};
    }
    return D.run(argv);
}

// ---- Estado: vive en ctx.state (sobrevive re-renders). Campos:
//   brain (JSON de brain-scan.sh o null) · scannedAt · heal ''|'running'|'ok'|'error' · healVerifying
//   upd {lastCheck, localShort, localDate, remoteShort, repoPath, discovered, canSelf, loaded,
//        available, running, message}
export function initState(s) {
    if (s.upd)
        return s;
    s.brain = null;
    s.scannedAt = '';
    s.heal = '';
    s.healVerifying = false;
    s.expandedKey = '';
    s.upd = {lastCheck: 0, localShort: '?', localDate: '', remoteShort: '?', repoPath: '', discovered: '',
        canSelf: false, loaded: false, available: false, running: false, message: ''};
    return s;
}

export function healthOf(ctx) {
    const cat = catalog(ctx.extPath);
    return cat.ok ? K.health(cat, ctx.state.brain) : {total: 0, active: 0, missing: 0, incomplete: false};
}

// ctx.refresh() repinta el panel (badges) y, si el popup está abierto, la pestaña.
export async function scan(ctx) {
    const s = ctx.state;
    const r = await D.run(['bash', paths(ctx.extPath).script, 'scan']);
    if (r.ok && r.stdout) {
        try {
            s.brain = JSON.parse(r.stdout);
            s.scannedAt = hhmm();
        } catch {}   // deja el estado previo si el parse falla
    }
    // HEAL HONESTO: el veredicto final sale de la completitud REAL tras curar, no del exit del instalador.
    if (s.healVerifying) {
        s.healVerifying = false;
        s.heal = healthOf(ctx).incomplete ? 'error' : 'ok';
    }
    ctx.refresh();
}

export async function heal(ctx) {
    const s = ctx.state;
    if (s.heal === 'running')
        return;
    s.heal = 'running';
    ctx.refresh();
    const r = await act('heal', ['bash', paths(ctx.extPath).script, 'heal']);
    // Sin jq, install-brain.sh sale 0 SIN cablear nada: solo un exit≠0 es error inmediato; con 0 se
    // re-escanea y el veredicto lo fija scan() según la completitud real (mientras, "Curando…").
    if (!r.ok) {
        s.heal = 'error';
        ctx.refresh();
        return;
    }
    s.healVerifying = true;
    await scan(ctx);
}

// Chequeo de versión: 1×/15 min (force=true lo salta). Carga version.json una vez → resuelve el clon →
// consulta commits/main en GitHub.
export async function checkUpdate(ctx, force = false) {
    const u = ctx.state.upd;
    const now = Date.now();
    if (!force && u.lastCheck > 0 && now - u.lastCheck < THROTTLE_MS)
        return;
    u.lastCheck = now;
    if (!u.loaded) {
        const v = D.readJsonPath(paths(ctx.extPath).version);
        let embedded = '';
        if (v) {
            u.localShort = v.sha || '?';
            u.localDate = v.date || '';
            embedded = v.repo || '';
        }
        await resolveRepo(u, embedded);
        u.loaded = true;
    }
    await checkRemote(ctx);
}

// H2 — no confiar a ciegas en version.json.repo: gana el primer clon que EXISTA con install.sh; la 2.ª
// línea es cualquier clon visible (para el mensaje "a mano"). Mismo orden que main.qml/Updater.swift.
async function resolveRepo(u, embedded) {
    const script = 'for c in "$1" "$CLAUDE_BRAIN_DIR" "$HOME/.cortex" "$HOME/.claude-brain"; do ' +
        '[ -n "$c" ] && [ -f "$c/install.sh" ] && { printf "%s\\n" "$c"; break; }; done; ' +
        'for d in "$CLAUDE_BRAIN_DIR" "$HOME/.claude-brain" "$HOME/.cortex"; do ' +
        '[ -n "$d" ] && [ -e "$d" ] && { printf "%s\\n" "$d"; break; }; done';
    const r = await D.run(['bash', '-c', script, 'cortex-resolve', embedded]);
    const lines = r.ok ? r.stdout.split('\n') : [];
    u.repoPath = (lines[0] || '').trim();
    u.discovered = (lines[1] || '').trim();
    u.canSelf = u.repoPath !== '';
}

async function checkRemote(ctx) {
    const u = ctx.state.upd;
    if (u.localShort === '?')
        return;   // sin version.json (desarrollo / build viejo) → no molesta
    const r = await D.run(['curl', '-fsSL', '--max-time', '6', '-H', 'User-Agent: cortex',
        `https://api.github.com/repos/${SLUG}/commits/main`]);
    if (!r.ok || !r.stdout)
        return;   // sin red → fail-open
    try {
        const o = JSON.parse(r.stdout);
        if (!o.sha)
            return;
        u.remoteShort = `${o.sha}`.substring(0, 7);
        // Novedad = el sha remoto NO empieza con el local Y (si hay fechas) el remoto es más nuevo.
        const differs = `${o.sha}`.indexOf(u.localShort) !== 0;
        let newer = true;
        const rDate = o.commit && o.commit.committer ? o.commit.committer.date : '';
        if (u.localDate && rDate) {
            const lt = Date.parse(u.localDate), rt = Date.parse(rDate);
            if (!isNaN(lt) && !isNaN(rt))
                newer = rt > lt + 2000;
        }
        u.available = differs && newer;
        ctx.refresh();
    } catch {}
}

export function manualHint(u) {
    const where = u.discovered ? ` (tu clon: ${u.discovered})` : '';
    return `No puedo auto-actualizar${where}. Corre en tu terminal: ${BOOTSTRAP_ONE_LINER}`;
}

// El comando del update (el bash interno). Fuerza-alinea el clon a origin/main (patrón de bootstrap.sh;
// migra ~/.claude-brain → ~/.cortex si hace falta) y re-corre el instalador COMPLETO (cerebro + widget)
// en sabor GNOME. GNOME no recarga extensiones en caliente: la versión nueva carga al volver a entrar.
export function updateCommand(repo) {
    return `SRC=${shq(repo)}; DST=$HOME/.cortex; ` +
        '[ "$SRC" != "$DST" ] && [ -d "$SRC" ] && [ ! -e "$DST" ] && mv "$SRC" "$DST"; ' +
        'DIR=$DST; [ -d "$DIR/.git" ] || DIR=$SRC; ' +
        'cd "$DIR" && git fetch origin --quiet && git checkout -B main origin/main && ' +
        'bash "$DIR/install.sh" --gnome --no-reload-shell';
}

export async function runUpdate(ctx) {
    const u = ctx.state.upd;
    if (u.running)
        return;
    if (!u.canSelf || !u.repoPath) {
        u.message = manualHint(u);
        ctx.refresh();
        return;
    }
    u.running = true;
    u.message = '';
    ctx.refresh();
    // nohup + log, como el plasmoide: el instalador reemplaza el directorio de la extensión mientras corre.
    const r = await act('update', ['bash', '-c', `nohup bash -lc "$1" >${UPDATE_LOG} 2>&1`, 'cortex-update',
        updateCommand(u.repoPath)]);
    u.running = false;
    if (r.ok) {
        u.message = '✓ actualizado — cierra sesión y vuelve a entrar para cargar la versión nueva';
        u.available = false;
    } else {
        u.message = `✗ error (revisa ${UPDATE_LOG})`;
    }
    ctx.refresh();
}
