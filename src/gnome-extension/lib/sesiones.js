// Alias de proyectos/sesiones, resumir, sugerir nombre y mover sesión — port de renameProject/
// renameSession/serializeAliasMap/writeAliasMap, resumeSession, suggestName/cleanSuggestion,
// otherProjects/moveSession y refreshSessions de src/plasmoid/contents/ui/main.qml (paridad con
// QuotaModel.swift). Sin GTK/St: se puede probar con gjs fuera del shell.
import GLib from 'gi://GLib';

import * as D from './data.js';
import {shq} from './fmt.js';

export const PROJ_ALIAS = 'proyectos-alias.json';
export const SESS_ALIAS = 'sesiones-alias.json';

// Base de los mapas = CLAUDE_CONFIG_DIR o ~/.claude (la MISMA que leen cortex-fetch/sessions-extract.js).
// Se resuelve en cada llamada (no al cargar el módulo) para que una prueba pueda fijarla por env.
export function aliasDir() {
    return GLib.getenv('CLAUDE_CONFIG_DIR') || D.ALIAS_DIR;
}

function readMap(file) {
    const m = D.readJsonPath(GLib.build_filenamev([aliasDir(), file]));
    return m && typeof m === 'object' && !Array.isArray(m) ? m : {};
}

export const projAliasMap = () => readMap(PROJ_ALIAS);
export const sessAliasMap = () => readMap(SESS_ALIAS);

// LLAVES ORDENADAS + 2 espacios → diff limpio si el archivo se versiona/sincroniza.
export function serializeAliasMap(map) {
    return JSON.stringify(map, Object.keys(map).sort(), 2);
}

function writeAliasMap(file, map) {
    D.writeText(GLib.build_filenamev([aliasDir(), file]), serializeAliasMap(map));
}

// Proyecto: la lista muestra el nombre YA aliaseado. Llave canónica = la entrada cuyo VALOR == mostrado;
// si no hay, el mostrado ES el canónico. Nuevo vacío o == canónico → BORRA (revierte).
export function renameProject(shown, newName) {
    const map = projAliasMap();
    let canonical = shown;
    for (const k of Object.keys(map)) {
        if (map[k] === shown) {
            canonical = k;
            break;
        }
    }
    const v = `${newName ?? ''}`.trim();
    if (v === '' || v === canonical)
        delete map[canonical];
    else
        map[canonical] = v;
    writeAliasMap(PROJ_ALIAS, map);
}

// Sesión: llave = id (estable). Vacío → borra (revierte a la etiqueta derivada del transcript).
export function renameSession(id, newName) {
    const map = sessAliasMap();
    const v = `${newName ?? ''}`.trim();
    if (v === '')
        delete map[id];
    else
        map[id] = v;
    writeAliasMap(SESS_ALIAS, map);
}

export function projectAliased(shown) {
    const map = projAliasMap();
    return map[shown] !== undefined || Object.values(map).includes(shown);
}

export function sessionAliased(id) {
    const v = sessAliasMap()[id];
    return v !== undefined && v !== null;
}

// Refresh RÁPIDO (sin red): solo sessions-extract.js por el PATH de login. → array o null (fail-safe).
export async function refreshSessions() {
    const r = await D.run(['bash', '-lc', 'sessions-extract.js']);
    if (!r.ok || !r.stdout)
        return null;
    try {
        const arr = JSON.parse(r.stdout);
        return Array.isArray(arr) ? arr : null;
    } catch {
        return null;
    }
}

// Terminales en cascada: GNOME primero (ptyxis, gnome-terminal, kgx), luego las del plasmoide.
// `command -v` (no `||`): una terminal que SÍ arrancó pero sale ≠0 no debe abrir una segunda.
export function resumeCommand(cwd, id) {
    const arg = shq(`cd ${shq(cwd)} && claude --resume ${shq(id)}; exec bash`);
    const terms = [
        ['ptyxis', `ptyxis -- bash -lc ${arg}`],
        ['gnome-terminal', `gnome-terminal -- bash -lc ${arg}`],
        ['kgx', `kgx -- bash -lc ${arg}`],
        ['konsole', `konsole -e bash -lc ${arg}`],
        ['x-terminal-emulator', `x-terminal-emulator -e bash -lc ${arg}`],
        ['xterm', `xterm -e bash -lc ${arg}`],
    ];
    return `${terms.map(([bin, cmd], i) =>
        `${i ? 'elif' : 'if'} command -v ${bin} >/dev/null 2>&1; then ${cmd}`).join('; ')}; fi`;
}

export function resumeSession(cwd, id) {
    return D.sh(resumeCommand(cwd, id));
}

// `--no-session-persistence`: sin ella `claude -p` guarda una sesión con cwd=/ (proyecto fantasma "/").
export function suggestCommand(summary) {
    const prompt = 'Genera un nombre corto (de 3 a 6 palabras) en español para esta sesión de Claude Code, ' +
        'a partir de su contexto. Responde SOLO con el nombre, sin comillas ni puntuación final.\n\n' +
        `Contexto: ${summary}`;
    return ['bash', '-lc', `claude -p --no-session-persistence ${shq(prompt)}`];
}

// Primera línea no vacía, sin comillas/asteriscos/punto envolventes.
export function cleanSuggestion(raw) {
    let s = `${raw}`.trim();
    for (const line of s.split('\n')) {
        if (line.trim() !== '') {
            s = line.trim();
            break;
        }
    }
    return s.replace(/^["'`*\s]+/, '').replace(/["'`*.\s]+$/, '');
}

// → nombre sugerido, o null si falló (cuesta tokens: lo dispara el usuario).
export async function suggestName(summary) {
    const ctxt = `${summary ?? ''}`.trim();
    if (ctxt === '')
        return null;
    const r = await D.run(suggestCommand(ctxt));
    if (!r.ok || r.stdout.trim() === '')
        return null;
    return cleanSuggestion(r.stdout);
}

// Proyectos conocidos DISTINTOS del actual (uno por proyecto, con su cwd real), ordenados por nombre.
export function otherProjects(sessions, excludeProject) {
    const seen = {}, out = [];
    for (const s of sessions || []) {
        const p = s.project ? s.project : '?';
        if (p === excludeProject || !s.cwd || seen[p])
            continue;
        seen[p] = true;
        out.push({name: p, cwd: s.cwd});
    }
    return out.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
}

// session-move.js escribe JSON a stdout SIEMPRE (ok:true | ok:false+error con exit 1). → {ok, error}.
export async function moveSession(id, toCwd) {
    const r = await D.run(['bash', '-lc', `session-move.js ${shq(id)} --to-cwd ${shq(toCwd)}`]);
    let res = null;
    try {
        res = JSON.parse(r.stdout);
    } catch {}
    if (res && res.ok)
        return {ok: true};
    return {ok: false, error: res && res.error ? res.error : `no se pudo mover la sesión (rc=${r.status})`};
}
