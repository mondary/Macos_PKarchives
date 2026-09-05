// PKarchives v2 — interface moderne (WKWebView)
// Même moteur que la v1 (archive.sh + rclone) : scan du Bureau avec vignettes,
// cartes animées qui s'envolent vers le Drive puis se dissolvent (suppression).
import SwiftUI
import AppKit
import WebKit
import QuickLookThumbnailing
import CoreServices

// MARK: - Config / historique (identique v1, app séparée)

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
    if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty { return env }
    let appDir = Bundle.main.resourcePath ?? ""
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let envPaths = [
        "\(appDir)/../Resources/secrets/.env",
        "\(home)/Documents/GitHub/PROJECTS/PKarchives/secrets/.env",
        "\(home)/Documents/GitHub/PROJECTS/Macos_PKarchives/secrets/.env",
        "\(home)/.config/pkarchives/secrets/.env",
        "\(home)/.config/pkarchives/pkarchives.conf"
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

func expandedPath(_ p: String) -> String {
    (p as NSString).expandingTildeInPath
}

func desktopPath() -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let p = loadEnv("PKARCHIVES_DESKTOP_PATH") ?? ""
    return p.isEmpty ? "\(home)/Desktop" : expandedPath(p)
}

func driveFolderURL() -> String {
    guard let id = loadEnv("PKARCHIVES_DRIVE_FOLDER_ID"), !id.isEmpty else {
        return "https://drive.google.com"
    }
    return "https://drive.google.com/drive/folders/\(id)"
}

func monthFolder() -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "fr_FR")
    df.dateFormat = "yyyy_MM_MMMM"
    return df.string(from: Date())
}

func humanSize(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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

// MARK: - Scan du Bureau + vignettes

struct DeskItem {
    let name: String
    let isDir: Bool
    let size: Int64       // fichiers : octets ; dossiers : nb de fichiers
    let thumb: String?    // data URI
    let textPreview: String?
}

func symbolThumb(_ name: String, tint: NSColor) -> String? {
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: ""),
          let sym = base.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 88, weight: .regular)) else { return nil }
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 220, pixelsHigh: 220,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    tint.setFill()
    let s = sym.size
    let scale = min(120 / s.width, 120 / s.height)
    let w = s.width * scale, h = s.height * scale
    sym.draw(in: NSRect(x: (220 - w) / 2, y: (220 - h) / 2, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else { return nil }
    return "data:image/png;base64," + data.base64EncodedString()
}

func fileThumb(_ url: URL) -> String? {
    let sem = DispatchSemaphore(value: 0)
    var nsImage: NSImage?
    let req = QLThumbnailGenerator.Request(fileAt: url,
                                           size: CGSize(width: 256, height: 256),
                                           scale: 1,
                                           representationTypes: .all)
    QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
        nsImage = rep?.nsImage
        sem.signal()
    }
    _ = sem.wait(timeout: .now() + 1.5)
    guard let img = nsImage, let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else { return nil }
    return "data:image/png;base64," + data.base64EncodedString()
}

func hasBureauTag(_ url: URL) -> Bool {
    let pipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/mdls")
    process.arguments = ["-name", "kMDItemUserTags", "-raw", url.path]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.range(of: "Bureau", options: .caseInsensitive) != nil
    } catch {
        return false
    }
}

func dirStats(_ url: URL) -> (count: Int, bytes: Int64) {
    var count = 0, bytes: Int64 = 0
    guard let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
        return (0, 0)
    }
    for case let f as URL in en {
        guard let vals = try? f.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              vals.isRegularFile == true else { continue }
        count += 1
        bytes += Int64(vals.fileSize ?? 0)
    }
    return (count, bytes)
}

func scanDesktop(mode: String = "files") throws -> [DeskItem] {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let desktop = desktopPath()
    let linkName = loadEnv("PKARCHIVES_DESKTOP_LINK_NAME") ?? "DesktopArchive"
    var files: [(String, Int64, URL)] = []
    var dirs: [(String, Int, Int64, URL)] = []
    let fm = FileManager.default
    let entries = try fm.contentsOfDirectory(atPath: desktop)
    for name in entries.sorted() {
        if name.hasPrefix(".") || name == linkName { continue }
        let full = "\(desktop)/\(name)"
        let url = URL(fileURLWithPath: full)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: full, isDirectory: &isDir) else { continue }
        if hasBureauTag(url) { continue }
        if isDir.boolValue {
            let st = dirStats(url)
            dirs.append((name, st.count, st.bytes, url))
        } else {
            let sz = ((try? fm.attributesOfItem(atPath: full))?[.size] as? Int64) ?? 0
            files.append((name, sz, url))
        }
    }
    files.sort { $0.1 < $1.1 }
    dirs.sort { $0.1 < $1.1 }

    var items: [DeskItem] = []
    for (name, sz, url) in files {
        let textPreview: String?
        let ext = url.pathExtension.lowercased()
        if ["txt", "md", "markdown", "json", "yaml", "yml", "csv", "log", "sh", "swift", "go", "js", "ts", "html", "css"].contains(ext) {
            let content = try? String(contentsOf: url, encoding: .utf8)
            textPreview = content.map { String($0.prefix(900)) }
        } else {
            textPreview = nil
        }
        items.append(DeskItem(name: name, isDir: false, size: sz,
                              thumb: items.count < 40 ? fileThumb(url) : nil,
                              textPreview: textPreview))
    }
    guard mode == "all" else { return items }
    let folderIcon = symbolThumb("folder.fill", tint: NSColor(calibratedRed: 0.35, green: 0.62, blue: 0.95, alpha: 1))
    for (name, count, _, _) in dirs {
        items.append(DeskItem(name: name, isDir: true, size: Int64(count), thumb: folderIcon, textPreview: nil))
    }
    // vignette de repli pour les fichiers sans aperçu
    for i in items.indices where !items[i].isDir && items[i].thumb == nil {
        items[i] = DeskItem(name: items[i].name, isDir: false, size: items[i].size, thumb: nil, textPreview: items[i].textPreview)
    }
    _ = home
    return items
}

// MARK: - App delegate + pont WebView

class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var statusItem: NSStatusItem?
    var statusMenu: NSMenu?
    var window: NSWindow?
    var webView: WKWebView?

    // état du run
    var process: Process?
    var timer: Timer?
    var isRunning = false
    var selectedMode = "files"
    var lastTotal = 0
    var deletedCount = 0
    var uploadedBytes: Int64 = 0
    var eventOffset = 0
    var sizeByName: [String: Int64] = [:]
    var currentItems: [DeskItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "📦"
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ouvrir PKarchives", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Archiver (fichiers)", action: #selector(quickFiles), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Archiver (tout)", action: #selector(quickAll), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Ouvrir Google Drive", action: #selector(openDrive), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quitter", action: #selector(quitApp), keyEquivalent: "q"))
        statusMenu = menu
        showWindow()

        // Test/e2e : PKARCHIVES_AUTOSTART=files|all lance l'archivage au démarrage
        if let auto = loadEnv("PKARCHIVES_AUTOSTART"), !auto.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.startArchive(mode: auto)
            }
        }
    }

    @objc func statusClicked() {
        guard let event = NSApp.currentEvent else { showWindow(); return }
        if event.type == .rightMouseUp, let button = statusItem?.button {
            statusMenu?.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        } else {
            showWindow()
        }
    }

    @objc func showWindow() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 780),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            let cfg = WKWebViewConfiguration()
            cfg.userContentController.add(self, name: "pk")
            let wv = WKWebView(frame: w.contentLayoutRect, configuration: cfg)
            wv.autoresizingMask = [.width, .height]
            wv.navigationDelegate = self
            wv.setValue(false, forKey: "drawsBackground")
            w.backgroundColor = NSColor(red: 0.027, green: 0.035, blue: 0.05, alpha: 1)
            w.title = "PKarchives"
            w.contentView = wv
            if let res = Bundle.main.resourcePath {
                let webDir = URL(fileURLWithPath: "\(res)/web", isDirectory: true)
                let index = webDir.appendingPathComponent("index.html")
                if FileManager.default.fileExists(atPath: index.path) {
                    wv.loadFileURL(index, allowingReadAccessTo: webDir)
                } else {
                    wv.loadHTMLString("<body style='background:#07090d;color:#fff;font-family:sans-serif;padding:40px'>Interface web introuvable dans l'app.</body>", baseURL: nil)
                }
            }
            w.center()
            window = w
            webView = wv
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quickFiles() { showWindow(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.js("window.__pkStart && __pkStart('files')") } }
    @objc func quickAll() { showWindow(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.js("window.__pkStart && __pkStart('all')") } }
    @objc func openDrive() { if let url = URL(string: driveFolderURL()) { NSWorkspace.shared.open(url) } }
    @objc func openFinder() { NSWorkspace.shared.open(URL(fileURLWithPath: desktopPath())) }
    @objc func quitApp() { NSApp.terminate(nil) }

    // MARK: pont JS

    func js(_ code: String) {
        DispatchQueue.main.async { self.webView?.evaluateJavaScript(code, completionHandler: nil) }
    }

    func sendEV(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              var s = String(data: data, encoding: .utf8) else {
            NSLog("PKV2 sendEV: SERIALIZATION FAILED \(dict.keys)")
            return
        }
        s = s.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
             .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        js("__pkEvent(\(s));")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "pk",
              let body = message.body as? [String: Any],
              let cmd = body["cmd"] as? String else { return }
        switch cmd {
        case "ready":
            bootPayload()
        case "archive":
            let mode = (body["mode"] as? String) ?? "files"
            startArchive(mode: mode)
        case "cancel":
            process?.terminate()
        case "openDrive":
            openDrive()
        case "openFinder":
            openFinder()
        case "chooseDesktop":
            chooseDesktop()
        case "rescan":
            refreshItems(mode: body["mode"] as? String ?? "files")
        case "settingsReq":
            sendSettings()
        case "historyReq":
            sendHistory()
        case "saveSettings":
            saveSettings(folderId: body["folderId"] as? String ?? "",
                         desktop: body["desktop"] as? String ?? "",
                         remote: body["remote"] as? String ?? "gdrive",
                         permanent: body["permanent"] as? Bool ?? false)
            sendEV(["type": "log", "line": "✅ Réglages enregistrés", "cls": "ok"])
            sendDest()
            refreshItems(mode: selectedMode)
        default:
            break
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        bootPayload()
    }

    func bootPayload() {
        sendDest()
        sendSettings()
        sendHistory()
        refreshItems()
    }

    func sendDest() {
        let remote = (loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive").trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        let folder = monthFolder()
        sendEV(["type": "dest", "name": "\(remote):\(folder)", "short": folder, "url": driveFolderURL()])
    }

    func sendSettings() {
        sendEV(["type": "settings",
                "folderId": loadEnv("PKARCHIVES_DRIVE_FOLDER_ID") ?? "",
                "desktop": desktopPath(),
                "remote": (loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive").trimmingCharacters(in: CharacterSet(charactersIn: ":")),
                "permanent": (loadEnv("PKARCHIVES_DELETE_MODE") ?? "trash") == "delete"])
    }

    func sendHistory() {
        let runs = loadHistory()
        let calendar = Calendar.current
        let now = Date()
        let formatter = ISO8601DateFormatter()
        let payload: [[String: Any]] = runs.map {
            ["date": formatter.string(from: $0.date), "items": $0.items,
             "success": $0.success, "bytes": $0.bytesFreed]
        }
        sendEV(["type": "history", "runs": payload,
                "total": runs.reduce(0) { $0 + $1.success },
                "bytes": runs.reduce(0) { $0 + $1.bytesFreed }])
    }

    func refreshItems(mode: String = "files") {
        DispatchQueue.global(qos: .userInitiated).async {
            let items: [DeskItem]
            do {
                items = try scanDesktop(mode: mode)
            } catch {
                DispatchQueue.main.async {
                    self.sendEV(["type": "scanError", "path": desktopPath(), "message": error.localizedDescription])
                }
                return
            }
            DispatchQueue.main.async {
                self.currentItems = items
                self.sizeByName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.size) })
                let payload: [[String: Any]] = items.map {
                    ["name": $0.name,
                     "kind": $0.isDir ? "folder" : "file",
                     "ext": URL(fileURLWithPath: $0.name).pathExtension.lowercased(),
                     "sizeTxt": $0.isDir ? "\($0.size) fichier(s)" : humanSize($0.size),
                     "thumb": $0.thumb ?? NSNull(),
                     "textPreview": $0.textPreview ?? NSNull()]
                }
                let src = desktopPath()
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                self.sendEV(["type": "items", "items": payload,
                             "source": src.hasPrefix(home) ? "~" + src.dropFirst(home.count) : src])
            }
        }
    }

    func saveSettings(folderId: String, desktop: String, remote: String, permanent: Bool) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/.config/pkarchives/pkarchives.conf"
        try? FileManager.default.createDirectory(atPath: "\(home)/.config/pkarchives", withIntermediateDirectories: true)
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        let content = "PKARCHIVES_DRIVE_FOLDER_ID=\"\(folderId)\"\nPKARCHIVES_DESKTOP_PATH=\"\(desktop)\"\nPKARCHIVES_RCLONE_REMOTE=\"\(cleanRemote)\"\nPKARCHIVES_DESKTOP_LINK_NAME=\"\(loadEnv("PKARCHIVES_DESKTOP_LINK_NAME") ?? "DesktopArchive")\"\nPKARCHIVES_DELETE_MODE=\"\(permanent ? "delete" : "trash")\"\n"
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    func chooseDesktop() {
        let panel = NSOpenPanel()
        panel.title = "Choisir le dossier source"
        panel.message = "Sélectionnez le dossier à analyser et archiver."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: desktopPath())
        guard panel.runModal() == .OK, let url = panel.url else { return }
        sendEV(["type": "desktopChosen", "path": url.path])
    }

    // MARK: run archive.sh

    func startArchive(mode: String) {
        guard !isRunning else { return }
        selectedMode = mode
        isRunning = true
        lastTotal = 0; deletedCount = 0; uploadedBytes = 0; eventOffset = 0
        sendEV(["type": "log", "line": "— Lancement de l'archivage —", "cls": "dim"])

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let appDir = Bundle.main.resourcePath ?? ""
        let envScript = ProcessInfo.processInfo.environment["PKARCHIVES_SCRIPT"] ?? ""
        let candidates = [
            envScript,
            "\(appDir)/../Resources/archive.sh",
            "\(appDir)/../MacOS/archive.sh",
            "\(home)/.config/pkarchives/archive.sh"
        ].filter { !$0.isEmpty }
        guard let scriptPath = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            sendEV(["type": "log", "line": "❌ Script archive.sh introuvable", "cls": "err"])
            isRunning = false
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [scriptPath, mode]

        let statusFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("pkarchives_\(ProcessInfo.processInfo.processIdentifier)_status").path
        let eventFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("pkarchives_\(ProcessInfo.processInfo.processIdentifier)_events").path
        try? "".write(toFile: eventFile, atomically: true, encoding: .utf8)
        eventOffset = 0

        var env = ProcessInfo.processInfo.environment
        env["PKARCHIVES_STATUS_FILE"] = statusFile
        env["PKARCHIVES_EVENT_FILE"] = eventFile
        if let v = loadEnv("PKARCHIVES_DRIVE_FOLDER_ID") { env["PKARCHIVES_DRIVE_FOLDER_ID"] = v }
        if let v = loadEnv("PKARCHIVES_DESKTOP_PATH"), !v.isEmpty { env["PKARCHIVES_DESKTOP_PATH"] = v }
        if let v = loadEnv("PKARCHIVES_DESKTOP_LINK_NAME"), !v.isEmpty { env["PKARCHIVES_DESKTOP_LINK_NAME"] = v }
        if let v = loadEnv("PKARCHIVES_RCLONE_REMOTE"), !v.isEmpty { env["PKARCHIVES_RCLONE_REMOTE"] = v }
        env["PKARCHIVES_RCLONE_BINARY"] = rcloneBinary()
        env["PKARCHIVES_DELETE_MODE"] = (loadEnv("PKARCHIVES_DELETE_MODE") ?? "trash")
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        self.process = proc

        timer?.invalidate()
        var lastStatus = ""
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let data = try? Data(contentsOf: URL(fileURLWithPath: statusFile)),
               let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !s.isEmpty, s != lastStatus {
                lastStatus = s
                self.sendEV(["type": "status", "text": s])
            }
            self.drainEvents(eventFile)
        }

        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.timer?.invalidate()
                self.drainEvents(eventFile) // derniers événements écrits juste avant la fin du script
                self.isRunning = false
                self.process = nil
                self.timer?.invalidate()
                let ok = p.terminationStatus == 0
                self.sendEV(["type": "runDone", "ok": ok, "success": self.deletedCount, "total": max(self.lastTotal, self.deletedCount)])
                if ok && self.deletedCount > 0 {
                    let run = ArchiveRun(date: Date(), mode: self.selectedMode,
                                         items: max(self.lastTotal, 1), success: self.deletedCount,
                                         bytesFreed: self.uploadedBytes, mountOK: true)
                    var hist = loadHistory()
                    hist.insert(run, at: 0)
                    saveHistory(hist)
                    self.mountDrive()
                }
                try? FileManager.default.removeItem(atPath: statusFile)
                try? FileManager.default.removeItem(atPath: eventFile)
            }
        }

        do { try proc.run() } catch {
            sendEV(["type": "log", "line": "❌ Erreur: \(error.localizedDescription)", "cls": "err"])
            isRunning = false
            timer?.invalidate()
            return
        }

        readPipe(outPipe) { [weak self] line in self?.parseOutputLine(line) }
        readPipe(errPipe) { [weak self] line in self?.parseOutputLine(line) }
    }

    func readPipe(_ pipe: Pipe, handler: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let handle = pipe.fileHandleForReading
            var buf = ""
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                guard let self = self, let str = String(data: data, encoding: .utf8) else { continue }
                buf += stripAnsi(str)
                var lines = buf.components(separatedBy: .newlines)
                buf = lines.popLast() ?? ""
                for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    DispatchQueue.main.async { self.parseOutputLine(line) }
                }
            }
            _ = self
        }
    }

    func parseOutputLine(_ line: String) {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        if t.contains("📦"), t.range(of: "[0-9]+", options: .regularExpression) != nil {
            sendEV(["type": "log", "line": t, "cls": "dim"])
            return
        }
        if t.contains("✅") || t.contains("🔗") || t.contains("🗑") || t.contains("⚠️") || t.contains("❌") {
            let cls = t.contains("✅") ? "ok" : (t.contains("⚠️") || t.contains("❌") ? "warn" : "dim")
            sendEV(["type": "log", "line": t, "cls": cls])
        }
    }

    // Journal d'événements append-only écrit par archive.sh
    func drainEvents(_ eventFile: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: eventFile)) else { return }
        guard data.count > eventOffset else { return }
        let chunk = data.subdata(in: eventOffset..<data.count)
        eventOffset = data.count
        guard let s = String(data: chunk, encoding: .utf8) else { return }
        for line in s.components(separatedBy: .newlines) where !line.isEmpty {
            handleEventLine(line)
        }
    }

    func handleEventLine(_ line: String) {
        let parts = line.components(separatedBy: "|")
        guard let type = parts.first else { return }
        let name = parts.count > 1 ? parts[1] : ""
        switch type {
        case "total":
            lastTotal = Int(name) ?? 0
            sendEV(["type": "run", "total": lastTotal])
        case "upload":
            sendEV(["type": "uploadStart", "name": name])
        case "progress":
            let detail = parts.count > 2 ? parts[2] : ""
            if detail.contains("/") {
                sendEV(["type": "progress", "name": name, "pct": subPct(detail) ?? 0, "sub": detail])
            } else {
                sendEV(["type": "progress", "name": name, "pct": Double(detail) ?? 0, "sub": ""])
            }
        case "ok":
            uploadedBytes += sizeByName[name] ?? 0
            sendEV(["type": "uploaded", "name": name])
        case "deleted":
            deletedCount += 1
            // ponytail: on anime la suppression même si le trash échoue (cas rare, log visible côté journal)
            sendEV(["type": "deleted", "name": name,
                    "permanent": (loadEnv("PKARCHIVES_DELETE_MODE") ?? "trash") == "delete"])
        case "failed":
            sendEV(["type": "failed", "name": name])
            sendEV(["type": "log", "line": "❌ \(name) conservé (échec d'upload)", "cls": "err"])
        default:
            break
        }
    }

    func subPct(_ c: String) -> Double? {
        let pp = c.components(separatedBy: "/")
        guard pp.count == 2, let a = Double(pp[0]), let b = Double(pp[1]), b > 0 else { return nil }
        return a / b * 100
    }

    // MARK: montage Drive (identique v1)

    func mountDrive() {
        let desktop = desktopPath()
        let linkName = loadEnv("PKARCHIVES_DESKTOP_LINK_NAME") ?? "DesktopArchive"
        let remote = (loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive").trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard let folderID = loadEnv("PKARCHIVES_DRIVE_FOLDER_ID"), !folderID.isEmpty else {
            sendEV(["type": "log", "line": "⚠️ Drive Folder ID absent, montage ignoré", "cls": "warn"])
            return
        }
        // ponytail: montage hors du dossier Bureau (rm -rf du Bureau ne doit jamais traverser vers le Drive)
        let mountPath = "\(NSHomeDirectory())/DesktopArchive"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            if isMounted(at: mountPath) {
                self?.sendEV(["type": "log", "line": "📁 Google Drive déjà monté : \(mountPath)", "cls": "ok"])
                return
            }
            if fm.fileExists(atPath: mountPath) {
                guard (try? fm.contentsOfDirectory(atPath: mountPath).isEmpty) == true else {
                    self?.sendEV(["type": "log", "line": "⚠️ \(linkName) existe déjà et n'est pas vide. Montage annulé.", "cls": "warn"])
                    return
                }
            } else {
                try? fm.createDirectory(atPath: mountPath, withIntermediateDirectories: true)
            }
            let logPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("pkarchives-mount.log").path
            let mount = Process()
            let binary = rcloneBinary()
            if binary.contains("/") {
                mount.executableURL = URL(fileURLWithPath: binary)
                mount.arguments = ["mount", "\(remote):", mountPath,
                                   "--drive-root-folder-id", folderID,
                                   "--daemon", "--daemon-wait", "10s",
                                   "--vfs-cache-mode", "minimal", "--volname", "PKarchives",
                                   "--log-file", logPath, "--log-level", "INFO"]
            } else {
                mount.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                mount.arguments = ["rclone", "mount", "\(remote):", mountPath,
                                   "--drive-root-folder-id", folderID,
                                   "--daemon", "--daemon-wait", "10s",
                                   "--vfs-cache-mode", "minimal", "--volname", "PKarchives",
                                   "--log-file", logPath, "--log-level", "INFO"]
            }
            do { try mount.run(); mount.waitUntilExit() } catch {
                self?.sendEV(["type": "log", "line": "⚠️ Impossible de lancer rclone mount: \(error.localizedDescription)", "cls": "warn"])
                return
            }
            if isMounted(at: mountPath) {
                self?.sendEV(["type": "log", "line": "📁 Google Drive monté : \(mountPath)", "cls": "ok"])
                let linkPath = "\(desktop)/\(linkName)"
                try? fm.removeItem(atPath: linkPath)
                do { try fm.createSymbolicLink(atPath: linkPath, withDestinationPath: mountPath) } catch {
                    self?.sendEV(["type": "log", "line": "⚠️ Lien \(linkName) non créé: \(error.localizedDescription)", "cls": "warn"])
                }
            } else {
                try? fm.removeItem(atPath: mountPath)
                self?.sendEV(["type": "log", "line": "⚠️ Google Drive non monté (voir log rclone / FUSE-T)", "cls": "warn"])
            }
        }
    }
}

// MARK: - Entrée app

extension Notification.Name {
    static let startArchive = Notification.Name("startArchive")
}

@main
struct PKarchivesV2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}
