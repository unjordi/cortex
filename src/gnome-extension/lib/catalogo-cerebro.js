// Catálogo del árbol del cerebro para la pestaña Cerebro — SIN copia propia: se LEE del main.qml del
// plasmoide (propiedades brainTiers / brainGlobalHooks / brainRepoHooks / brainNormNames), así KDE y
// GNOME comparten UN solo catálogo de Linux (ver .claude/memory/arbol-cerebro-sync.md).
// Módulo PURO (sin gi://): lo importa la extensión y también node, para el check de
// docs/flowcharts/verificar-arbol-sync.sh, que pone rojo el repo si el parser deja de entender el QML.

// Devuelve el literal [...] que sigue a `<prop>: ` en el QML (balanceando corchetes y saltando strings).
function arrayLiteral(text, prop) {
    const m = new RegExp(`property\\s+var\\s+${prop}\\s*:\\s*\\[`).exec(text);
    if (!m)
        throw new Error(`no encuentro la propiedad ${prop} en el QML`);
    const start = m.index + m[0].length - 1;
    let depth = 0;
    for (let i = start; i < text.length; i++) {
        const c = text[i];
        if (c === '"' || c === "'") {
            i = skipString(text, i);
            continue;
        }
        if (c === '/' && text[i + 1] === '/') {
            i = text.indexOf('\n', i);
            if (i < 0)
                break;
            continue;
        }
        if (c === '[' || c === '{')
            depth++;
        else if (c === ']' || c === '}') {
            depth--;
            if (depth === 0)
                return text.slice(start, i + 1);
        }
    }
    throw new Error(`corchete sin cerrar en ${prop}`);
}

// Índice del cierre del string que abre en text[i].
function skipString(text, i) {
    const q = text[i];
    for (let j = i + 1; j < text.length; j++) {
        if (text[j] === '\\')
            j++;
        else if (text[j] === q)
            return j;
    }
    throw new Error('string sin cerrar en el QML');
}

// Literal de objeto JS/QML → JSON: comillas a las llaves desnudas, fuera comentarios y comas colgantes.
// Tokeniza respetando strings (un ':' o una ',' dentro de un texto no se toca).
function toJson(lit) {
    let out = '';
    for (let i = 0; i < lit.length; i++) {
        const c = lit[i];
        if (c === '"' || c === "'") {
            const j = skipString(lit, i);
            const body = lit.slice(i + 1, j);
            out += c === '"' ? `"${body}"` : JSON.stringify(body.replace(/\\'/g, "'"));
            i = j;
        } else if (c === '/' && lit[i + 1] === '/') {
            const j = lit.indexOf('\n', i);
            i = j < 0 ? lit.length : j - 1;
        } else if (/[A-Za-z_$]/.test(c)) {
            const m = /^[A-Za-z_$][\w$]*/.exec(lit.slice(i));
            const word = m[0];
            const rest = lit.slice(i + word.length);
            out += /^\s*:/.test(rest) ? `"${word}"` : word;
            i += word.length - 1;
        } else {
            out += c;
        }
    }
    return out.replace(/,(\s*[\]}])/g, '$1');
}

// → {tiers:[{emoji,title,color,subtitle,items:[{emoji,name,desc,event,detail}]}], globalHooks, repoHooks, normNames}
export function parseQml(text) {
    const tiers = JSON.parse(toJson(arrayLiteral(text, 'brainTiers')));
    const list = p => JSON.parse(toJson(arrayLiteral(text, p)));
    const cat = {
        tiers,
        globalHooks: list('brainGlobalHooks'),
        repoHooks: list('brainRepoHooks'),
        normNames: list('brainNormNames'),
    };
    // Forma mínima: si el QML cambia de forma, mejor un error claro que una pestaña a medias.
    if (!Array.isArray(tiers) || tiers.length === 0)
        throw new Error('brainTiers vacío');
    for (const t of tiers) {
        if (!t.title || !Array.isArray(t.items) || t.items.length === 0)
            throw new Error(`tier sin título o sin hojas: ${JSON.stringify(t).slice(0, 80)}`);
        for (const it of t.items) {
            for (const k of ['emoji', 'name', 'desc', 'event', 'detail']) {
                if (typeof it[k] !== 'string' || it[k] === '')
                    throw new Error(`hoja sin ${k}: ${it.name || '?'}`);
            }
        }
    }
    return cat;
}

// ---- Lógica de estado (port 1:1 de brainStatus / isBrainLive / brainTotal… de main.qml) ----
const inArr = (a, x) => Array.isArray(a) && a.indexOf(x) !== -1;

// "" | "installed" | "presentNotWired" | "absent" | "repoScoped"
export function status(cat, st, name) {
    if (!st)
        return '';
    if (inArr(cat.globalHooks, name)) {
        const p = inArr(st.present, name), w = inArr(st.wired, name);
        return p && w ? 'installed' : (p ? 'presentNotWired' : 'absent');
    }
    if (inArr(cat.repoHooks, name))
        return 'repoScoped';
    if (inArr(cat.normNames, name))
        return st.hasNorms ? 'installed' : 'absent';
    // Cualquier otro nombre es una SKILL: su estado sale de la fuente viva (st.skills), sin lista tecleada.
    return inArr(st.skills, name) ? 'installed' : 'absent';
}

// Retirados (fuera de la fuente viva) ni se muestran ni cuentan. Sin escaneo aún → se muestra todo.
export function isLive(cat, st, name) {
    if (!st)
        return true;
    if (inArr(cat.globalHooks, name) || inArr(cat.repoHooks, name) || inArr(cat.normNames, name))
        return true;
    return inArr(st.skills, name);
}

// {total, active, missing, incomplete} de las piezas GLOBALES vivas (las repo-scoped no cuentan).
export function health(cat, st) {
    if (!st)
        return {total: 0, active: 0, missing: 0, incomplete: false};
    let total = 0, active = 0;
    for (const t of cat.tiers) {
        for (const it of t.items) {
            if (!isLive(cat, st, it.name))
                continue;
            const s = status(cat, st, it.name);
            if (s === 'repoScoped')
                continue;
            total++;
            if (s === 'installed')
                active++;
        }
    }
    return {total, active, missing: total - active, incomplete: active < total};
}

// Hooks cableados en settings.json fuera del catálogo (sección "➕ OTROS").
export function extras(cat, st) {
    if (!st || !Array.isArray(st.wired))
        return [];
    const known = cat.globalHooks.concat(cat.repoHooks);
    return st.wired.filter(w => known.indexOf(w) === -1).sort();
}

export function dot(s) {
    if (s === 'installed')
        return '✓';
    if (s === 'repoScoped')
        return '◈';
    if (s === '')
        return '';
    return '！';
}

export function dotColor(s) {
    if (s === 'installed')
        return '#3aa76d';
    if (s === 'repoScoped')
        return 'rgba(74, 144, 217, 0.6)';
    return '#dc3545';
}

export function statusLabel(s) {
    if (s === 'installed')
        return 'instalado + cableado en tu ~/.claude';
    if (s === 'presentNotWired')
        return 'el script existe pero NO está cableado en settings.json';
    if (s === 'repoScoped')
        return 'viaja por repo: se copia al .claude/ de cada proyecto';
    return 'no instalado en tu ~/.claude';
}
