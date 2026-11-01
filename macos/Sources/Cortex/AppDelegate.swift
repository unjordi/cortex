import AppKit
import SwiftUI

/// Owns the menu-bar status item and the popover. Polls the cache files every
/// 10s (the plasmoid's cadence) and redraws the two-row pill; the launchd agent
/// does the actual ccusage fetch on its own 5-minute floor, and the popover's
/// "Actualizar ahora" button can force one on demand.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let model = QuotaModel()
    private var timer: Timer?
    private var fetching = false
    /// El fetch EN CURSO lanzado por la propia app (runFetch). Se guarda para poder matarlo al Salir —
    /// "apagar el widget apaga TODO", no solo cerrar la GUI. El fetch del LaunchAgent lo para el bootout.
    private var fetchProc: Process?

    // LaunchAgent del fetcher de cuota (StartInterval 300s + RunAtLoad). Cerrar la GUI NO lo detiene por sí
    // solo → sin esto, el fetch seguía corriendo cada 5 min con el widget "apagado" (unjordi: "cerré el
    // widget pero eso no liberó la Mac"). Salir lo saca con bootout; abrir lo vuelve a cargar con bootstrap.
    private let launchAgentLabel = "io.github.unjordi.cortex"
    private var launchAgentDomain: String { "gui/\(getuid())" }
    private var launchAgentPlistPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist").path
    }

    // The launchd agent refreshes every 5 min, but its StartInterval doesn't
    // reliably catch up after the machine sleeps. If the cache is older than
    // this, the app kicks off its own fetch — only ever when already stale, so
    // the 5-minute polling floor is preserved.
    private let staleThreshold: Double = 330  // 5.5 min
    private lazy var fetchScript = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/bin/cortex-fetch").path

    // Comparar la cuenta ACTIVA (~/.claude.json) contra la del snapshot cada 30s (no en cada tick de
    // 10s — unjordi: "no hace falta que sea tan ansioso"): un cambio de cuenta no es ni "stale" ni
    // "reset pasado", así que sin esto el widget mostraba la cuota de la cuenta anterior hasta 5.5 min.
    private let accountCheckInterval: Double = 30
    private var lastAccountCheck = Date.distantPast
    private lazy var claudeConfigPath: String = {
        let env = ProcessInfo.processInfo.environment
        if let dir = env["CLAUDE_CONFIG_DIR"], !dir.isEmpty { return dir + "/.claude.json" }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json").path
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 520, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(model: model, onRefresh: { [weak self] in self?.forceFetch() })
        )

        // Abrir el widget = cargar TODO su herramiental: (re)carga el LaunchAgent del fetcher (quedó fuera
        // si se salió con el botón de apagar) y dispara una lectura. bootout+bootstrap es idempotente y
        // recarga el timer; RunAtLoad del plist hace la primera lectura, y el refresh() de abajo la pinta.
        reloadLaunchAgent()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    /// Salir del widget APAGA TODO: saca el LaunchAgent del fetcher (para el timer de 5 min y manda SIGTERM
    /// a su fetch en curso) y mata el fetch que lanzó la propia app. Sin esto, "cerrar" dejaba el fetcher
    /// corriendo cada 5 min y recalentando la Mac. Síncrono: el bootout es rápido y debe correr antes de morir.
    func applicationWillTerminate(_ notification: Notification) {
        // bootout: detiene el StartInterval y SIGTERMea el job del agente si está corriendo ahora.
        runLaunchctl(["bootout", "\(launchAgentDomain)/\(launchAgentLabel)"])
        // Fetch en curso lanzado por la app (raro al salir, pero el contrato pide matarlo). terminate() =
        // SIGTERM al /bin/bash del script; cortex-fetch tiene su propio candado del SO (no deja huérfanos
        // encimados). Límite honesto: un npx/ccusage hijo ya lanzado puede terminar su corrida actual.
        if let p = fetchProc, p.isRunning { p.terminate() }
    }

    /// Recarga el LaunchAgent del fetcher (bootout idempotente + bootstrap). Best-effort: un fallo de
    /// launchctl NO debe tumbar el arranque del widget.
    private func reloadLaunchAgent() {
        guard FileManager.default.fileExists(atPath: launchAgentPlistPath) else { return }
        runLaunchctl(["bootout", "\(launchAgentDomain)/\(launchAgentLabel)"])   // puede fallar si no estaba cargado → OK
        runLaunchctl(["bootstrap", launchAgentDomain, launchAgentPlistPath])
    }

    /// Corre /bin/launchctl con los argumentos dados, síncrono, tragándose cualquier error (best-effort).
    private func runLaunchctl(_ args: [String]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = args
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do { try proc.run(); proc.waitUntilExit() } catch { /* best-effort */ }
    }

    private func refresh() {
        model.reload()
        // Avisos del cerebro para la píldora (sin abrir el popover): 🩹 si le falta una pieza,
        // ⬆ si hay versión nueva. El estado del cerebro se lee del ~/.claude real (barato); el de
        // update se leyó en el último chequeo (se refresca abajo, throttle 15 min).
        let heal = !BrainInspector.inspect().isComplete
        // refresh() siempre corre en main (applicationDidFinishLaunching / Timer / main.async);
        // assumeIsolated deja leer la propiedad @MainActor del Updater sin marcar toda la clase.
        let updateAvail = MainActor.assumeIsolated { Updater.shared.updateAvailable }
        if let button = statusItem.button {
            let five = PillImage.RowData(label: "5h",
                                         pct: model.fivePct,
                                         reset: model.snapshot?.five_hour?.resets_at)
            let week = PillImage.RowData(label: "7d",
                                         pct: model.weekPct,
                                         reset: model.snapshot?.weekly?.resets_at)
            button.image = PillImage.render(five: five, week: week,
                                            hasError: model.statusKey == "error",
                                            update: updateAvail, heal: heal,
                                            appearance: button.effectiveAppearance)
            var tip = model.tooltip
            if heal { tip += " · 🩹 al cerebro le falta una pieza" }
            if updateAvail { tip += " · ⬆ actualización disponible" }
            button.toolTip = tip
        }
        // Refresca si el caché superó el piso de 5.5 min, O si una ventana YA pasó su reset (el %
        // cacheado quedó viejo) y el caché tiene >60s — así el 100% no se queda pegado tras el reset.
        if let age = model.ageSeconds, age > staleThreshold || (model.anyResetPassed && age > 60) { runFetch() }
        // Cambio de CUENTA: cada 30s compara la cuenta activa (~/.claude.json) con la del snapshot; si
        // difiere → refetch al instante (runFetch está guardado por `fetching`, un doble disparo es no-op).
        if Date().timeIntervalSince(lastAccountCheck) >= accountCheckInterval {
            lastAccountCheck = Date()
            if let active = activeAccountUuid(), active != model.snapshot?.account_uuid { runFetch() }
        }
        Task { @MainActor in await Updater.shared.checkIfStale() }
    }

    /// Force a real fetch regardless of cache age (from the popover button).
    private func forceFetch() { runFetch() }

    /// UUID de la cuenta Claude ACTIVA, de ~/.claude.json (.oauthAccount.accountUuid). nil si no se
    /// puede leer → en ese caso NO se fuerza fetch (fail-safe: sin señal fiable, no disparar de más).
    private func activeAccountUuid() -> String? {
        guard let data = FileManager.default.contents(atPath: claudeConfigPath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["oauthAccount"] as? [String: Any],
              let uuid = oauth["accountUuid"] as? String, !uuid.isEmpty else { return nil }
        return uuid
    }

    /// Run the fetch script off the main thread; reload the UI when it finishes.
    /// Guarded so only one fetch is ever in flight.
    private func runFetch() {
        guard !fetching, FileManager.default.isExecutableFile(atPath: fetchScript) else { return }
        fetching = true
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [fetchScript]
        // GUI apps inherit a minimal PATH; the script needs jq + ccusage/npx.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        proc.environment = env
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.fetching = false
                self?.fetchProc = nil
                self?.refresh()
            }
        }
        do { try proc.run(); fetchProc = proc } catch { fetching = false }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.reload()
            // Refresca si el caché superó el piso de 5.5 min, O si una ventana YA pasó su reset (el %
        // cacheado quedó viejo) y el caché tiene >60s — así el 100% no se queda pegado tras el reset.
        if let age = model.ageSeconds, age > staleThreshold || (model.anyResetPassed && age > 60) { runFetch() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
