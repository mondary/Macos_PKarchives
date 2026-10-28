// Short-lived rclone processes, serialized reconciliation, isolated previews and durable reports.
import Foundation
import AppKit
import Combine
import CoreServices
import Darwin

enum DriveFolderLink {
    static func validID(_ value: String) -> Bool {
        value.count >= 10 && value.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 95 || $0 == 45 }
    }
    static func folderID(from input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if validID(value) { return value }
        guard let url = URL(string: value), url.scheme?.lowercased() == "https", url.host?.lowercased() == "drive.google.com" else {
            throw SyncFailure.message("Collez le lien complet d’un dossier Google Drive, par exemple https://drive.google.com/drive/folders/IDENTIFIANT.")
        }
        let parts = url.pathComponents
        guard let index = parts.firstIndex(of: "folders"), parts.indices.contains(index + 1),
              index + 2 == parts.count, validID(parts[index + 1]) else {
            throw SyncFailure.message("Ce lien ne désigne pas un dossier Drive. Ouvrez le dossier voulu, puis copiez son adresse contenant /folders/… ; pas le lien d’un fichier.")
        }
        return parts[index + 1]
    }
}

struct SyncDiagnostic: Codable, Equatable {
    enum Kind: String, Codable { case quota, storage, resync, authentication, permission, notFound, network, safety, other }
    let kind: Kind
    let details: String
    var titleKey: String { "failure.\(kind.rawValue).title" }
    var helpKey: String { "failure.\(kind.rawValue).help" }
    var outcome: String { kind == .quota ? "rateLimited" : kind == .resync ? "needsResync" : "error" }
    var summary: String {
        switch kind {
        case .quota: "Google Drive limite temporairement les requêtes API. Attendre avant de réessayer ; ce n’est pas un manque d’espace de stockage."
        case .storage: "L’espace de stockage Google Drive est insuffisant. Libérer de l’espace avant de relancer."
        case .resync: "La comparaison précédente est absente ou inutilisable. Une nouvelle comparaison des deux côtés doit être confirmée."
        case .authentication: "La connexion à Google Drive doit être réautorisée. Aucune synchronisation n’est déclarée réussie."
        case .permission: "Le compte ou le Mac n’a pas les droits nécessaires pour accéder à certains fichiers."
        case .notFound: "Un dossier est introuvable. Vérifier le dossier Mac, le lien Drive et le compte sélectionné."
        case .network: "La connexion réseau a été interrompue. Réessayer lorsque le réseau est disponible."
        case .safety: "La synchronisation s’est arrêtée par sécurité face à des changements importants. Examiner les détails avant de poursuivre."
        case .other: details
        }
    }
    static func clean(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{001B}\\[[0-?]*[ -/]*[@-~]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[(?:[0-9]{1,3};?)+m", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func classify(_ messages: [String]) -> SyncDiagnostic {
        let cleaned = messages.map(clean).filter { !$0.isEmpty }
        let text = cleaned.joined(separator: "\n").lowercased()
        let kind: Kind
        if text.contains("storagequotaexceeded") || text.contains("storage quota exceeded") {
            kind = .storage
        } else if text.contains("ratelimitexceeded") || text.contains("rate_limit_exceeded") || text.contains("quota exceeded for quota metric") || text.contains("error 429") || text.contains("too many requests") {
            kind = .quota
        } else if text.contains("invalid_grant") || text.contains("invalid credentials") || text.contains("unauthorized") || text.contains("error 401") {
            kind = .authentication
        } else if text.contains("insufficientfilepermissions") || text.contains("permission denied") || text.contains("error 403") || text.contains("access denied") {
            kind = .permission
        } else if text.contains("directory not found") || text.contains("error 404") || text.contains("notfound") || text.contains("file not found") {
            kind = .notFound
        } else if text.contains("timeout") || text.contains("connection reset") || text.contains("no such host") || text.contains("network is unreachable") || text.contains("i/o timeout") {
            kind = .network
        } else if text.contains("safety abort") || text.contains("too many deletes") || text.contains("mustn't overlap") {
            kind = .safety
        } else if text.contains("--resync") && (text.contains("must run") || text.contains("cannot find prior") || text.contains("filters file has changed")) {
            kind = .resync
        } else { kind = .other }
        let useful = cleaned.first { !$0.lowercased().contains("bisync aborted") && !$0.lowercased().hasPrefix("failed to bisync") } ?? cleaned.first ?? "Erreur inconnue."
        return SyncDiagnostic(kind: kind, details: String(useful.prefix(6000)))
    }
}

enum SyncDirection: String, Codable, CaseIterable {
    case bidirectional, push, pull
    var usesBisync: Bool { self == .bidirectional }
    var label: String { syncText("dir.\(rawValue)") }
    var arrow: String { self == .push ? "→" : self == .pull ? "←" : "⇄" }
}

enum SyncConflictPolicy: String, Codable, CaseIterable {
    case newest, local, remote
    var label: String { syncText("conflict.\(rawValue)") }
    var argument: String { self == .local ? "path1" : self == .remote ? "path2" : "newer" }
}

struct SyncPair: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var localPath = ""
    var drivePath = ""
    var driveFolderID: String?
    var direction: SyncDirection = .bidirectional
    var conflictPolicy: SyncConflictPolicy = .newest
    var ignores = [".DS_Store", "Thumbs.db", "~$*", ".TemporaryItems/**", ".Trashes/**", "node_modules/**"]
    var enabled = true
    // Default for NEW pairs only; existing pairs keep their own stored value.
    var previewOnly = UserDefaults.standard.object(forKey: "sync-default-preview-only") as? Bool ?? true
    var remoteOverride: String?
    var lastRun: Date?
    var lastOutcome = "idle"
    var lastMessage: String?
    var needsResync = true
    var consecutiveFailures = 0
    var nextRetryAt: Date?
    var volumeUUID: String?

    init() {}
    enum CodingKeys: String, CodingKey {
        case id, name, localPath, drivePath, driveFolderID, direction, conflictPolicy, ignores, enabled, previewOnly,
             remoteOverride, lastRun, lastOutcome, lastMessage, needsResync, consecutiveFailures, nextRetryAt, volumeUUID
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        localPath = try c.decode(String.self, forKey: .localPath)
        drivePath = try c.decode(String.self, forKey: .drivePath)
        driveFolderID = try c.decodeIfPresent(String.self, forKey: .driveFolderID)
        direction = try c.decode(SyncDirection.self, forKey: .direction)
        conflictPolicy = try c.decodeIfPresent(SyncConflictPolicy.self, forKey: .conflictPolicy) ?? .newest
        ignores = try c.decodeIfPresent([String].self, forKey: .ignores) ?? ignores
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        previewOnly = try c.decodeIfPresent(Bool.self, forKey: .previewOnly) ?? true
        remoteOverride = try c.decodeIfPresent(String.self, forKey: .remoteOverride)
        lastRun = try c.decodeIfPresent(Date.self, forKey: .lastRun)
        // The first prototype did not perform post-transfer checks. Do not migrate its green state.
        let old = try c.decodeIfPresent(String.self, forKey: .lastOutcome) ?? "idle"
        lastOutcome = old == "ok" ? "pending" : old
        lastMessage = try c.decodeIfPresent(String.self, forKey: .lastMessage)
        needsResync = try c.decodeIfPresent(Bool.self, forKey: .needsResync) ?? true
        consecutiveFailures = try c.decodeIfPresent(Int.self, forKey: .consecutiveFailures) ?? 0
        nextRetryAt = try c.decodeIfPresent(Date.self, forKey: .nextRetryAt)
        volumeUUID = try c.decodeIfPresent(String.self, forKey: .volumeUUID)
    }

    var remote: String { remoteOverride ?? (loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive").trimmingCharacters(in: CharacterSet(charactersIn: ":")) }
    // Scope the folder override to this endpoint without changing rclone.conf.
    var endpoint: String { driveFolderID.map { "\(remote),root_folder_id=\($0)" } ?? remote }
    var target: String { "\(endpoint):\(drivePath)" }
    var destinationDescription: String {
        driveFolderID.map { "Google Drive · \(remote) · …\($0.suffix(8))" } ?? target
    }
}

struct SyncJob: Codable, Equatable {
    let pairID: UUID
    let dryRun: Bool
    let resync: Bool
}

struct SyncRun: Codable, Identifiable {
    var id = UUID()
    var pair: SyncPair
    var dryRun: Bool
    var resync: Bool
    var started = Date()
    var finished: Date?
    var outcome = "running"
    var message = ""
    var directory: String
    var processID: Int32?
    var diagnostic: SyncDiagnostic?
    /// Present for previews: exact per-file comparison used by the UI and the report.
    var plan: PreviewPlan?
}

enum SyncFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

struct SyncDisk {
    let base: URL
    let logs: URL
    var config: URL { base.appendingPathComponent("sync.json") }
    var history: URL { base.appendingPathComponent("runs.json") }
    var journal: URL { logs.appendingPathComponent("sync.log") }

    static var standard: SyncDisk {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return SyncDisk(base: home.appendingPathComponent("Library/Application Support/PKarchives"),
                        logs: home.appendingPathComponent("Library/Logs/PKarchives"))
    }
    func prepare() throws {
        for dir in [base, logs] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        }
    }
    func load<T: Decodable>(_ type: T.Type, at url: URL, fallback: T) throws -> T {
        guard FileManager.default.fileExists(atPath: url.path) else { return fallback }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
    func save<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
    func workdir(_ id: UUID) -> URL { base.appendingPathComponent("bisync/\(id)") }
    static func append(_ text: String, to url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw SyncFailure.message("Journal inaccessible : \(url.path)")
            }
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((text + "\n").utf8))
    }
}

/// Last known file/byte counts for one pair, from `rclone size` with the pair's own exclusions.
/// Counts describe a moment; they are not a per-file diff nor a verified state.
struct PairInventory: Codable, Equatable {
    var localFiles: Int?
    var localBytes: Int64?
    var localAt: Date?
    var remoteFiles: Int?
    var remoteBytes: Int64?
    var remoteAt: Date?
    /// True when the remote count could not be refreshed (API cooldown or failed read).
    var remoteDeferred = false
    var gapFiles: Int? {
        guard let l = localFiles, let r = remoteFiles else { return nil }
        return abs(l - r)
    }
    var gapBytes: Int64? {
        guard let l = localBytes, let r = remoteBytes else { return nil }
        return abs(l - r)
    }
    var aligned: Bool { gapFiles == 0 && gapBytes == 0 }
}

/// Live feedback for one execution, parsed from rclone's own INFO log and stats.
/// Planned counts come from bisync's "Queue copy/delete" lines; done counts from
/// "Copied"/"Deleted"; throughput/ETA from rclone stats. Nothing is estimated.
struct RunProgress: Equatable {
    enum Phase: String { case listing, pull, push, deleting, verifying }
    var phase: Phase = .listing
    var pushPlanned = 0, pullPlanned = 0, deleteRemotePlanned = 0, deleteLocalPlanned = 0
    var pushDone = 0, pullDone = 0, deleteDone = 0
    var transfersDone = 0, transfersTotal = 0
    var bytesDone: Int64 = 0, bytesTotal: Int64 = 0
    var speed: Double = 0
    var eta: TimeInterval?
    var elapsed: TimeInterval = 0
    var listed: Int64 = 0
    var plannedDeletes: Int { deleteRemotePlanned + deleteLocalPlanned }
    var plannedPushes: Int { pushPlanned }
    var plannedPulls: Int { pullPlanned }
}

/// Exact comparison produced by a bisync pass: what each side would gain, update, lose
/// or keep untouched. Built from rclone's own per-file log lines, never estimated.
struct PreviewPlan: Codable, Equatable {
    var pushNew: [String] = []
    var pushModified: [String] = []
    var pullNew: [String] = []
    var pullModified: [String] = []
    var deleteRemote: [String] = []   // local deletions that would be propagated to Drive
    var deleteLocal: [String] = []    // Drive deletions that would be propagated locally
    var conflicts: [String] = []
    var truncated = false
    var localFiles: Int?
    var remoteFiles: Int?
    var countedAt: Date?
    var totalOps: Int { pushNew.count + pushModified.count + pullNew.count + pullModified.count + deleteRemote.count + deleteLocal.count + conflicts.count }
    /// Files present and identical on both sides, from the inventory minus every planned change.
    var unchanged: Int? {
        guard let l = localFiles else { return nil }
        let touchedLocally = pushNew.count + pushModified.count + pullModified.count + deleteLocal.count + conflicts.count
        return max(0, l - touchedLocally)
    }
}

/// All methods and observable mutations are main-queue confined. Disk-heavy work and pipe draining
/// run on a worker. No polling of the filesystem or permanent rclone/RC/FUSE process.
final class SyncEngine: ObservableObject {
    static let shared: SyncEngine = {
        let args = CommandLine.arguments
        if args.contains("--qa-screen"), let i = args.firstIndex(of: "--qa-data"), args.indices.contains(i + 1) {
            let root = URL(fileURLWithPath: args[i + 1])
            return SyncEngine(disk: SyncDisk(base: root.appendingPathComponent("data"), logs: root.appendingPathComponent("logs")),
                              binary: "/__qa_transfers_disabled__", automatic: false)
        }
        return SyncEngine(disk: .standard)
    }()
    @Published private(set) var pairs: [SyncPair] = []
    @Published private(set) var runs: [SyncRun] = []
    @Published private(set) var runningPairID: UUID?
    @Published private(set) var progressText = ""
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var journalLines: [String] = []
    @Published private(set) var statusBadgeSubject = "📦"
    @Published private(set) var storageError: String?
    @Published private(set) var queue: [SyncJob] = []
    @Published private(set) var cooldowns: [String: Date] = [:]
    @Published private(set) var inventories: [UUID: PairInventory] = [:]
    @Published private(set) var inventoryBusy = false
    @Published private(set) var runProgress: RunProgress?
    private var activePlan: PreviewPlan?
    private var planResyncDirection: String?
    let disk: SyncDisk
    private let binary: String
    private let automatic: Bool
    private var process: Process?
    private var active: SyncRun?
    private var cancelled = false
    private var shuttingDown = false
    private var lockFD: Int32 = -1
    private var wakeObserver: NSObjectProtocol?
    private var timer: Timer?
    private var stream: FSEventStreamRef?
    private var revisions: [UUID: Int] = [:]
    private var runRevision = 0
    private var localDue: [UUID: Date] = [:]
    private var remoteDue = Date().addingTimeInterval(3600)
    private var lastStat = Date.distantPast
    private var hasUncheckedHashes = false
    private var verifying = false
    private var skippedUnsupportedObject = false
    private var processErrors: [String] = []
    private var inventoryQueue: [UUID] = []

    init(disk: SyncDisk, binary: String? = nil, automatic: Bool = true) {
        self.disk = disk
        self.binary = binary ?? rcloneBinary()
        self.automatic = automatic
        do {
            try disk.prepare()
            // One engine per data directory, including between two installed builds.
            lockFD = Darwin.open(disk.base.appendingPathComponent("sync-engine.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
            guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
                throw SyncFailure.message("Une autre instance utilise déjà la synchronisation.")
            }
            pairs = try disk.load([SyncPair].self, at: disk.config, fallback: [])
            runs = try disk.load([SyncRun].self, at: disk.history, fallback: [])
            cooldowns = try disk.load([String: Date].self, at: disk.base.appendingPathComponent("cooldowns.json"), fallback: [:])
            inventories = try disk.load([UUID: PairInventory].self, at: disk.base.appendingPathComponent("inventories.json"), fallback: [:])
            // Enrich old generated history from its preserved raw logs; do not rewrite raw
            // evidence or existing Markdown reports just to correct the on-screen diagnosis.
            for i in runs.indices where ["error", "needsResync", "rateLimited"].contains(runs[i].outcome) {
                if runs[i].diagnostic == nil {
                    let logURL = URL(fileURLWithPath: runs[i].directory).appendingPathComponent("rclone.jsonl")
                    let messages = Self.errorMessages(in: Self.tail(logURL, bytes: 64 * 1024))
                    runs[i].diagnostic = SyncDiagnostic.classify(messages.isEmpty ? [runs[i].message] : messages)
                    runs[i].outcome = runs[i].diagnostic!.outcome
                }
                if runs[i].diagnostic?.kind == .quota {
                    let deadline = (runs[i].finished ?? runs[i].started).addingTimeInterval(900)
                    if deadline > Date() { cooldowns[runs[i].pair.remote] = max(cooldowns[runs[i].pair.remote] ?? .distantPast, deadline) }
                }
            }
            if let orphan = runs.first(where: { $0.outcome == "running" && $0.processID.map { Darwin.kill($0, 0) == 0 || errno == EPERM } == true }) {
                throw SyncFailure.message("Un processus de l’exécution précédente est encore actif (PID \(orphan.processID!)). Attendre sa fin puis relancer PKarchives ; aucune synchronisation concurrente n’est lancée.")
            }
            for i in runs.indices where runs[i].outcome == "running" {
                runs[i].outcome = "interrupted"
                runs[i].finished = Date()
                runs[i].message = "Exécution interrompue. Relancer la paire pour réconcilier son état."
                if !runs[i].dryRun, let p = pairs.firstIndex(where: { $0.id == runs[i].pair.id }) {
                    pairs[p].lastOutcome = "error"
                    pairs[p].lastMessage = runs[i].message
                    pairs[p].nextRetryAt = Date().addingTimeInterval(120)
                }
                try writeReport(runs[i])
            }
            for i in pairs.indices where pairs[i].lastOutcome == "running" {
                pairs[i].lastOutcome = "error"
                pairs[i].lastMessage = "Synchronisation interrompue ; nouvelle vérification nécessaire."
                pairs[i].nextRetryAt = Date().addingTimeInterval(120)
            }
            try saveState()
            if let text = try? String(contentsOf: disk.journal, encoding: .utf8) {
                journalLines = Array(text.components(separatedBy: .newlines).suffix(240)).map(SyncDiagnostic.clean)
            }
        } catch { storageError = error.localizedDescription }
        if automatic && storageError == nil { startWatching() }
        refreshBadge()
    }

    deinit {
        stopWatching()
        timer?.invalidate()
        if let observer = wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        if lockFD >= 0 { Darwin.close(lockFD) }
    }

    var isPaused: Bool { pausedUntil != nil }
    var isDryRun: Bool { active?.dryRun ?? false }
    var busy: Bool { runningPairID != nil }
    func cooldownUntil(for pair: SyncPair) -> Date? { cooldowns[pair.remote].flatMap { $0 > Date() ? $0 : nil } }

    func validationError(_ pair: SyncPair) -> String? {
        let path = URL(fileURLWithPath: expandedPath(pair.localPath)).resolvingSymlinksInPath().standardized.path
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return "Dossier local introuvable : \(path)" }
        guard path != "/", path != NSHomeDirectory() else { return "Choisir un sous-dossier dédié, pas la racine ou le dossier personnel." }
        let reserved = [disk.base.path, disk.logs.path, mountPath(), desktopPath()]
        if reserved.contains(where: { Self.overlap(path, $0) }) { return "Ce dossier chevauche l’archivage du Bureau, le montage Drive ou les données de l’application. Choisir un dossier séparé." }
        let remote = pair.remote
        guard !remote.isEmpty, !remote.contains(":"), !remote.contains(","), !remote.contains("/"), !remote.contains("\n"), !remote.contains("\r") else { return "Nom de remote rclone invalide." }
        if let id = pair.driveFolderID, !DriveFolderLink.validID(id) { return "Identifiant de dossier Drive invalide. Coller le lien du dossier, pas son nom." }
        let parts = pair.drivePath.split(separator: "/", omittingEmptySubsequences: false)
        let validPath = pair.drivePath.isEmpty ? pair.driveFolderID != nil : !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
        guard validPath,
              !pair.drivePath.contains(":"), !pair.drivePath.contains("\n"), !pair.drivePath.contains("\r"),
              !pair.drivePath.lowercased().hasPrefix(".pkarchives-recovery") else { return "Choisir un chemin Drive relatif non vide, sans « .. » ni préfixe remote." }
        guard !pair.ignores.contains(where: { $0.contains("\n") || $0.contains("\r") }) else { return "Un seul motif d’exclusion par ligne." }
        for other in pairs where other.id != pair.id {
            if Self.overlap(path, other.localPath) { return "Ce dossier chevauche la paire « \(other.name) »." }
            if other.remote == remote && other.driveFolderID == pair.driveFolderID &&
                (pair.drivePath.isEmpty || other.drivePath.isEmpty || Self.overlap(pair.drivePath, other.drivePath)) {
                return "La destination Drive chevauche la paire « \(other.name) »."
            }
        }
        if let expected = pair.volumeUUID, let actual = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString, expected != actual {
            return "Le volume de ce dossier a changé. Vérifier puis sélectionner à nouveau le dossier."
        }
        return nil
    }

    static func overlap(_ lhs: String, _ rhs: String) -> Bool {
        let a = URL(fileURLWithPath: lhs).resolvingSymlinksInPath().standardized.path.lowercased()
        let b = URL(fileURLWithPath: rhs).resolvingSymlinksInPath().standardized.path.lowercased()
        return a == b || a.hasPrefix(b + "/") || b.hasPrefix(a + "/")
    }

    @discardableResult func savePair(_ input: SyncPair) -> Bool {
        guard !busy, storageError == nil else { return false }
        var pair = input
        pair.localPath = URL(fileURLWithPath: expandedPath(pair.localPath)).resolvingSymlinksInPath().standardized.path
        pair.drivePath = pair.drivePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = validationError(pair) { progressText = error; return false }
        pair.remoteOverride = pair.remote
        if pair.name.isEmpty { pair.name = URL(fileURLWithPath: pair.localPath).lastPathComponent }
        pair.volumeUUID = try? URL(fileURLWithPath: pair.localPath).resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
        if let i = pairs.firstIndex(where: { $0.id == pair.id }) {
            let previous = pairs[i]
            let changed = previous.localPath != pair.localPath || previous.target != pair.target || previous.direction != pair.direction || previous.ignores != pair.ignores
            if changed {
                pair.needsResync = pair.direction.usesBisync
                pair.lastOutcome = "pending"; pair.lastRun = nil; pair.lastMessage = nil
                pair.nextRetryAt = nil; pair.consecutiveFailures = 0
                queue.removeAll { $0.pairID == pair.id }
            }
            pairs[i] = pair
        } else {
            pair.needsResync = pair.direction.usesBisync
            pairs.append(pair)
        }
        if !pair.enabled { localDue[pair.id] = nil; queue.removeAll { $0.pairID == pair.id } }
        persist()
        if automatic { startWatching() }
        return storageError == nil
    }

    func deletePair(_ id: UUID) {
        guard !busy else { return }
        queue.removeAll { $0.pairID == id }
        localDue[id] = nil
        pairs.removeAll { $0.id == id }
        // Keep recovery copies, previous listings and reports. Removing a pair never deletes files.
        persist()
        if automatic { startWatching() }
    }

    func syncAll(dryRun: Bool = false) {
        for pair in pairs where pair.enabled && cooldownUntil(for: pair) == nil && (dryRun || pair.previewOnly || !pair.direction.usesBisync || !pair.needsResync) {
            enqueue(SyncJob(pairID: pair.id, dryRun: dryRun || pair.previewOnly, resync: pair.direction.usesBisync && pair.needsResync))
        }
        startNext()
    }
    func syncPair(_ id: UUID, dryRun: Bool = false, resync: Bool = false) {
        guard let p = pairs.first(where: { $0.id == id }), !p.direction.usesBisync || !p.needsResync || resync || dryRun else {
            progressText = syncText("needsResync"); return
        }
        guard cooldownUntil(for: p) == nil else { progressText = SyncDiagnostic(kind: .quota, details: "").summary; return }
        // Only an explicit per-pair real-run action activates live syncing. Global/automatic
        // actions always respect previewOnly and cannot silently promote a preview.
        if !dryRun, storageError == nil, !busy, let i = pairs.firstIndex(where: { $0.id == id }) {
            pairs[i].previewOnly = false
            persist()
        }
        enqueue(SyncJob(pairID: id, dryRun: dryRun, resync: resync || (dryRun && p.needsResync)))
        startNext()
    }
    func retryFailed() {
        for pair in pairs where pair.enabled && pair.lastOutcome == "error" && !pair.needsResync {
            enqueue(SyncJob(pairID: pair.id, dryRun: pair.previewOnly, resync: false))
        }
        startNext()
    }
    /// Replay reconciles the *current* pair, not an obsolete file operation or shell command.
    func replay(_ run: SyncRun) {
        guard let pair = pairs.first(where: { $0.id == run.pair.id }) else { return }
        syncPair(run.pair.id, dryRun: run.dryRun || pair.previewOnly)
    }
    func stopRunning() { cancelled = true; process?.interrupt() }
    func pauseForHours(_ hours: Double) { pausedUntil = Date().addingTimeInterval(hours * 3600); schedule(); refreshBadge() }
    func resume() { pausedUntil = nil; startNext(); schedule(); refreshBadge() }
    func shutdown() { shuttingDown = true; queue.removeAll(); stopWatching(); timer?.invalidate(); stopRunning() }

    /// True while any inventory request is running or waiting (transfers keep priority).
    var inventoryActive: Bool { inventoryBusy || !inventoryQueue.isEmpty }

    /// Duration to reconcile the size gap at the reference throughput. Explicitly a rough figure:
    /// modified-on-both-sides files and per-file overhead are unknown without a preview.
    static func etaText(_ gapBytes: Int64) -> String {
        let seconds = Double(gapBytes) / Double(referenceThroughput)
        if seconds < 60 { return syncText("etaSeconds") }
        if seconds < 3600 { return "\(Int(seconds / 60)) min" }
        return "\(Int(seconds / 3600)) h \(Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)) min"
    }
    static func byteText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    static func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total) s" }
        if total < 3600 { return "\(total / 60) min \(total % 60) s" }
        return "\(total / 3600) h \((total % 3600) / 60) min"
    }

    // MARK: - Inventory (file/byte counts per pair)
    /// Bytes per second used for the alignment estimate. Reference value, not a measurement:
    /// the true duration depends on the exact operations listed by a preview.
    static let referenceThroughput: Int64 = 4 * 1024 * 1024
    private static let sizeFlags = ["--tpslimit", "4", "--tpslimit-burst", "4", "--checkers", "2", "--retries", "1",
                                    "--low-level-retries", "12", "--drive-pacer-burst", "20", "--contimeout", "15s", "--timeout", "2m"]

    func refreshInventory(_ id: UUID) {
        guard storageError == nil, !shuttingDown, !inventoryBusy,
              pairs.contains(where: { $0.id == id }), !inventoryQueue.contains(id) else { return }
        inventoryQueue.append(id)
        drainInventories()
    }
    func refreshAllInventories() { pairs.forEach { refreshInventory($0.id) } }

    /// Serialized with transfers: never a second rclone while a run is executing. Retried after
    /// each completion and on scheduler ticks, so a busy engine simply delays the counting.
    private func drainInventories() {
        guard !inventoryBusy, !busy, !isPaused, storageError == nil, !shuttingDown,
              let id = inventoryQueue.first,
              let pair = pairs.first(where: { $0.id == id }) else { return }
        inventoryQueue.removeFirst()
        inventoryBusy = true
        refreshBadge()
        let filter = inventoryFilterURL(pair)
        let deferred = cooldownUntil(for: pair) != nil
        let localArgs = ["size", pair.localPath, "--json", "--filter-from", filter.path] + Self.sizeFlags
        let remoteArgs = deferred ? nil : ["size", pair.target, "--json", "--filter-from", filter.path] + Self.sizeFlags
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let local = self?.runCommand(localArgs) ?? (-1, "")
            let remote = remoteArgs.map { self?.runCommand($0) ?? (-1, "") }
            DispatchQueue.main.async {
                guard let self else { return }
                self.applyInventory(local: local, remote: remote, deferred: deferred, pair: pair)
                self.inventoryBusy = false
                self.refreshBadge()
                self.drainInventories()
                self.startNext()
            }
        }
    }
    private func inventoryFilterURL(_ pair: SyncPair) -> URL {
        let url = disk.base.appendingPathComponent("inventory/\(pair.id)-filters.txt")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? (["- /.PKarchives-recovery/**"] + pair.ignores.map { "- \($0)" })
            .joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    private func applyInventory(local: (exit: Int32, output: String), remote: (exit: Int32, output: String)?, deferred: Bool, pair: SyncPair) {
        var inventory = inventories[pair.id] ?? PairInventory()
        if local.exit == 0, let parsed = Self.parseSize(local.output) {
            inventory.localFiles = parsed.count; inventory.localBytes = parsed.bytes; inventory.localAt = Date()
        }
        if let remote {
            if remote.exit == 0, let parsed = Self.parseSize(remote.output) {
                inventory.remoteFiles = parsed.count; inventory.remoteBytes = parsed.bytes; inventory.remoteAt = Date()
                inventory.remoteDeferred = false
            } else {
                // Keep the previous counts; a quota refusal also extends the shared cooldown.
                inventory.remoteDeferred = true
                if SyncDiagnostic.classify([remote.output]).kind == .quota {
                    cooldowns[pair.remote] = Date().addingTimeInterval(900)
                }
            }
        } else { inventory.remoteDeferred = true }
        inventories[pair.id] = inventory
        persist()
        let localText = inventory.localFiles.map { "\($0)" } ?? "?"
        let remoteText = inventory.remoteFiles.map { "\($0)" } ?? (deferred ? syncText("remoteDeferred") : "?")
        try? log("Inventaire · \(pair.name) · \(syncText("localSide")) \(localText) · \(syncText("remoteSide")) \(remoteText)")
    }
    static func parseSize(_ output: String) -> (count: Int, bytes: Int64)? {
        guard let start = output.lastIndex(of: "{"), let end = output.lastIndex(of: "}"), start < end,
              let data = output[start...end].data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let count = json["count"] as? Int,
              let bytes = (json["bytes"] as? NSNumber)?.int64Value else { return nil }
        return (count, bytes)
    }
    /// Small synchronous helper for one-shot commands whose output fits in memory (rclone size --json).
    private func runCommand(_ args: [String]) -> (exit: Int32, output: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary.contains("/") ? binary : "/usr/bin/env")
        proc.arguments = binary.contains("/") ? args : [binary] + args
        proc.qualityOfService = .utility
        var environment = ProcessInfo.processInfo.environment
        environment["GOMEMLIMIT"] = "128MiB"
        proc.environment = environment
        let pipe = Pipe()
        proc.standardOutput = pipe; proc.standardError = pipe
        do { try proc.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return (proc.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    private func enqueue(_ job: SyncJob) {
        guard storageError == nil, !shuttingDown, !queue.contains(job), active.map({ $0.pair.id == job.pairID && $0.dryRun == job.dryRun }) != true else { return }
        queue.append(job)
        refreshBadge()
    }
    private func startNext() {
        guard !busy, !inventoryBusy, !isPaused, !shuttingDown, storageError == nil else { return }
        queue.removeAll { job in !pairs.contains(where: { $0.id == job.pairID && $0.enabled }) }
        if let index = queue.firstIndex(where: { job in pairs.first(where: { $0.id == job.pairID }).map { cooldownUntil(for: $0) == nil } ?? false }) {
            let job = queue.remove(at: index)
            guard let pair = pairs.first(where: { $0.id == job.pairID }) else { return }
            begin(pair, job: job)
            return
        }
        refreshBadge(); drainInventories(); schedule()
    }

    private func begin(_ pair: SyncPair, job: SyncJob) {
        let id = UUID()
        let dir = disk.logs.appendingPathComponent("runs/\(id)")
        var run = SyncRun(pair: pair, dryRun: job.dryRun, resync: job.resync, directory: dir.path)
        run.id = id
        active = run; runningPairID = pair.id; cancelled = false; verifying = false; skippedUnsupportedObject = false
        runProgress = RunProgress()
        activePlan = job.dryRun ? PreviewPlan() : nil
        planResyncDirection = nil
        runRevision = revisions[pair.id, default: 0]
        progressText = job.dryRun ? syncText("simulating") : syncText("running")
        if !job.dryRun, let i = pairs.firstIndex(where: { $0.id == pair.id }) {
            pairs[i].lastOutcome = "running"; pairs[i].nextRetryAt = nil
        }
        runs.insert(run, at: 0); runs = Array(runs.prefix(80))
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try SyncDisk.append("\(job.dryRun ? "SIMULATION — fichiers inchangés" : "SYNCHRONISATION") · \(pair.name) · \(Self.stamp(run.started))", to: dir.appendingPathComponent("operations.log"))
            try saveState(); try writeReport(run)
            try log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\(Self.stamp(run.started))  ·  \(pair.name)  ·  \(job.dryRun ? "SIMULATION — aucune écriture des fichiers" : "SYNCHRONISATION")\n\(pair.localPath)  \(pair.direction.arrow)  \(pair.target)\nRapport : \(dir.path)/rapport.md")
            if let error = validationError(pair) { throw SyncFailure.message(error) }
            if pair.direction.usesBisync && pair.needsResync && !job.resync { throw SyncFailure.message(syncText("needsResync")) }
            let work: URL
            if job.dryRun {
                // bisync writes listings even with --dry-run. Never expose live state to a preview.
                work = dir.appendingPathComponent("preview-state")
                let real = disk.workdir(pair.id)
                if FileManager.default.fileExists(atPath: real.path) { try FileManager.default.copyItem(at: real, to: work) }
                else { try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true) }
                // The copy may contain an interruption lock; it does not own the active state.
                for file in try FileManager.default.contentsOfDirectory(at: work, includingPropertiesForKeys: nil) where file.pathExtension == "lck" {
                    try FileManager.default.removeItem(at: file)
                }
            } else {
                work = disk.workdir(pair.id)
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            }
            let filter = work.appendingPathComponent("filters.txt")
            // A folder-link destination is itself the remote root. Keep recovery copies in
            // an explicitly excluded namespace on that SAME scoped remote (rclone requires it).
            try (["- /.PKarchives-recovery/**"] + pair.ignores.map { "- \($0)" })
                .joined(separator: "\n").appending("\n").write(to: filter, atomically: true, encoding: .utf8)
            let args = transferArguments(run, work: work, filter: filter)
            execute(args, logURL: dir.appendingPathComponent("rclone.jsonl")) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error): self.complete("error", message: error.localizedDescription)
                case .success(let exit):
                    if self.cancelled { self.complete("cancelled", message: "Arrêt demandé. Rien n’est déclaré vérifié.") }
                    else if exit != 0 { self.failedProcess(exit, at: dir.appendingPathComponent("rclone.jsonl")) }
                    else if job.dryRun { self.complete("preview", message: "Simulation terminée. Aucune sauvegarde effectuée, aucun état vérifié modifié.") }
                    else {
                        // Listings were committed by a successful real bisync. If the subsequent
                        // check fails, retry normal reconciliation, not a destructive reinitialization.
                        if run.pair.direction.usesBisync, let i = self.pairs.firstIndex(where: { $0.id == run.pair.id }) {
                            self.pairs[i].needsResync = false
                            self.persist()
                        }
                        self.verify(run, filter: filter)
                    }
                }
            }
        } catch { complete("error", message: error.localizedDescription) }
    }

    // A 403 quota refusal is per-minute: retry with growing backoff so a listing waits out the
    // saturated minute instead of aborting the whole comparison two seconds in.
    static let lightFlags = ["--transfers", "2", "--checkers", "2", "--buffer-size", "4M", "--drive-chunk-size", "8M",
                             "--max-buffer-memory", "32M", "--max-backlog", "256", "--multi-thread-streams", "0",
                             "--tpslimit", "4", "--tpslimit-burst", "4", "--retries", "1", "--low-level-retries", "12",
                             "--drive-pacer-burst", "20",
                             "--contimeout", "15s", "--timeout", "2m", "--stats", "5s", "--use-json-log", "--log-level", "INFO"]

    func transferArguments(_ run: SyncRun, work: URL, filter: URL) -> [String] {
        let p = run.pair
        var args: [String]
        if p.direction.usesBisync {
            args = ["bisync", p.localPath, p.target, "--workdir", work.path, "--filters-file", filter.path,
                    "--check-sync", "true", "--resilient", "--recover", "--max-lock", "2m", "--max-delete", "50",
                    "--conflict-resolve", p.conflictPolicy.argument, "--conflict-loser", "num", "--conflict-suffix", "conflict"]
            if run.resync { args += ["--resync-mode", p.conflictPolicy.argument] }
        } else {
            let source = p.direction == .push ? p.localPath : p.target
            let dest = p.direction == .push ? p.target : p.localPath
            args = ["copy", source, dest, "--checksum", "--filter-from", filter.path]
        }
        if run.dryRun { args += ["--dry-run"] }
        else {
            // Non-overlapping destinations on each respective filesystem. No automatic purge.
            let localBackup = disk.base.appendingPathComponent("recovery/\(p.id)/\(run.id)").path
            let remoteBackup = "\(p.endpoint):.PKarchives-recovery/\(p.id)/\(run.id)"
            if p.direction.usesBisync { args += ["--backup-dir1", localBackup, "--backup-dir2", remoteBackup] }
            else { args += ["--backup-dir", p.direction == .push ? remoteBackup : localBackup] }
        }
        return args + Self.lightFlags
    }

    private func verify(_ run: SyncRun, filter: URL) {
        hasUncheckedHashes = false
        verifying = true
        progressText = syncText("verifying")
        refreshBadge()
        let pair = run.pair
        let source = pair.direction == .pull ? pair.target : pair.localPath
        let dest = pair.direction == .pull ? pair.localPath : pair.target
        let dir = URL(fileURLWithPath: run.directory)
        var args = ["check", source, dest, "--filter-from", filter.path, "--combined", dir.appendingPathComponent("verification.txt").path]
        if !pair.direction.usesBisync { args += ["--one-way"] }
        execute(args + Self.lightFlags, logURL: dir.appendingPathComponent("verification.jsonl")) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error): self.complete("error", message: error.localizedDescription)
            case .success(let exit):
                if self.cancelled { self.complete("cancelled", message: "Vérification interrompue. Rien n’est déclaré vérifié.") }
                else if exit != 0 { self.failedProcess(exit, at: dir.appendingPathComponent("verification.jsonl")) }
                else if self.hasUncheckedHashes || self.skippedUnsupportedObject || self.uncheckedHashes(at: dir.appendingPathComponent("verification.jsonl")) {
                    self.complete("unverified", message: "Copie terminée, mais certaines empreintes ou certains objets (par exemple un lien symbolique non suivi) n’ont pas pu être vérifiés. Sauvegarde NON déclarée vérifiée.")
                } else if self.revisions[pair.id, default: 0] != self.runRevision {
                    self.complete("pending", message: "Des changements locaux sont survenus pendant le contrôle. Nouvelle vérification en attente.")
                } else {
                    self.complete("verified", message: "Contenus inclus vérifiés par taille et empreinte à cette date. Les exclusions ne sont pas sauvegardées.")
                }
            }
        }
    }

    /// Drain UTF-8 by whole lines on one worker, with bounded memory. Completion is dispatched only
    /// after EOF, so final errors cannot race against the process exit callback.
    private func execute(_ args: [String], logURL: URL, completion: @escaping (Result<Int32, Error>) -> Void) {
        processErrors = []
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary.contains("/") ? binary : "/usr/bin/env")
        proc.arguments = binary.contains("/") ? args : [binary] + args
        proc.qualityOfService = .utility
        var environment = ProcessInfo.processInfo.environment
        environment["GOMEMLIMIT"] = "128MiB" // Soft Go GC target, not a hard RSS cap.
        proc.environment = environment
        let pipe = Pipe()
        proc.standardOutput = pipe; proc.standardError = pipe
        process = proc
        do { try proc.run() } catch { process = nil; completion(.failure(error)); return }
        var startupError: Error?
        do {
            if var run = active {
                run.processID = proc.processIdentifier
                active = run
                if let i = runs.firstIndex(where: { $0.id == run.id }) { runs[i] = run }
                try writeReport(run); try saveState()
            }
        } catch { startupError = error; proc.interrupt() }
        let durableStartError = startupError
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var buffer = Data()
            var loggingError: Error?
            do {
                let handle = try FileHandle(forWritingTo: Self.makeLog(logURL))
                defer { try? handle.close() }
                while true {
                    let chunk = pipe.fileHandleForReading.availableData
                    if chunk.isEmpty { break }
                    try handle.write(contentsOf: chunk)
                    buffer.append(chunk)
                    while let end = buffer.firstIndex(of: 10) {
                        let line = String(decoding: buffer[..<end], as: UTF8.self)
                        buffer.removeSubrange(...end)
                        DispatchQueue.main.async { self?.ingest(line) }
                    }
                    if buffer.count > 256 * 1024 { buffer.removeAll(keepingCapacity: true) }
                }
                if !buffer.isEmpty {
                    let line = String(decoding: buffer, as: UTF8.self)
                    DispatchQueue.main.async { self?.ingest(line) }
                }
            } catch {
                loggingError = error
                proc.interrupt()
                // Do not leave a child blocked on a full pipe after a disk-write failure.
                while !pipe.fileHandleForReading.availableData.isEmpty {}
            }
            proc.waitUntilExit()
            let exit = proc.terminationStatus
            let failure = loggingError ?? durableStartError
            DispatchQueue.main.async {
                self?.process = nil
                if let failure { completion(.failure(failure)) } else { completion(.success(exit)) }
            }
        }
    }
    private static func makeLog(_ url: URL) throws -> URL {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw SyncFailure.message("Impossible de créer \(url.path)") }
        return url
    }
    private func ingest(_ line: String) {
        guard let data = line.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let message = SyncDiagnostic.clean(json["msg"] as? String ?? "")
        let object = json["object"] as? String ?? ""
        if var progress = runProgress {
            Self.apply(message: message, object: object, to: &progress)
            if verifying { progress.phase = .verifying }
            runProgress = progress
        }
        if activePlan != nil {
            let oneWay: Bool? = active.map { $0.pair.direction == .bidirectional ? nil : $0.pair.direction == .push } ?? nil
            Self.applyPlan(message: message, object: object, to: &activePlan!, resyncDirection: &planResyncDirection, oneWay: oneWay)
        }
        if json["level"] as? String == "error", processErrors.count < 64 { processErrors.append(String(message.prefix(8192))) }
        if message.lowercased().contains("hashes could not be checked") || message.lowercased().contains("no hashes in common") { hasUncheckedHashes = true }
        if message.lowercased().contains("can't follow symlink") || message.lowercased().contains("can't transfer non file/directory") { skippedUnsupportedObject = true }
        if let stats = json["stats"] as? [String: Any], Date().timeIntervalSince(lastStat) > 1 {
            lastStat = Date()
            if var progress = runProgress {
                Self.apply(stats: stats, to: &progress)
                if verifying { progress.phase = .verifying }
                runProgress = progress
            }
            let bytes = (stats["bytes"] as? NSNumber)?.int64Value ?? 0
            progressText = "\(syncText(isDryRun ? "simulating" : verifying ? "verifying" : "running")) · \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
        }
        if json["level"] as? String == "error" || message.contains("Skipped") || message.contains("Copied") || message.contains("Deleted") || message.lowercased().contains("conflict") || message.lowercased().contains("can't follow symlink") {
            let object = json["object"] as? String ?? ""
            let readable = "  \(json["level"] as? String == "error" ? "✗" : "·") \(object) \(message)"
            do {
                try log(readable)
                if let active { try SyncDisk.append(readable, to: URL(fileURLWithPath: active.directory).appendingPathComponent("operations.log")) }
            }
            catch { storageError = error.localizedDescription; cancelled = true; process?.interrupt() }
        }
    }
    static func apply(message rawMessage: String, object: String, to progress: inout RunProgress) {
        let message = SyncDiagnostic.clean(rawMessage)
        let text = message.lowercased()
        if text.contains("queue copy to path2") { progress.pushPlanned += 1 }
        else if text.contains("queue copy to path1") { progress.pullPlanned += 1 }
        else if text.contains("queue delete") {
            if text.contains("path2") { progress.deleteRemotePlanned += 1 } else { progress.deleteLocalPlanned += 1 }
        }
        if text.contains("do queued copies to path1") { progress.phase = .pull }
        else if text.contains("do queued copies to path2") { progress.phase = .push }
        else if text.contains("do queued deletes") || text.contains("applying changes") { progress.phase = .deleting }
        if message.hasPrefix("Copied (") {
            switch progress.phase {
            case .pull: progress.pullDone += 1
            case .push: progress.pushDone += 1
            default: break
            }
        } else if message == "Deleted" || message.hasPrefix("Deleted ") {
            progress.deleteDone += 1
        }
        _ = object
    }
    static func apply(stats: [String: Any], to progress: inout RunProgress) {
        if let value = (stats["transfers"] as? NSNumber)?.intValue { progress.transfersDone = value }
        if let value = (stats["totalTransfers"] as? NSNumber)?.intValue { progress.transfersTotal = value }
        if let value = (stats["bytes"] as? NSNumber)?.int64Value { progress.bytesDone = value }
        if let value = (stats["totalBytes"] as? NSNumber)?.int64Value { progress.bytesTotal = value }
        if let value = (stats["speed"] as? NSNumber)?.doubleValue { progress.speed = value }
        if let value = (stats["listed"] as? NSNumber)?.int64Value { progress.listed = value }
        if let value = (stats["elapsedTime"] as? NSNumber)?.doubleValue { progress.elapsed = value }
        if let value = stats["eta"] as? NSNumber { progress.eta = value.doubleValue } else if stats["eta"] is NSNull { progress.eta = nil }
    }
    /// Reads bisync's per-file lines. Path1 = local folder, Path2 = Drive destination.
    /// A deleted file on Path1 becomes a Drive deletion, and the reverse.
    /// On a first merge (resync) rclone lists copies under "copying files to Path1/Path2"
    /// headers, with the path in the `object` field instead of the message.
    static func applyPlan(message rawMessage: String, object: String, to plan: inout PreviewPlan, resyncDirection: inout String?, oneWay: Bool? = nil) {
        let text = SyncDiagnostic.clean(rawMessage)
        let lower = text.lowercased()
        if let oneWay {
            if lower.contains("skipped copy") || text.hasPrefix("Copied (") {
                guard !object.isEmpty else { return }
                add(object, to: oneWay ? \.pushNew : \.pullNew, plan: &plan, limit: 5000)
                return
            }
        }
        let isCopyHeader = lower.contains("files to path1") || lower.contains("files to path2") || lower.contains("copying files to")
        if isCopyHeader {
            let lastPath1 = lower.range(of: "path1", options: .backwards)?.lowerBound
            let lastPath2 = lower.range(of: "path2", options: .backwards)?.lowerBound
            if let lastPath1, let lastPath2 { resyncDirection = lastPath1 > lastPath2 ? "pull" : "push" }
            else if lastPath1 != nil { resyncDirection = "pull" }
            else if lastPath2 != nil { resyncDirection = "push" }
            return
        }
        if let direction = resyncDirection, lower.contains("skipped copy") || text.hasPrefix("Copied (") {
            guard !object.isEmpty else { return }
            add(object, to: direction == "push" ? \.pushNew : \.pullNew, plan: &plan, limit: 5000)
            return
        }
        guard text.hasPrefix("- Path1") || text.hasPrefix("- Path2") else { return }
        let isLocalSide = text.hasPrefix("- Path1")
        guard let separator = text.range(of: " - ", options: .backwards) else { return }
        let path = String(text[separator.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !path.contains("\n") else { return }
        let limit = 5000
        if lower.contains("file is new") || lower.contains("directory is new") {
            add(path, to: isLocalSide ? \.pushNew : \.pullNew, plan: &plan, limit: limit)
        } else if lower.contains("file changed") || lower.contains("directory changed") {
            add(path, to: isLocalSide ? \.pushModified : \.pullModified, plan: &plan, limit: limit)
        } else if lower.contains("was deleted") {
            add(path, to: isLocalSide ? \.deleteRemote : \.deleteLocal, plan: &plan, limit: limit)
        }
    }
    private static func add(_ path: String, to keyPath: WritableKeyPath<PreviewPlan, [String]>, plan: inout PreviewPlan, limit: Int) {
        guard !plan[keyPath: keyPath].contains(path) else { return }
        if plan[keyPath: keyPath].count >= limit { plan.truncated = true; return }
        plan[keyPath: keyPath].append(path)
    }
    /// A file modified on both sides is a conflict, resolved by the pair's conflict policy.
    /// Counted once, outside the push/pull lists, so totals are not doubled.
    static func finalizePlan(_ plan: PreviewPlan) -> PreviewPlan {
        var result = plan
        let shared = Set(plan.pushModified).intersection(Set(plan.pullModified))
        if !shared.isEmpty {
            result.pushModified = plan.pushModified.filter { !shared.contains($0) }
            result.pullModified = plan.pullModified.filter { !shared.contains($0) }
            let conflicts = shared.sorted()
            result.conflicts = Array(conflicts.prefix(5000))
            if conflicts.count > 5000 { result.truncated = true }
        }
        result.pushNew.sort(); result.pushModified.sort(); result.pullNew.sort(); result.pullModified.sort()
        result.deleteRemote.sort(); result.deleteLocal.sort()
        return result
    }
    private func failedProcess(_ exit: Int32, at logURL: URL) {
        let lines = processErrors + Self.errorMessages(in: Self.tail(logURL, bytes: 32 * 1024))
        let diagnostic = SyncDiagnostic.classify(lines.isEmpty ? ["rclone a quitté avec le code \(exit)"] : lines)
        active?.diagnostic = diagnostic
        complete(diagnostic.outcome, message: diagnostic.summary)
    }
    private static func errorMessages(in text: String) -> [String] {
        text.components(separatedBy: .newlines).compactMap { line -> String? in
            guard let data = line.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any], j["level"] as? String == "error" else { return nil }
            return j["msg"] as? String
        }
    }
    private func uncheckedHashes(at url: URL) -> Bool {
        // rclone reports size-only fallbacks even when exit code is zero.
        let text = Self.tail(url, bytes: 64 * 1024).lowercased()
        return text.contains("hashes could not be checked") || text.contains("no hashes in common")
    }
    private static func tail(_ url: URL, bytes: UInt64) -> String {
        guard let h = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        try? h.seek(toOffset: size > bytes ? size - bytes : 0)
        return String(decoding: (try? h.readToEnd()) ?? Data(), as: UTF8.self)
    }

    private func complete(_ outcome: String, message: String) {
        guard var run = active else { return }
        run.outcome = outcome; run.message = message; run.finished = Date()
        if run.dryRun, outcome == "preview", var plan = activePlan {
            let inventory = inventories[run.pair.id]
            plan.localFiles = inventory?.localFiles
            plan.remoteFiles = inventory?.remoteFiles
            plan.countedAt = inventory?.remoteAt ?? inventory?.localAt
            run.plan = Self.finalizePlan(plan)
        }
        activePlan = nil
        planResyncDirection = nil
        if run.diagnostic?.kind == .quota { cooldowns[run.pair.remote] = Date().addingTimeInterval(900) }
        if let r = runs.firstIndex(where: { $0.id == run.id }) { runs[r] = run }
        if !run.dryRun, let i = pairs.firstIndex(where: { $0.id == run.pair.id }) {
            pairs[i].lastOutcome = outcome; pairs[i].lastMessage = message
            if outcome == "verified" {
                pairs[i].lastRun = Date(); pairs[i].needsResync = false
                pairs[i].consecutiveFailures = 0; pairs[i].nextRetryAt = nil
            } else if outcome == "needsResync" {
                pairs[i].needsResync = true; pairs[i].nextRetryAt = nil
            } else if outcome == "rateLimited" {
                pairs[i].nextRetryAt = pairs[i].direction.usesBisync && pairs[i].needsResync ? nil : cooldowns[run.pair.remote]
            } else if outcome == "error" || outcome == "unverified" {
                pairs[i].consecutiveFailures += 1
                let manual = run.diagnostic.map { [.storage, .authentication, .permission, .notFound, .safety].contains($0.kind) } ?? false
                pairs[i].nextRetryAt = manual ? nil : Date().addingTimeInterval(Self.retryDelay(pairs[i].consecutiveFailures))
            } else if outcome == "pending" {
                pairs[i].nextRetryAt = Date().addingTimeInterval(45)
            }
        }
        do {
            try writeReport(run)
            try log("\(outcome == "verified" ? "✓" : outcome == "preview" ? "◌" : "⚠") \(message)\nÉtat : \(outcome) · \(Int(run.finished!.timeIntervalSince(run.started))) s\nRelance : Synchronisation → Historique relançable → Relancer la paire\n")
            try saveState()
        } catch { storageError = error.localizedDescription }
        active = nil; runningPairID = nil; progressText = message; process = nil
        runProgress = nil
        refreshBadge()
        startNext()
        drainInventories()
    }
    static func retryDelay(_ failures: Int) -> TimeInterval { [120.0, 300, 900, 1800, 3600][min(max(failures - 1, 0), 4)] }
    private func writeReport(_ run: SyncRun) throws {
        let dir = URL(fileURLWithPath: run.directory)
        try disk.save(run, to: dir.appendingPathComponent("run.json"))
        try reportText(run).write(to: dir.appendingPathComponent("rapport.md"), atomically: true, encoding: .utf8)
    }
    /// Latest preview that carries a per-file comparison, for the pair's card.
    func previewRun(for pairID: UUID) -> SyncRun? {
        runs.first { $0.pair.id == pairID && $0.plan != nil }
    }
    func readableReportURL(for run: SyncRun) -> URL? {
        // Leave historical raw reports intact. Generate a separate, decoded reading copy.
        let url = URL(fileURLWithPath: run.directory).appendingPathComponent("rapport-lecture.md")
        do { try reportText(run).write(to: url, atomically: true, encoding: .utf8); return url }
        catch { storageError = error.localizedDescription; return nil }
    }
    private func reportText(_ run: SyncRun) -> String {
        let explanation = run.diagnostic?.summary ?? SyncDiagnostic.clean(run.message)
        let action = run.diagnostic.map { syncText($0.helpKey) } ?? ""
        let waiting = cooldownUntil(for: run.pair).map { "Réessayer après : \(Self.stamp($0))" } ?? ""
        return """
        # PKarchives · \(run.dryRun ? "Simulation — aucun fichier modifié" : "Synchronisation")

        **Dossier :** \(run.pair.name)
        **Début :** \(Self.stamp(run.started))
        **Résultat :** \(syncText(run.diagnostic?.titleKey ?? run.outcome))

        \(explanation)

        \(action)

        \(waiting)

        - Mac : `\(run.pair.localPath)`
        - Remote : `\(run.pair.target)`
        - Direction : \(run.pair.direction.arrow)
        - Exclusions (non sauvegardées) : \(run.pair.ignores.joined(separator: ", "))

        ## Détails et relance

        \(Self.comparisonText(run.plan))

        [Opérations prévues/effectuées et erreurs, en texte lisible](operations.log)

        `rclone.jsonl` contient les opérations et erreurs détaillées.
        `verification.txt` : « = » identique, « + » manquant à destination, « * » différent, « ! » erreur.
        Relancer depuis **PKarchives → Synchronisation → Paires → Simuler** puis vérifier la comparaison.
        La relance réconcilie la configuration actuelle, elle ne rejoue pas aveuglément une commande.
        Une simulation ne vaut jamais sauvegarde. Une synchronisation n’est pas une sauvegarde immuable.
        Les versions remplacées/supprimées sont conservées sous `.PKarchives-recovery/` sur le remote
        (à l’intérieur du dossier sélectionné par lien, toujours exclu des transferts et contrôles)
        et sous `Application Support/PKarchives/recovery/` côté Mac (aucune purge automatique).
        """
    }
    /// Human-readable comparison section for preview reports.
    static func comparisonText(_ plan: PreviewPlan?) -> String {
        guard let plan else { return "" }
        let unchanged = plan.unchanged.map(String.init) ?? "non calculé (inventaire absent)"
        var lines = [
            "## Comparaison Mac ↔ Drive",
            "",
            "- Identiques (non touchés) : \(unchanged)",
            "- À envoyer vers Drive : \(plan.pushNew.count) nouveaux, \(plan.pushModified.count) modifiés",
            "- À rapatrier vers le Mac : \(plan.pullNew.count) nouveaux, \(plan.pullModified.count) modifiés",
            "- À supprimer sur Drive (suppressions locales) : \(plan.deleteRemote.count)",
            "- À supprimer sur le Mac (suppressions Drive) : \(plan.deleteLocal.count)",
            "- Conflits arbitrés par la règle de la paire : \(plan.conflicts.count)",
        ]
        if plan.truncated { lines.append("- Liste tronquée à 5 000 entrées par catégorie.") }
        func section(_ title: String, _ items: [String]) {
            guard !items.isEmpty else { return }
            lines += ["", "### \(title)", ""] + items.prefix(50).map { "- `\($0)`" }
            if items.count > 50 { lines.append("- … et \(items.count - 50) autres (voir operations.log).") }
        }
        section("Nouveaux fichiers vers Drive", plan.pushNew)
        section("Fichiers modifiés vers Drive", plan.pushModified)
        section("Nouveaux fichiers vers le Mac", plan.pullNew)
        section("Fichiers modifiés vers le Mac", plan.pullModified)
        section("Suppressions sur Drive", plan.deleteRemote)
        section("Suppressions sur le Mac", plan.deleteLocal)
        section("Conflits", plan.conflicts)
        return lines.joined(separator: "\n")
    }
    private func saveState() throws {
        try disk.save(pairs, to: disk.config); try disk.save(runs, to: disk.history)
        try disk.save(cooldowns, to: disk.base.appendingPathComponent("cooldowns.json"))
        try disk.save(inventories, to: disk.base.appendingPathComponent("inventories.json"))
    }
    private func persist() {
        do { try saveState() } catch { storageError = error.localizedDescription }
        refreshBadge(); schedule()
    }
    private func log(_ text: String) throws {
        // Rotate the human-readable index, never delete per-run evidence or recovery copies.
        if let size = (try? FileManager.default.attributesOfItem(atPath: disk.journal.path))?[.size] as? Int, size > 512 * 1024 {
            let previous = disk.logs.appendingPathComponent("sync.previous.log")
            if FileManager.default.fileExists(atPath: previous.path) { try FileManager.default.removeItem(at: previous) }
            try FileManager.default.moveItem(at: disk.journal, to: previous)
        }
        let clean = SyncDiagnostic.clean(text)
        try SyncDisk.append(clean, to: disk.journal)
        journalLines.append(contentsOf: clean.components(separatedBy: .newlines))
        journalLines = Array(journalLines.suffix(240))
    }
    private func refreshBadge() {
        let badge = storageError != nil ? "⚠︎" : busy ? (isDryRun ? "◌" : "⟳") : isPaused ? "⏸" : pairs.contains(where: { ["error", "unverified", "needsResync", "rateLimited"].contains($0.lastOutcome) || cooldownUntil(for: $0) != nil }) ? "⚠︎" : "📦"
        if statusBadgeSubject != badge { statusBadgeSubject = badge }
    }
    static func stamp(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    // MARK: Event-driven scheduling. One one-shot timer for all jobs, no 20-second polling loop.
    private func stopWatching() {
        if let stream { FSEventStreamStop(stream); FSEventStreamInvalidate(stream); FSEventStreamRelease(stream) }
        stream = nil
    }
    private func startWatching() {
        stopWatching()
        let paths = pairs.filter { $0.enabled && $0.direction != .pull }.map(\.localPath)
        if !paths.isEmpty {
            var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
            stream = FSEventStreamCreate(nil, { _, info, count, paths, flags, _ in
                guard let info else { return }
                let engine = Unmanaged<SyncEngine>.fromOpaque(info).takeUnretainedValue()
                let strings = paths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
                for i in 0..<count {
                    let path = String(cString: strings[i])
                    engine.localChanged(path: path, ownEvent: flags[i] & FSEventStreamEventFlags(kFSEventStreamEventFlagOwnEvent) != 0)
                }
            }, &context, paths as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagMarkSelf))
            if let stream {
                FSEventStreamSetDispatchQueue(stream, .main)
                if !FSEventStreamStart(stream) { storageError = "Surveillance des dossiers impossible. Vérifier les permissions macOS." }
            } else { storageError = "Création du watcher FSEvents impossible." }
        }
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.remoteDue = Date().addingTimeInterval(30); self?.schedule()
            }
        }
        schedule()
    }
    func localChanged(path: String, ownEvent: Bool = false) {
        guard !ownEvent else { return }
        for i in pairs.indices where pairs[i].enabled && pairs[i].direction != .pull && Self.overlap(path, pairs[i].localPath) {
            let id = pairs[i].id
            revisions[id, default: 0] += 1
            localDue[id] = Date().addingTimeInterval(45)
            if pairs[i].lastOutcome == "verified" { pairs[i].lastOutcome = "pending" }
        }
        persist()
    }
    private func schedule() {
        guard automatic, storageError == nil, !shuttingDown else { return }
        timer?.invalidate(); timer = nil
        guard pairs.contains(where: \.enabled) else { return }
        var deadlines = [remoteDue]
        deadlines += cooldowns.values.filter { $0 > Date() }
        if let pausedUntil { deadlines = [pausedUntil] }
        else {
            let eligible = pairs.filter { $0.enabled && !($0.direction.usesBisync && $0.needsResync) }
            deadlines += eligible.compactMap { pair in localDue[pair.id].map { max($0, cooldowns[pair.remote] ?? .distantPast) } }
            deadlines += eligible.compactMap { pair in pair.nextRetryAt.map { max($0, cooldowns[pair.remote] ?? .distantPast) } }
        }
        guard let next = deadlines.min() else { return }
        timer = Timer.scheduledTimer(withTimeInterval: max(1, next.timeIntervalSinceNow), repeats: false) { [weak self] _ in self?.tick() }
        timer?.tolerance = 5
    }
    func tick(now: Date = Date()) {
        cooldowns = cooldowns.filter { $0.value > now }
        if let until = pausedUntil {
            if until > now { schedule(); return }
            pausedUntil = nil
        }
        let remoteReady = remoteDue <= now
        if remoteReady { remoteDue = now.addingTimeInterval(3600) }
        for pair in pairs where pair.enabled && cooldownUntil(for: pair) == nil && !(pair.direction.usesBisync && pair.needsResync) {
            let retry = pair.nextRetryAt.map { $0 <= now } ?? false
            let local = localDue[pair.id].map { $0 <= now } ?? false
            if retry || ((local || remoteReady) && pair.nextRetryAt == nil) {
                enqueue(SyncJob(pairID: pair.id, dryRun: pair.previewOnly, resync: false))
                localDue[pair.id] = nil
                if let i = pairs.firstIndex(where: { $0.id == pair.id }) { pairs[i].nextRetryAt = nil }
            }
        }
        // Do not wake every second for a pair awaiting its first explicit merge.
        for pair in pairs where pair.needsResync { localDue[pair.id] = nil }
        startNext(); drainInventories(); schedule(); refreshBadge()
    }
}
