// Acceso a datos: lee los JSON que publica el daemon (cortex-fetch) y corre comandos.
// La extensión es VISTA PURA, igual que el plasmoide: no consulta la red por su cuenta.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

export const CACHE_DIR = GLib.build_filenamev([GLib.get_user_cache_dir(), 'cortex']);

// null si el archivo falta o no es JSON (fail-open: cada pestaña decide qué mostrar).
export function readJson(name) {
    try {
        const [ok, bytes] = Gio.File.new_for_path(GLib.build_filenamev([CACHE_DIR, name]))
            .load_contents(null);
        if (!ok)
            return null;
        return JSON.parse(new TextDecoder().decode(bytes));
    } catch {
        return null;
    }
}

// Lanza un comando sin esperar (systemctl --user …). argv = array.
export function spawn(argv) {
    try {
        Gio.Subprocess.new(argv, Gio.SubprocessFlags.NONE);
    } catch (e) {
        logError(e, `cortex: no se pudo lanzar ${argv.join(' ')}`);
    }
}

export function forceRefresh() {
    spawn(['systemctl', '--user', 'start', 'cortex.service']);
}

// ⏸/⏵ pausa/reanuda la RECOLECCIÓN (el timer), no "apaga" el widget — mismo contrato que el plasmoide.
export function pauseCollection() {
    spawn(['systemctl', '--user', 'stop', 'cortex.timer', 'cortex.service']);
}

export function resumeCollection() {
    spawn(['systemctl', '--user', 'start', 'cortex.timer']);
    forceRefresh();
}

export const ALIAS_DIR = GLib.getenv('CLAUDE_CONFIG_DIR') || GLib.build_filenamev([GLib.get_home_dir(), '.claude']);

// Como readJson pero con ruta absoluta (mapas de alias en ~/.claude, version.json de la extensión…).
export function readJsonPath(path) {
    try {
        const [ok, bytes] = Gio.File.new_for_path(path).load_contents(null);
        return ok ? JSON.parse(new TextDecoder().decode(bytes)) : null;
    } catch {
        return null;
    }
}

// Escritura atómica (tmp + rename) de texto.
export function writeText(path, text) {
    const f = Gio.File.new_for_path(path);
    try {
        f.get_parent().make_directory_with_parents(null);
    } catch {}
    f.replace_contents(new TextEncoder().encode(text), null, false,
        Gio.FileCreateFlags.REPLACE_DESTINATION, null);
}

// Corre un comando y resuelve con {ok, status, stdout, stderr} — equivalente al engine "executable"
// del plasmoide. Nunca rechaza: un fallo de lanzamiento vuelve como ok=false.
export function run(argv, {cwd = null} = {}) {
    return new Promise(resolve => {
        try {
            const launcher = new Gio.SubprocessLauncher({
                flags: Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
            });
            if (cwd)
                launcher.set_cwd(cwd);
            const proc = launcher.spawnv(argv);
            proc.communicate_utf8_async(null, null, (p, res) => {
                try {
                    const [, stdout, stderr] = p.communicate_utf8_finish(res);
                    const status = p.get_exit_status();
                    resolve({ok: status === 0, status, stdout: stdout || '', stderr: stderr || ''});
                } catch (e) {
                    resolve({ok: false, status: -1, stdout: '', stderr: e.message});
                }
            });
        } catch (e) {
            resolve({ok: false, status: -1, stdout: '', stderr: e.message});
        }
    });
}

// `bash -c '<cmd>'` — para reusar tal cual las líneas de comando del plasmoide.
export function sh(cmd, opts) {
    return run(['bash', '-c', cmd], opts);
}
