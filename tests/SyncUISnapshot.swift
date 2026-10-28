// Render the actual native Sync view offscreen, without activating a window or capturing the user's desktop.
import SwiftUI
import AppKit

func loadEnv(_ key: String) -> String? { nil }
func rcloneBinary() -> String { "/__snapshot_no_transfers__" }
func expandedPath(_ path: String) -> String { (path as NSString).expandingTildeInPath }
func shortPath(_ path: String) -> String { path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
func mountPath() -> String { "/__snapshot_no_mount__" }
func desktopPath() -> String { "/__snapshot_no_archive__" }
func monthFolder() -> String {
    let formatter = DateFormatter(); formatter.dateFormat = "yyyy_MM"; return formatter.string(from: Date())
}

struct SettingsSectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20, weight: .medium)).foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42).background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(.bottom, 6)
    }
}

@main struct SyncUISnapshot {
    static func main() throws {
        let args = CommandLine.arguments
        // Regression: no stale throughput in preview/check/idle, no negative remaining counts.
        var progress = RunProgress()
        progress.phase = .push; progress.speed = 4_000_000
        progress.transfersTotal = 10; progress.transfersDone = 3
        precondition(MenuActivity.title(display: .remaining, busy: true, dryRun: false, progress: progress) == "7 \(syncText("files"))")
        precondition(MenuActivity.title(display: .speed, busy: true, dryRun: false, progress: progress).contains("/s"))
        precondition(MenuActivity.title(display: .speed, busy: true, dryRun: true, progress: progress) == workspaceText("previewShort"))
        precondition(MenuActivity.title(display: .speed, busy: false, dryRun: false, progress: progress).isEmpty)
        precondition(MenuActivity.title(display: .icon, busy: true, dryRun: false, progress: progress).isEmpty)
        progress.transfersDone = 12
        precondition(MenuActivity.title(display: .remaining, busy: true, dryRun: false, progress: progress) == "0 \(syncText("files"))")
        progress.transfersTotal = 0
        precondition(MenuActivity.title(display: .remaining, busy: true, dryRun: false, progress: progress) == "…")
        progress.phase = .verifying
        precondition(MenuActivity.title(display: .speed, busy: true, dryRun: false, progress: progress) == workspaceText("checkingShort"))
        progress.phase = .listing
        precondition(MenuActivity.title(display: .speed, busy: true, dryRun: false, progress: progress) == "…")
        progress.phase = .pull; progress.speed = .infinity
        precondition(MenuActivity.title(display: .speed, busy: true, dryRun: false, progress: progress) == "…")
        print("Menu activity regressions passed")
        guard args.count >= 3 else { fatalError("sync-snapshot TEST_ROOT OUTPUT.png [sync|history|quota|menu|menuArchive|form]") }
        let root = URL(fileURLWithPath: args[1])
        let kind = args.count > 3 ? args[3] : "sync"
        let fixture = kind == "quota" ? "past-quota" : "push"
        let disk = SyncDisk(base: root.appendingPathComponent("\(fixture)/data"), logs: root.appendingPathComponent("\(fixture)/logs"))
        // Status captures run read-only `rclone size` counts on the fixture remotes; every other
        // kind keeps the sentinel binary that can never launch a transfer.
        var inventoryBinary: String? = nil
        if ["status", "menuLive"].contains(kind), FileManager.default.fileExists(atPath: root.appendingPathComponent("rclone.conf").path) {
            setenv("RCLONE_CONFIG", root.appendingPathComponent("rclone.conf").path, 1)
            for candidate in [NSHomeDirectory() + "/.local/share/pkarchives/bin/rclone", "/opt/homebrew/bin/rclone", "/usr/local/bin/rclone"]
            where FileManager.default.fileExists(atPath: candidate) { inventoryBinary = candidate; break }
        }
        let engine = SyncEngine(disk: disk, binary: inventoryBinary, automatic: false)
        guard engine.storageError == nil else { fatalError(engine.storageError!) }
        if kind == "menuLive", inventoryBinary != nil, let pair = engine.pairs.first {
            // Isolated test remote: RCLONE_BWLIMIT=1M RCLONE_DISABLE=Copy keeps the real copy visible.
            engine.syncPair(pair.id)
            let limit = Date().addingTimeInterval(20)
            while engine.busy && (engine.runProgress?.speed ?? 0) <= 0 && limit > Date() {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            precondition(engine.busy && (engine.runProgress?.speed ?? 0) > 0, "Expected live rclone throughput")
            precondition(engine.runProgress?.phase == .push, "One-way transfer phase must be push")
        }
        if kind == "status", inventoryBinary != nil {
            engine.refreshAllInventories()
            let limit = Date().addingTimeInterval(45)
            while engine.inventoryActive && limit > Date() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let dark = ProcessInfo.processInfo.environment["PK_SNAPSHOT_DARK"] == "1"
        app.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            precondition(WorkspaceAppVersion.installed == version)
            print("Displayed installed version: \(WorkspaceAppVersion.installed)")
        }
        if let icon = NSImage(contentsOfFile: "icon.png") { app.applicationIconImage = icon }
        let navigation = WorkspaceNavigation()
        precondition(navigation.mode == .archive)
        precondition(WorkspaceMode.allCases == [.archive, .sync])
        navigation.mode = .sync
        precondition(WorkspaceNavigation().mode == .archive)
        navigation.showingSettings = true
        precondition(navigation.mode == .sync)
        navigation.showingSettings = false
        let tracker = StatusHoverView(frame: .zero)
        precondition(tracker.hitTest(.zero) == nil)
        navigation.mode = kind == "menuArchive" ? .archive : .sync
        let content: AnyView
        var bounds: NSRect
        if kind == "general" {
            content = AnyView(WorkspaceGeneralSettings())
            bounds = NSRect(x: 0, y: 0, width: 660, height: 480)
        } else if kind == "form" {
            content = AnyView(SyncPairForm(original: SyncPair(), engine: engine))
            bounds = NSRect(x: 0, y: 0, width: 580, height: 640)
        } else if kind.hasPrefix("menu") {
            content = AnyView(WorkspacePopoverView(engine: engine, navigation: navigation, open: { _, _ in }, settings: {}, support: {}, updates: {}, about: {}, quit: {}, hoverChanged: { _ in }))
            bounds = NSRect(x: 0, y: 0, width: 400, height: 620)
        } else {
            content = AnyView(VStack(spacing: 0) {
                WorkspaceHeaderView(navigation: navigation, select: { navigation.mode = $0 }, settings: { navigation.showingSettings = true })
                SyncSectionView(engine: engine, initialTab: ["history", "quota"].contains(kind) ? "history" : "pairs")
            })
            bounds = NSRect(x: 0, y: 0, width: 1240, height: 820)
        }
        let view = NSHostingView(rootView: content.background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light))
        if kind.hasPrefix("menu") { bounds.size.height = view.fittingSize.height }
        let window = NSWindow(contentRect: NSRect(x: -12000, y: -12000, width: bounds.width, height: bounds.height), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        view.frame = bounds
        // The window is never ordered onto a screen; render its view hierarchy directly.
        for _ in 0..<10 { RunLoop.main.run(until: Date().addingTimeInterval(0.1)); view.layoutSubtreeIfNeeded() }
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) else { fatalError("No bitmap") }
        view.cacheDisplay(in: bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("No PNG") }
        try png.write(to: URL(fileURLWithPath: args[2]))
        print("Native offscreen snapshot: \(args[2])")
        if kind == "menuLive" {
            engine.shutdown()
            let limit = Date().addingTimeInterval(15)
            while engine.busy && limit > Date() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            precondition(!engine.busy, "Fixture transfer did not stop")
        }
    }
}
