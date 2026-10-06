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
