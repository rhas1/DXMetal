// DXMetal Settings: a window for installing DXMetal, choosing its settings and starting or
// quitting Steam. It runs the same scripts as the command line, bundled inside the app.
import AppKit
import SwiftUI

@main
struct DXMetalSettingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = Model()

    var body: some Scene {
        Window("DXMetal Settings", id: "main") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// The four settings, in the order run-steam.sh takes them.
struct Settings: Equatable {
    var retina = false, dxmt = false, hud = false, metalfx = false

    init() {}

    /// Reads the "0101"-style digits printed by the state query.
    init?(_ digits: Substring) {
        let values = digits.map { $0 == "1" }
        guard values.count == 4 else { return nil }
        (retina, dxmt, hud, metalfx) = (values[0], values[1], values[2], values[3])
    }

    var arguments: [String] { [retina, dxmt, hud, metalfx].map { $0 ? "1" : "0" } }

    /// MetalFX only takes effect with DXMT at scaled resolution.
    var metalfxActive: Bool { metalfx && dxmt && !retina }
}

/// An action waiting for "Close the game?" to be answered; `action` gets the answer.
struct Confirmation {
    let button: String
    let action: (Bool) -> Void
}

// Window state lives here rather than in @State: in current SDKs @State is a macro whose plugin
// only comes with Xcode, and this app builds with the Command Line Tools alone.
final class Model: ObservableObject {
    @Published var loaded = false
    @Published var installed = false
    @Published var wineRunning = false
    @Published var steamRunning = false
    @Published var game: String?        // a running game, e.g. "Game.exe on DXMT"
    @Published var saved = Settings()   // what Steam starts with
    @Published var chosen = Settings()  // what the switches show
    @Published var busy: String?        // the action in progress
    @Published var message = ""         // the last action's output
    @Published var log = ""             // setup's output while installing
    @Published var confirmation: Confirmation?

    private let scripts = Bundle.main.resourceURL!.appendingPathComponent("scripts").path
    private var saving = false
    private var logLines: [String] = []
    private var logLine = ""
    private var timer: Timer?

    var pendingChanges: Bool { chosen != saved }
    var gameName: String? { game?.components(separatedBy: " on ").first }

    // Prints one line per fact: "installed", "settings 0101", "wine", "steam", "game Name.exe on DXMT".
    private static let stateQuery = """
        source "$1/config.sh"
        [[ -x $LAUNCHER && -f $STEAM_DIR/steam.exe ]] || exit 0
        echo installed
        echo "settings $(get_retina)$(get_dxmt)$(get_hud)$(get_metalfx)"
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

    init() {
        refresh()
        // Notices Steam starting or quitting, e.g. from Steam's own menu. The full check is slower,
        // so it only runs when that changes or the window comes to the front.
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.checkRunning()
        }
    }

    func refresh() {
        zsh(["-c", Self.stateQuery, "zsh", scripts]) { [self] _, output in
            let lines = output.split(separator: "\n")
            installed = lines.contains("installed")
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

    /// `closingGame` answers close-wine.sh's question about a running game.
    func quitSteam(closingGame: Bool) {
        run("Quitting Steam…", "close-wine.sh", input: closingGame ? "y\n" : "n\n")
    }

    func install() {
        busy = "Installing…"
        message = ""
        logLines = []
        logLine = ""
        log = ""
        zsh(["-c", "arch -x86_64 /usr/bin/true"]) { [self] status, _ in
            if status == 0 { return runSetup() }
            // Rosetta 2 runs the Windows programs. Installing it needs an administrator's password.
            appendLog("Installing Rosetta 2 (this accepts Apple's Rosetta license)...\n")
            let command = "do shell script \"/usr/sbin/softwareupdate --install-rosetta --agree-to-license\" with administrator privileges"
            zsh(["-c", "/usr/bin/osascript -e \"$1\"", "zsh", command]) { [self] status, output in
                if status == 0 { return runSetup() }
                busy = nil
                message = "Rosetta 2 wasn't installed. \(output)"
            }
        }
    }

    private func runSetup() {
        zsh(["\(scripts)/setup.sh"], progress: { [self] in appendLog($0) }) { [self] status, _ in
            busy = nil
            message = status == 0
                ? "Installed. Start Steam and sign in to your Steam account."
                : "Setup stopped; the details are above. You can try Install again."
            refresh()
        }
    }

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
            if !model.loaded {
                ProgressView().frame(maxWidth: .infinity).padding(40)
            } else if model.installed {
                settings
                Divider()
                buttons
            } else {
                installer
            }
        }
        .frame(width: 460)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
        .alert(Text("Close \(model.gameName ?? "the game")?"),
               isPresented: Binding(get: { model.confirmation != nil }, set: { if !$0 { model.confirmation = nil } }),
               presenting: model.confirmation) { confirmation in
            Button(confirmation.button, role: .destructive) { confirmation.action(true) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Unsaved progress will be lost.")
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
        if !model.installed { return "DXMetal isn't installed" }
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
            row("Translator", "D3DMetal runs DirectX 11 and 12. DXMT runs DirectX 10 and 11, and is sometimes faster.") {
                Picker("Translator", selection: $model.chosen.dxmt) {
                    Text("D3DMetal").tag(false)
                    Text("DXMT").tag(true)
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
            if model.wineRunning {
                Text("Settings are locked while Steam is running. Quit Steam to change them.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else if !model.message.isEmpty {
                Text(model.message)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
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

    private var buttons: some View {
        HStack {
            Spacer()
            if model.wineRunning {
                Button("Quit Steam") {
                    confirmIfPlaying("Quit Steam") { model.quitSteam(closingGame: $0) }
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

    private var installer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Install DXMetal to play Windows games from Steam on this Mac.")
            Text("It downloads Wine and Windows Steam, and takes a few minutes. Allow 4 GB of space, plus your games. If Rosetta 2 is missing, it's installed too, which accepts Apple's Rosetta license and asks for your password.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !model.log.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(model.log)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .id("log")
                    }
                    .frame(height: 180)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onChange(of: model.log) { proxy.scrollTo("log", anchor: .bottom) }
                }
            }
            if !model.message.isEmpty {
                Text(model.message).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Install") { model.install() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.busy != nil)
            }
        }
        .padding(20)
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

    /// Asks before an action that would close a running game; `action` gets the answer.
    private func confirmIfPlaying(_ button: String, _ action: @escaping (Bool) -> Void) {
        if model.game == nil {
            action(false)
        } else {
            model.confirmation = Confirmation(button: button, action: action)
        }
    }
}
