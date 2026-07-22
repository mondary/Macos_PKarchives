import SwiftUI
import Charts

struct ArchiveRun: Codable, Identifiable {
    let date: Date
    let mode: String
    let items: Int
    let success: Int
    let bytesFreed: Int64
    let mountOK: Bool

    var id: String { "\(date.timeIntervalSince1970)-\(mode)" }

    enum CodingKeys: String, CodingKey {
        case date, mode, items, success
        case bytesFreed = "bytes_freed"
        case mountOK = "mount_ok"
    }
}

func historyURL() -> URL {
    let base = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/pkarchives", isDirectory: true)
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base.appendingPathComponent("history.json")
}

func loadHistory() -> [ArchiveRun] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    guard let data = try? Data(contentsOf: historyURL()),
          let runs = try? decoder.decode([ArchiveRun].self, from: data) else { return [] }
    return runs
}

func saveHistory(_ runs: [ArchiveRun]) {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(Array(runs.prefix(50))) else { return }
    try? data.write(to: historyURL(), options: .atomic)
}

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
                return v.isEmpty ? nil : v
            }
        }
    }
    return nil
}

func rcloneBinary() -> String {
    if let configured = loadEnv("PKARCHIVES_RCLONE_BINARY"), !configured.isEmpty {
        return configured
    }
    let bundled = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/pkarchives/bin/rclone").path
    return FileManager.default.isExecutableFile(atPath: bundled) ? bundled : "rclone"
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
    @State private var uploadProgress = 0.0
    @State private var history = loadHistory()
    @State private var page = "dashboard"
    @State private var driveFolderID = loadEnv("PKARCHIVES_DRIVE_FOLDER_ID") ?? ""
    @State private var desktopPath = loadEnv("PKARCHIVES_DESKTOP_PATH") ?? ""
    @State private var rcloneRemote = loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive"
    @State private var linkName = loadEnv("PKARCHIVES_DESKTOP_LINK_NAME") ?? "DesktopArchive"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Group {
                switch page {
                case "history": historyPage
                case "settings": settingsPage
                default: dashboardPage
                }
            }
        }
        .frame(width: 900, height: 680)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .startArchive)) { notification in
            if let mode = notification.userInfo?["mode"] as? String, !isRunning {
                startArchive(mode: mode)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("PKarchives").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Desktop archive / Google Drive").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Spacer()
            Label(isRunning ? status : "Ready", systemImage: isRunning ? "arrow.up.right" : "checkmark.circle.fill")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isRunning ? .orange : .green)
            Picker("Page", selection: $page) {
                Text("Dashboard").tag("dashboard")
                Text("History").tag("history")
                Text("Settings").tag("settings")
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(Color(red: 0.07, green: 0.09, blue: 0.10))
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard("Runs", value: "\(history.count)", icon: "clock.arrow.circlepath", color: .cyan)
            statCard("Archived", value: "\(history.reduce(0) { $0 + $1.success })", icon: "archivebox.fill", color: .orange)
            statCard("Freed", value: ByteCountFormatter.string(fromByteCount: history.reduce(0) { $0 + $1.bytesFreed }, countStyle: .file), icon: "internaldrive.fill", color: .green)
            statCard("Mount", value: "DesktopArchive", icon: "externaldrive.fill", color: .purple)
        }
    }

    private var dashboardPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statsRow
                if isRunning { transferProgress }
                liveConsole
                actionBar
            }
            .padding(22)
        }
    }

    private var historyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dashboardChart
                historyList
            }
            .padding(22)
        }
    }

    private func statCard(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title.uppercased()).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 17, weight: .semibold, design: .rounded)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
    }

    private var dashboardChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Archive activity").font(.headline)
                Spacer()
                Text("last 10 runs").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            if history.isEmpty {
                ContentUnavailableView("No archive history", systemImage: "chart.xyaxis.line", description: Text("Your next archive will appear here."))
                    .frame(height: 130)
            } else {
                Chart(Array(history.prefix(10).reversed())) { run in
                    BarMark(x: .value("Run", run.date, unit: .day), y: .value("Items", run.success))
                        .foregroundStyle(.cyan.gradient)
                        .cornerRadius(4)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 150)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private var liveConsole: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Live output").font(.headline); Spacer(); Text(status).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary) }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(output.isEmpty ? "Ready. Choose a mode and start an archive." : output)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("bottom")
                }
                .frame(height: 130)
                .onChange(of: output) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private var transferProgress: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Transfer progress").font(.headline)
                Spacer()
                Text("\(Int(uploadProgress * 100))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            ProgressView(value: uploadProgress)
                .tint(.cyan)
            Text(status)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(16)
        .background(Color.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent runs").font(.headline)
            if history.isEmpty {
                Text("No runs yet").foregroundStyle(.secondary).font(.system(size: 12, design: .monospaced))
            } else {
                ForEach(Array(history.prefix(4))) { run in
                    HStack {
                        Image(systemName: run.mountOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(run.mountOK ? .green : .orange)
                        Text(run.date, style: .date).font(.system(size: 11, design: .monospaced))
                        Text(run.mode == "all" ? "Files + folders" : "Files").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(run.success)/\(run.items)").font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Picker("Mode", selection: $selectedMode) { Text("Files").tag("files"); Text("Files + folders").tag("all") }
                .pickerStyle(.segmented).frame(width: 190).disabled(isRunning)
            Spacer()
            Button("Google Drive", systemImage: "folder.fill", action: openDrive).buttonStyle(.bordered)
            if isRunning { Button("Cancel", action: cancelRun).buttonStyle(.bordered).tint(.red) }
            else { Button("Archive", systemImage: "arrow.up.circle.fill") { startArchive(mode: selectedMode) }.buttonStyle(.borderedProminent).tint(.cyan) }
        }
    }

    private var settingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings").font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Configuration shared with the CLI.")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                settingField("Google Drive folder ID", text: $driveFolderID, hint: "Destination folder in Google Drive")
                settingField("Desktop path", text: $desktopPath, hint: "Leave empty to use ~/Desktop")
                settingField("rclone remote", text: $rcloneRemote, hint: "Usually gdrive")
                settingField("Desktop archive name", text: $linkName, hint: "Mount point created on the Desktop")
                HStack {
                    Button("Save settings") { saveSettings(); status = "Settings saved" }
                        .buttonStyle(.borderedProminent).tint(.cyan)
                    Button("Open Google Drive", action: openDrive).buttonStyle(.bordered)
                }
                Divider().padding(.vertical, 4)
                Text("Drive mount").font(.headline)
                Text("PKarchives mounts the Drive directly on DesktopArchive after a successful archive. No symlink is created if the mount fails.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(28)
        }
    }

    private func settingField(_ title: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold))
            TextField(title, text: text).textFieldStyle(.roundedBorder)
            Text(hint).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func saveSettings() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/.config/pkarchives/pkarchives.conf"
        try? FileManager.default.createDirectory(atPath: "\(home)/.config/pkarchives", withIntermediateDirectories: true)
        rcloneRemote = rcloneRemote.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        let content = "PKARCHIVES_DRIVE_FOLDER_ID=\"\(driveFolderID)\"\nPKARCHIVES_DESKTOP_PATH=\"\(desktopPath)\"\nPKARCHIVES_RCLONE_REMOTE=\"\(rcloneRemote)\"\nPKARCHIVES_DESKTOP_LINK_NAME=\"\(linkName)\"\n"
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    func openDrive() { if let url = URL(string: driveURL) { NSWorkspace.shared.open(url) } }

    func cancelRun() {
        process?.terminate()
        isRunning = false
        status = "Annulé"
        output += "\n🛑 Annulé par l'utilisateur.\n"
        timer?.invalidate()
    }

    func mountDrive() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let desktop = (loadEnv("PKARCHIVES_DESKTOP_PATH") ?? "\(home)/Desktop")
            .replacingOccurrences(of: "~", with: home, options: [], range: nil)
        let linkName = loadEnv("PKARCHIVES_DESKTOP_LINK_NAME") ?? "DesktopArchive"
        let remote = (loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive").trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard let folderID = loadEnv("PKARCHIVES_DRIVE_FOLDER_ID"), !folderID.isEmpty else {
            output += "\n⚠️ Drive Folder ID absent, montage ignoré.\n"
            return
        }

        let mountPath = "\(desktop)/\(linkName)"
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            if isMounted(at: mountPath) {
                DispatchQueue.main.async {
                    self.output += "\n📁 Google Drive déjà monté dans Finder : \(mountPath)\n"
                }
                return
            }

            if fileManager.fileExists(atPath: mountPath) {
                guard (try? fileManager.contentsOfDirectory(atPath: mountPath).isEmpty) == true else {
                    DispatchQueue.main.async {
                        self.output += "\n⚠️ \(linkName) existe déjà et n'est pas vide. Montage annulé.\n"
                    }
                    return
                }
            } else {
                try? fileManager.createDirectory(atPath: mountPath, withIntermediateDirectories: true)
            }

            let logPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("pkarchives-mount.log").path
            let mount = Process()
            let binary = rcloneBinary()
            if binary.contains("/") {
                mount.executableURL = URL(fileURLWithPath: binary)
                mount.arguments = [
                    "mount", "\(remote):", mountPath,
                    "--drive-root-folder-id", folderID,
                    "--daemon", "--daemon-wait", "10s",
                    "--vfs-cache-mode", "minimal", "--volname", "PKarchives",
                    "--log-file", logPath, "--log-level", "INFO"
                ]
            } else {
                mount.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                mount.arguments = [
                    "rclone", "mount", "\(remote):", mountPath,
                "--drive-root-folder-id", folderID,
                "--daemon", "--daemon-wait", "10s",
                "--vfs-cache-mode", "minimal", "--volname", "PKarchives",
                "--log-file", logPath, "--log-level", "INFO"
                ]
            }
            do {
                try mount.run()
                mount.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self.output += "\n⚠️ Impossible de lancer rclone mount: \(error.localizedDescription)\n"
                }
                return
            }

            if isMounted(at: mountPath) {
                DispatchQueue.main.async {
                    self.output += "\n📁 Google Drive monté dans Finder : \(mountPath)\n"
                }
            } else {
                try? fileManager.removeItem(atPath: mountPath)
                let log = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
                let help = log.contains("installed via Homebrew")
                    ? "Installe le binaire officiel rclone depuis rclone.org/downloads : Homebrew ne prend pas en charge mount sur macOS."
                    : "Consulte le log rclone et vérifie FUSE-T/macFUSE."
                DispatchQueue.main.async {
                    self.output += "\n⚠️ Google Drive non monté. \(help)\n"
                }
            }
        }
    }

    func startArchive(mode: String) {
        selectedMode = mode
        runArchive()
    }

    func runArchive() {
        isRunning = true
        output = ""
        status = "Préparation..."
        uploadProgress = 0

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

        let statusFile = FileManager.default.temporaryDirectory.appendingPathComponent("pkarchives_\(ProcessInfo.processInfo.processIdentifier)").path

        // Pass config as env vars
        var env = ProcessInfo.processInfo.environment
        if let v = loadEnv("PKARCHIVES_DRIVE_FOLDER_ID") { env["PKARCHIVES_DRIVE_FOLDER_ID"] = v }
        env["PKARCHIVES_STATUS_FILE"] = statusFile
        if let v = loadEnv("PKARCHIVES_DESKTOP_PATH"), !v.isEmpty { env["PKARCHIVES_DESKTOP_PATH"] = v }
        if let v = loadEnv("PKARCHIVES_DESKTOP_LINK_NAME"), !v.isEmpty { env["PKARCHIVES_DESKTOP_LINK_NAME"] = v }
        if let v = loadEnv("PKARCHIVES_RCLONE_REMOTE"), !v.isEmpty { env["PKARCHIVES_RCLONE_REMOTE"] = v }
        env["PKARCHIVES_RCLONE_BINARY"] = rcloneBinary()
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        self.process = proc

        // Poll status file
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            if let data = try? Data(contentsOf: URL(fileURLWithPath: statusFile)),
               let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !s.isEmpty {
                self.status = s
                if let match = s.range(of: "\\b[0-9]{1,3}%", options: .regularExpression) {
                    let percentage = s[match].dropLast()
                    self.uploadProgress = min(1, max(0, (Double(percentage) ?? 0) / 100))
                }
            }
        }

        proc.terminationHandler = { process in
            DispatchQueue.main.async {
                self.isRunning = false
                self.process = nil
                self.timer?.invalidate()
                self.status = "Terminé"
                self.uploadProgress = 1
                if process.terminationStatus == 0 {
                    self.mountDrive()
                    let run = ArchiveRun(date: Date(), mode: self.selectedMode,
                                         items: self.output.isEmpty ? 0 : 1, success: self.output.isEmpty ? 0 : 1,
                                         bytesFreed: 0, mountOK: true)
                    self.history.insert(run, at: 0)
                    saveHistory(self.history)
                }
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

func isMounted(at path: String) -> Bool {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/sbin/mount")
    process.standardOutput = pipe
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.contains(" on \(path) ") == true
    } catch {
        return false
    }
}
