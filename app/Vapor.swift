// Vapor: installs, updates and removes Vapor Steam (Windows Steam running on Wine), changes its
// settings, and starts or quits Steam. It runs the same scripts as the command line, bundled
// inside the app, and checks GitHub for new versions of itself.
import AppKit
import Network
import SwiftUI

@main
struct VaporApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = Model.shared

    var body: some Scene {
        Window("Vapor", id: "main") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                UpdateMenuItem(model: model).disabled(model.busy != nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // Quitting halfway through installing, updating or uninstalling could leave it half done.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard Model.shared.working else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Vapor is still working"
        alert.informativeText = "Wait until it finishes, then quit."
        alert.runModal()
        return .terminateCancel
    }
}

/// The settings, in the order run-steam.sh takes them.
struct Settings: Equatable {
    var retina = false, dxmt = false, hud = false, metalfx = false
    var fpsLimit = 0        // frames per second: 0 for no limit, 30 or 60
    var overlay = false     // Steam's in-game overlay

    init() {}

    /// Reads the "0 1 0 1 30 0"-style values printed by the state query.
    init?(_ text: Substring) {
        let values = text.split(separator: " ").compactMap { Int($0) }
        guard values.count == 6 else { return nil }
        (retina, dxmt, hud, metalfx) = (values[0] == 1, values[1] == 1, values[2] == 1, values[3] == 1)
        (fpsLimit, overlay) = (values[4], values[5] == 1)
    }

    var arguments: [String] {
        [retina, dxmt, hud, metalfx].map { $0 ? "1" : "0" } + [String(fpsLimit), overlay ? "1" : "0"]
    }

    /// MetalFX only takes effect with DXMT at scaled resolution.
    var metalfxActive: Bool { metalfx && dxmt && !retina }
}

/// A yes-or-no question to answer before an action.
struct Confirmation {
    let title: String
    let message: String
    let yes: String
    var no = "No"
    var destructive = false
    let action: () -> Void
}

// Window state lives here rather than in @State: in current SDKs @State is a macro whose plugin
// only comes with Xcode, and this app builds with the Command Line Tools alone.
final class Model: ObservableObject {
    static let shared = Model()

    @Published var loaded = false
    @Published var installed = false
    @Published var moveReady = false       // it's where an earlier version put it, which Spotlight searches
    @Published var updateReady = false {   // newer wrapper and Wine versions are pinned
        didSet { showUpdateDot() }
    }
    @Published var wineRunning = false
    @Published var steamRunning = false
    @Published var game: String?           // a running game, e.g. "Game.exe on DXMT"
    @Published var saved = Settings()      // what Steam starts with
    @Published var chosen = Settings()     // what the switches show
    @Published var busy: String?           // the action in progress
    @Published var working = false         // installing, updating or uninstalling: don't quit
    @Published var message = ""            // the last action's output
    @Published var log = ""                // setup's output while it runs
    @Published var confirmation: Confirmation?
    @Published var appUpdate: String? {    // a newer version of Vapor on GitHub
        didSet { showUpdateDot() }
    }

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private let scripts = Bundle.main.resourceURL!.appendingPathComponent("scripts").path
    private var saving = false
    private var logLines: [String] = []
    private var logLine = ""
    private var timer: Timer?
    private let network = NWPathMonitor()
    private var online = false
    private var checkedForAppUpdate = false
    private var dotShown = false

    var pendingChanges: Bool { chosen != saved }
    var gameName: String? { game?.components(separatedBy: " on ").first }

    // Prints one line per fact: "installed", "move", "update", "settings 0 1 0 1 30 0", "wine",
    // "steam", "game Name.exe on DXMT".
    private static let stateQuery = """
        source "$1/config.sh"
        if [[ -x $LAUNCHER && -f $STEAM_DIR/steam.exe ]]; then
          echo installed
          [[ $APP == $INSTALL_PATH ]] || echo move
          needs_update && echo update
          echo "settings $(get_retina) $(get_dxmt) $(get_hud) $(get_metalfx) $(get_fps_limit) $(get_overlay)"
        fi
        pgrep -x wineserver >/dev/null && echo wine
        pgrep -f 'steam\\.exe' >/dev/null && echo steam
        running_games | sed -n '1s/^/game /p'
        """

    private static let runningQuery = """
        pgrep -x wineserver >/dev/null && echo wine
        pgrep -f 'steam\\.exe' >/dev/null && echo steam
        true
        """

    private static let saveCommand = """
        source "$1/config.sh"
        pgrep -x wineserver >/dev/null && { echo "Steam is running; quit it to change settings."; exit 1; }
        save_settings "${@:2}"
        """

    private init() {
        refresh()
        // Notices Steam starting or quitting, e.g. from Steam's own menu. The full check is slower,
        // so it only runs when that changes or the window comes to the front.
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.checkRunning()
        }
        // Look for a new version of Vapor each time it opens, once the Mac is online.
        network.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            online = path.status == .satisfied
            if online && !checkedForAppUpdate {
                checkedForAppUpdate = true
                checkForAppUpdate(manual: false)
            }
        }
        network.start(queue: .main)
    }

    func refresh() {
        zsh(["-c", Self.stateQuery, "zsh", scripts]) { [self] _, output in
            let lines = output.split(separator: "\n")
            installed = lines.contains("installed")
            moveReady = lines.contains("move")
            updateReady = lines.contains("update")
            wineRunning = lines.contains("wine")
            steamRunning = lines.contains("steam")
            game = lines.first { $0.hasPrefix("game ") }.map { String($0.dropFirst(5)) }
            if let line = lines.first(where: { $0.hasPrefix("settings ") }),
               let settings = Settings(line.dropFirst(9)) {
                // Keep a change that's still being saved, unless Steam started and locked the settings.
                if !pendingChanges || wineRunning { chosen = settings }
                saved = settings
            }
            loaded = true
            saveIfIdle()
        }
    }

    private func checkRunning() {
        guard loaded, busy == nil else { return }
        zsh(["-c", Self.runningQuery]) { [self] _, output in
            let lines = output.split(separator: "\n")
            if lines.contains("wine") != wineRunning || lines.contains("steam") != steamRunning {
                refresh()
            }
        }
    }

    /// Saves the switches straight away. They're locked while Steam runs, since it only reads them at start.
    func saveIfIdle() {
        guard installed, !wineRunning, pendingChanges, busy == nil, !saving else { return }
        saving = true
        let settings = chosen
        zsh(["-c", Self.saveCommand, "zsh", scripts] + settings.arguments) { [self] status, output in
            saving = false
            if status == 0 { saved = settings } else { chosen = saved }
            message = output
            saveIfIdle()  // the switches may have changed while saving
        }
    }

    // MARK: Steam

    func startSteam() {
        run("Starting Steam…", "run-steam.sh", chosen.arguments) { [self] in
            // The launcher starts Wine in the background; wait for it so the status is right.
            busy = "Starting Steam…"
            zsh(["-c", "for i in {1..20}; do pgrep -x wineserver >/dev/null && break; sleep 1; done"]) { [self] _, _ in
                busy = nil
                refresh()
            }
        }
    }

    /// Brings back Steam's window, which closing it only hides.
    func showSteam() {
        run("Opening Steam…", "run-steam.sh")
    }

    /// `closingGame` answers close-wine.sh's question about a running game.
    func quitSteam(closingGame: Bool) {
        run("Quitting Steam…", "close-wine.sh", input: closingGame ? "y\n" : "n\n")
    }

    // MARK: Install, update, clear caches, uninstall

    /// Installs Vapor Steam, moves it from where an earlier version put it, or updates it: setup.sh
    /// does whichever is needed.
    func runSetup() {
        let (label, done) = !installed
            ? ("Installing…", "Installed. Start Steam and sign in to your Steam account.")
            : moveReady
                ? ("Moving…", "Moved. Only Vapor shows up in Spotlight now, and Steam, your games and settings are as you left them.")
                : ("Updating…", "Updated. Steam, your games and settings are as you left them.")
        busy = label
        working = true
        message = ""
        logLines = []
        logLine = ""
        log = ""
        zsh(["-c", "arch -x86_64 /usr/bin/true"]) { [self] status, _ in
            if status == 0 { return setup(done) }
            // Rosetta 2 runs the Windows programs. Installing it needs an administrator's password.
            appendLog("Installing Rosetta 2 (this accepts Apple's Rosetta license)...\n")
            let command = "do shell script \"/usr/sbin/softwareupdate --install-rosetta --agree-to-license\" with administrator privileges"
            zsh(["-c", "/usr/bin/osascript -e \"$1\"", "zsh", command]) { [self] status, output in
                if status == 0 { return setup(done) }
                finish("Rosetta 2 wasn't installed. \(output)")
            }
        }
    }

    private func setup(_ done: String) {
        zsh(["\(scripts)/setup.sh"], progress: { [self] in appendLog($0) }) { [self] status, _ in
            finish(status == 0 ? done : "Setup stopped; the details are above. Try again, or copy the diagnostics for a bug report.")
        }
    }

    func askClearCaches() {
        sizeOf("\"${CACHE_DIRS[@]}\"") { [self] size in
            confirmation = Confirmation(
                title: "Clear the shader caches?",
                message: "This deletes \(size) of shader caches. Games rebuild them as you play, so expect some stutter the first time through each area.",
                yes: "Yes, Clear Them") { [self] in
                    run("Clearing caches…", "clear-caches.sh", input: "y\n")
                }
        }
    }

    func askUninstall() {
        sizeOf("\"$INSTALL_PATH\" \"${OLD_APPS[@]}\" \"${CACHE_DIRS[@]}\"") { [self] size in
            confirmation = Confirmation(
                title: "Uninstall Vapor Steam?",
                message: "This deletes \(size): Steam, all installed games, your Steam and game sign-ins, any saves stored only on this Mac, and the shader caches. Saves in Steam Cloud stay online. This can't be undone.",
                yes: "Yes, Uninstall", destructive: true) { [self] in uninstall() }
        }
    }

    private func uninstall() {
        busy = "Uninstalling…"
        working = true
        message = ""
        zsh(["\(scripts)/uninstall.sh"], input: "y\n") { [self] status, output in
            finish(output)
            guard status == 0 else { return }
            confirmation = Confirmation(
                title: "Move Vapor to the Trash too?",
                message: "Vapor Steam is gone. Keep this app to install it again later, or move it to the Trash.",
                yes: "Move to Trash", no: "Keep Vapor") {
                    NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, _ in
                        DispatchQueue.main.async { NSApp.terminate(nil) }
                    }
                }
        }
    }

    /// Works out the size of the given paths (zsh words, evaluated after sourcing config.sh).
    private func sizeOf(_ paths: String, then show: @escaping (String) -> Void) {
        busy = "Checking sizes…"
        zsh(["-c", "source \"$1/config.sh\"; size_of \(paths)", "zsh", scripts]) { [self] _, output in
            busy = nil
            show(output)
        }
    }

    private func finish(_ text: String) {
        busy = nil
        working = false
        message = text
        refresh()
    }

    // MARK: Diagnostics and updates to Vapor itself

    func copyDiagnostics() {
        zsh(["\(scripts)/diagnostics.sh"]) { [self] _, output in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(output, forType: .string)
            message = "Copied the diagnostics. Paste them into a bug report on GitHub; they contain no names, file paths or accounts."
        }
    }

    /// Asks GitHub for the latest version. `manual` reports the result even when there's nothing new.
    func checkForAppUpdate(manual: Bool) {
        guard online else {
            if manual { message = "Couldn't check for updates: this Mac isn't connected to the internet." }
            return
        }
        zsh(["\(scripts)/update-app.sh", "check"]) { [self] status, output in
            guard status == 0, !output.isEmpty else {
                if manual { message = "Couldn't check for updates: \(output)" }
                return
            }
            if output.compare(version, options: .numeric) == .orderedDescending {
                appUpdate = output
                if manual { askAppUpdate(output) }
            } else {
                appUpdate = nil
                if manual { message = "Vapor \(version) is the latest version." }
            }
        }
    }

    /// Puts a red dot on Vapor's Dock icon while an update is waiting.
    private func showUpdateDot() {
        let show = appUpdate != nil || updateReady
        guard show != dotShown else { return }
        dotShown = show
        let dock = NSApp.dockTile
        if show {
            let view = NSImageView(frame: NSRect(origin: .zero, size: dock.size))
            view.image = Self.iconWithDot()
            view.imageScaling = .scaleProportionallyUpOrDown
            dock.contentView = view
        } else {
            dock.contentView = nil
        }
        dock.display()
    }

    /// Vapor's icon with a red dot on the top right corner of its tile, which fills the middle 80%.
    private static func iconWithDot() -> NSImage {
        let icon = NSApp.applicationIconImage ?? NSImage()
        return NSImage(size: NSSize(width: 256, height: 256), flipped: false) { rect in
            icon.draw(in: rect)
            let size = rect.width * 0.22
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.width * 0.85 - size / 2, y: rect.height * 0.85 - size / 2,
                                        width: size, height: size)).fill()
            return true
        }
    }

    func askAppUpdate(_ latest: String) {
        confirmation = Confirmation(
            title: "Update Vapor to \(latest)?",
            message: "Vapor downloads it from GitHub, checks it against the release's checksum, and restarts. Vapor Steam, your games and settings aren't touched.",
            yes: "Yes, Update") { [self] in updateApp(to: latest) }
    }

    private func updateApp(to latest: String) {
        busy = "Downloading Vapor \(latest)…"
        working = true
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vapor-\(latest)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        zsh(["\(scripts)/update-app.sh", "download", latest, dir.path]) { [self] status, output in
            guard status == 0 else { return finish("Couldn't update Vapor: \(output)") }
            // Replacing the app has to happen after it quits, so hand over to a separate process.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["\(scripts)/update-app.sh", "replace", output, Bundle.main.bundlePath,
                                 String(ProcessInfo.processInfo.processIdentifier)]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                working = false
                NSApp.terminate(nil)
            } catch {
                finish("Couldn't update Vapor: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Running scripts

    private func appendLog(_ text: String) {
        for character in text {
            switch character {
            case "\n", "\r\n": logLines.append(logLine); logLine = ""
            case "\r": logLine = ""  // progress bars redraw their line
            default: logLine.append(character)
            }
        }
        log = (logLines.suffix(200) + [logLine]).joined(separator: "\n")
    }

    /// Runs one of the bundled scripts, shows `label` meanwhile and its output afterwards, then
    /// runs `next` if it succeeded.
    private func run(_ label: String, _ script: String, _ arguments: [String] = [], input: String = "",
                     then next: (() -> Void)? = nil) {
        busy = label
        message = ""
        zsh(["\(scripts)/\(script)"] + arguments, input: input) { [self] status, output in
            busy = nil
            message = output
            if status == 0, let next { next() } else { refresh() }
        }
    }
}

/// "Check for Updates…", or "Update to Vapor 2.2.0…" once a newer version is known.
struct UpdateMenuItem: View {
    @ObservedObject var model: Model

    var body: some View {
        if let latest = model.appUpdate {
            Button("Update to Vapor \(latest)…") { model.askAppUpdate(latest) }
        } else {
            Button("Check for Updates…") { model.checkForAppUpdate(manual: true) }
        }
    }
}

/// Runs zsh with `arguments` and `input` on stdin, then calls `done` on the main thread with the
/// exit status and output. `progress` receives the output as it arrives.
func zsh(_ arguments: [String], input: String = "", progress: ((String) -> Void)? = nil,
         done: @escaping (Int32, String) -> Void) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = arguments
    let output = Pipe(), stdin = Pipe()
    process.standardOutput = output
    process.standardError = output
    process.standardInput = stdin
    // Written before the script starts, so it can't exit before reading it.
    stdin.fileHandleForWriting.write(Data(input.utf8))
    try? stdin.fileHandleForWriting.close()

    var text = ""
    output.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if data.isEmpty { handle.readabilityHandler = nil; return }
        let chunk = String(decoding: data, as: UTF8.self)
        DispatchQueue.main.async {
            text += chunk
            progress?(chunk)
        }
    }
    process.terminationHandler = { process in
        // Programs the script started in the background (Wine) can keep the output open, so
        // don't wait for it to close; just give the script's last lines a moment to arrive.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            output.fileHandleForReading.readabilityHandler = nil
            done(process.terminationStatus, text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    do {
        try process.run()
    } catch {
        output.fileHandleForReading.readabilityHandler = nil
        done(-1, error.localizedDescription)
    }
}

struct ContentView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if let latest = model.appUpdate {
                banner("Vapor \(latest) is available.", button: "Update Vapor", enabled: model.busy == nil) {
                    model.askAppUpdate(latest)
                }
            }
            if !model.loaded {
                ProgressView().frame(maxWidth: .infinity).padding(40)
            } else if model.installed {
                if model.moveReady {
                    banner(model.wineRunning
                           ? "Vapor Steam can move to a hidden folder, so only Vapor shows up in Spotlight. Quit Steam to move it."
                           : "Vapor Steam can move to a hidden folder, so only Vapor shows up in Spotlight. Steam, your games and settings stay.",
                           button: "Move", enabled: model.busy == nil && !model.wineRunning) {
                        model.runSetup()
                    }
                } else if model.updateReady {
                    banner(model.wineRunning
                           ? "An update for Wine and the translators is ready. Quit Steam to install it."
                           : "An update for Wine and the translators is ready. Steam, your games and settings stay.",
                           button: "Update", enabled: model.busy == nil && !model.wineRunning) {
                        model.runSetup()
                    }
                }
                settings
            } else {
                installer
            }
            if !model.log.isEmpty { logView }
            Divider()
            footer
        }
        .frame(width: 480)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
        .alert(Text(model.confirmation?.title ?? ""),
               isPresented: Binding(get: { model.confirmation != nil }, set: { if !$0 { model.confirmation = nil } }),
               presenting: model.confirmation) { confirmation in
            Button(confirmation.yes, role: confirmation.destructive ? .destructive : nil) { confirmation.action() }
            Button(confirmation.no, role: .cancel) {}
        } message: { confirmation in
            Text(confirmation.message)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(model.wineRunning ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(status).font(.headline)
                if let game = model.game {
                    Text("Running \(game)").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if let busy = model.busy {
                ProgressView().controlSize(.small)
                Text(busy).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var status: String {
        if !model.loaded { return "Checking…" }
        if !model.installed { return "Vapor Steam isn't installed" }
        if model.steamRunning { return "Steam is running" }
        if model.wineRunning { return "Wine is running" }
        return "Steam is closed"
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            row("Resolution", "Scaled is faster. Retina is sharper, but much heavier.") {
                Picker("Resolution", selection: $model.chosen.retina) {
                    Text("Scaled").tag(false)
                    Text("Retina").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)
            }
            row("Translator", "DXMT runs DirectX 10 and 11. D3DMetal also runs DirectX 12.") {
                Picker("Translator", selection: $model.chosen.dxmt) {
                    Text("DXMT").tag(true)
                    Text("D3DMetal").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)
            }
            row("FPS overlay", "Shows the frame rate and frame timing in games.") {
                Toggle("FPS overlay", isOn: $model.chosen.hud).toggleStyle(.switch).labelsHidden()
            }
            row("MetalFX upscaling", metalfxNote, warning: model.chosen.metalfx && !model.chosen.metalfxActive) {
                Toggle("MetalFX upscaling", isOn: $model.chosen.metalfx).toggleStyle(.switch).labelsHidden()
            }
            row("Frame rate limit", "Caps games' frame rate. 30 keeps a MacBook Air cooler and steadier.") {
                Picker("Frame rate limit", selection: $model.chosen.fpsLimit) {
                    Text("Off").tag(0)
                    Text("60").tag(60)
                    Text("30").tag(30)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)
            }
            row("Steam overlay", "Steam's Shift+Tab overlay in games. Opening it can freeze a game, so invite friends from Steam's window.") {
                Toggle("Steam overlay", isOn: $model.chosen.overlay).toggleStyle(.switch).labelsHidden()
            }
            if model.wineRunning {
                Text("Settings are locked while Steam is running. Quit Steam to change them.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else if !model.message.isEmpty {
                messageView
            }
        }
        .disabled(model.busy != nil || model.wineRunning)
        .padding(20)
        .onChange(of: model.chosen) { model.saveIfIdle() }
    }

    private var metalfxNote: String {
        if model.chosen.metalfx && !model.chosen.metalfxActive {
            return "Inactive: it needs DXMT at scaled resolution."
        }
        return "Upscales each frame for a sharper picture at scaled resolution. Works with DXMT."
    }

    private var installer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Install Vapor Steam to play Windows games from Steam on this Mac.")
            Text("It downloads Wine and Windows Steam, and takes a few minutes. Allow 5 GB of space, plus your games. If Rosetta 2 is missing, it's installed too, which accepts Apple's Rosetta license and asks for your password.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !model.message.isEmpty { messageView }
        }
        .padding(20)
    }

    private var messageView: some View {
        Text(model.message)
            .font(.callout)
            .foregroundColor(.secondary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(model.log)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .id("log")
            }
            .frame(height: 160)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding([.horizontal, .bottom], 20)
            .onChange(of: model.log) { proxy.scrollTo("log", anchor: .bottom) }
        }
    }

    private var footer: some View {
        HStack {
            Menu("More") {
                UpdateMenuItem(model: model)
                Button("Clear Caches…") { model.askClearCaches() }
                    .disabled(!model.installed || model.wineRunning)
                Button("Copy Diagnostics") { model.copyDiagnostics() }
                Divider()
                Button("Uninstall Vapor Steam…") { model.askUninstall() }
                    .disabled(!model.installed || model.wineRunning)
                Divider()
                Button("Vapor on GitHub") { NSWorkspace.shared.open(URL(string: "https://github.com/rhas1/Vapor")!) }
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .overlay(alignment: .topTrailing) {
                // Points to "Update to Vapor…" in the menu.
                if model.appUpdate != nil {
                    Circle().fill(Color.red).frame(width: 8, height: 8).offset(x: 6, y: -3)
                }
            }
            .help(model.appUpdate.map { "Vapor \($0) is available" } ?? "")
            Spacer()
            if !model.loaded {
                EmptyView()
            } else if !model.installed {
                Button("Install") { model.runSetup() }
                    .keyboardShortcut(.defaultAction)
            } else if model.wineRunning {
                Button("Show Steam") { model.showSteam() }
                Button("Quit Steam") {
                    confirmIfPlaying { model.quitSteam(closingGame: $0) }
                }
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Start Steam") { model.startSteam() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .disabled(model.busy != nil)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func banner(_ text: String, button: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(button, action: action).disabled(!enabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.12))
    }

    private func row<Control: View>(_ title: String, _ detail: String, warning: Bool = false,
                                    @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(warning ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            control()
        }
    }

    /// Asks before quitting Steam would close a running game; `action` gets whether to close it.
    private func confirmIfPlaying(_ action: @escaping (Bool) -> Void) {
        guard let name = model.gameName else { return action(false) }
        model.confirmation = Confirmation(
            title: "Close \(name)?",
            message: "Unsaved progress will be lost.",
            yes: "Quit Steam", destructive: true) { action(true) }
    }
}
