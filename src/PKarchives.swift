import SwiftUI

func loadEnv(_ key: String) -> String? {
    // 1. Env var directe
    if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty { return env }
    // 2. Fichier secrets/.env à côté du script ou du bundle
    let appDir = Bundle.main.resourcePath ?? ""
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let envPaths = [
        "\(appDir)/../Resources/secrets/.env",
        "\(home)/Documents/GitHub/PROJECTS/PKarchives/secrets/.env",
        "\(home)/.config/pkarchives/secrets/.env"
    ]
    for path in envPaths {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { continue }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let eq = trimmed.firstIndex(of: "=") else { continue }
            let k = String(trimmed[trimmed.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
            var v = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if k == key {
                if (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")) {
                    v = String(v.dropFirst().dropLast())
                }
                return v
            }
        }
    }
    return nil
}

let driveURL: String = {
    guard let id = loadEnv("PKARCHIVES_DRIVE_FOLDER_ID"), !id.isEmpty else {
        return "https://drive.google.com"
    }
    return "https://drive.google.com/drive/folders/\(id)"
}()

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "📦"
            button.action = #selector(statusClicked)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ouvrir PKarchives", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Archiver (fichiers)", action: #selector(quickArchiveFiles), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Archiver (tout)", action: #selector(quickArchiveAll), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Ouvrir Google Drive", action: #selector(openDrive), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quitter", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu

        showWindow()
    }

    @objc func statusClicked() {
        if let window = window, window.isVisible {
            window.orderOut(nil)
        } else {
            showWindow()
        }
    }

    @objc func showWindow() {
        if window == nil {
            let hostingView = NSHostingView(rootView: ContentView())
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
                             styleMask: [.titled, .closable, .miniaturizable],
                             backing: .buffered, defer: false)
            w.contentView = hostingView
            w.title = "PKarchives"
            w.backgroundColor = NSColor.windowBackgroundColor
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quickArchiveFiles() { showWindow(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NotificationCenter.default.post(name: .startArchive, object: nil, userInfo: ["mode": "files"]) } }
    @objc func quickArchiveAll() { showWindow(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NotificationCenter.default.post(name: .startArchive, object: nil, userInfo: ["mode": "all"]) } }
    @objc func openDrive() { if let url = URL(string: driveURL) { NSWorkspace.shared.open(url) } }
    @objc func quitApp() { NSApp.terminate(nil) }
}

extension Notification.Name {
    static let startArchive = Notification.Name("startArchive")
}

@main
struct PKarchivesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

struct ContentView: View {
    @State private var output = ""
    @State private var status = "Prêt"
    @State private var isRunning = false
    @State private var selectedMode = "files"
    @State private var process: Process?
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("📦 PKarchives")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Output
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    Text(output)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .id("bottom")
                }
                .background(Color(red: 0.07, green: 0.07, blue: 0.09))
                .onChange(of: output) {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            Divider()

            // Status bar
            HStack {
                Image(systemName: isRunning ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(isRunning ? .orange : .green)
                    .font(.system(size: 11))
                Text(status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Controls
            HStack(spacing: 10) {
                Picker("", selection: $selectedMode) {
                    Text("Fichiers").tag("files")
                    Text("Fichiers + Dossiers").tag("all")
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .disabled(isRunning)

                Spacer()

                Button(action: openDrive) {
                    Label("Google Drive", systemImage: "folder.fill")
                }
                .buttonStyle(.bordered)
                .tint(.cyan)

                if isRunning {
                    Button("Annuler") { cancelRun() }
                        .buttonStyle(.bordered)
                        .tint(.red)
                } else {
                    Button(action: { startArchive(mode: selectedMode) }) {
                        Label("Archiver", systemImage: "arrow.up.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 780, height: 520)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .startArchive)) { notification in
            if let mode = notification.userInfo?["mode"] as? String, !isRunning {
                startArchive(mode: mode)
            }
        }
    }

    func openDrive() { if let url = URL(string: driveURL) { NSWorkspace.shared.open(url) } }

    func cancelRun() {
        process?.terminate()
        isRunning = false
        status = "Annulé"
        output += "\n🛑 Annulé par l'utilisateur.\n"
        timer?.invalidate()
    }

    func startArchive(mode: String) {
        selectedMode = mode
        runArchive()
    }

    func runArchive() {
        isRunning = true
        output = ""
        status = "Préparation..."

        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Cherche le script : variable d'env > app bundle > ~/.config/pkarchives/
        let appDir = Bundle.main.resourcePath ?? ""
        let envScript = ProcessInfo.processInfo.environment["PKARCHIVES_SCRIPT"] ?? ""
        let candidates = [
            envScript,
            "\(appDir)/../Resources/archive.sh",
            "\(appDir)/../MacOS/archive.sh",
            "\(home)/.config/pkarchives/archive.sh"
        ].filter { !$0.isEmpty }
        guard let scriptPath = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            output = "❌ Script archive.sh introuvable"
            isRunning = false
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [scriptPath, selectedMode]

        // Pass config as env vars
        var env = ProcessInfo.processInfo.environment
        if let v = loadEnv("PKARCHIVES_DRIVE_FOLDER_ID") { env["PKARCHIVES_DRIVE_FOLDER_ID"] = v }
        env["PKARCHIVES_STATUS_FILE"] = statusFile
        if let v = loadEnv("PKARCHIVES_DESKTOP_PATH"), !v.isEmpty { env["PKARCHIVES_DESKTOP_PATH"] = v }
        if let v = loadEnv("PKARCHIVES_DESKTOP_LINK_NAME"), !v.isEmpty { env["PKARCHIVES_DESKTOP_LINK_NAME"] = v }
        if let v = loadEnv("PKARCHIVES_RCLONE_REMOTE"), !v.isEmpty { env["PKARCHIVES_RCLONE_REMOTE"] = v }
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        self.process = proc

        // Poll status file
        let statusFile = FileManager.default.temporaryDirectory.appendingPathComponent("pkarchives_\(ProcessInfo.processInfo.processIdentifier)").path
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            if let data = try? Data(contentsOf: URL(fileURLWithPath: statusFile)),
               let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !s.isEmpty {
                self.status = s
            }
        }

        proc.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.isRunning = false
                self.process = nil
                self.timer?.invalidate()
                self.status = "Terminé"
                try? FileManager.default.removeItem(atPath: statusFile)
            }
        }

        do { try proc.run() } catch {
            output = "❌ Erreur: \(error.localizedDescription)"
            isRunning = false
            status = "Erreur"
            timer?.invalidate()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let handle = outPipe.fileHandleForReading
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                if let str = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { output += stripAnsi(str) }
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let handle = errPipe.fileHandleForReading
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                if let str = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { output += stripAnsi(str) }
                }
            }
        }
    }
}

func stripAnsi(_ text: String) -> String {
    var result = text
    result = result.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
    result = result.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[A-Za-z]", with: "", options: .regularExpression)
    return result
}
