// PKSync — mode « Dossiers synchronisés » de PKarchives
// Paires dossier local ↔ dossier Google Drive, moteur rclone court-lived :
//  - push   : rclone copy --update (additif, zéro conflit possible)
//  - pull   : rclone copy --update dans l'autre sens
//  - bidir  : rclone bisync (listings de référence, conflits résolus)
//
// Principes :
//  - rclone n'est JAMAIS résident : un process à la demande, un seul à la fois.
//  - Rien n'est déclaré synchronisé sans sortie rclone 0 (MD5 vérifiés par rclone).
//  - Toute erreur est reprise : file d'attente + backoff + bouton « Relancer ».
//  - Journal texte lisible dans ~/Library/Logs/PKarchives/sync.log.
import SwiftUI
import AppKit
import Combine

// MARK: - Copy (4 langues, même format que les réglages v2)

let syncCopy: [String: [String: String]] = [
    "sync.subtitle": ["fr": "Synchronisez des dossiers locaux avec Google Drive, en arrière-plan et sans démon.",
                      "en": "Sync local folders with Google Drive in the background, with no daemon.",
                      "es": "Sincroniza carpetas locales con Google Drive en segundo plano y sin demonio.",
                      "de": "Synchronisiere lokale Ordner mit Google Drive im Hintergrund, ohne Daemon."],
    "sync.add": ["fr": "Ajouter un dossier", "en": "Add a folder", "es": "Añadir una carpeta", "de": "Ordner hinzufügen"],
    "sync.all": ["fr": "Tout synchroniser", "en": "Sync all", "es": "Sincronizar todo", "de": "Alles synchronisieren"],
    "sync.pause": ["fr": "Pause 1 h", "en": "Pause 1 h", "es": "Pausa 1 h", "de": "Pause 1 Std."],
    "sync.resume": ["fr": "Reprendre", "en": "Resume", "es": "Reanudar", "de": "Fortsetzen"],
    "sync.journal": ["fr": "Journal de synchronisation", "en": "Sync journal", "es": "Registro de sincronización", "de": "Synchronisierungsprotokoll"],
    "sync.openlog": ["fr": "Ouvrir le fichier", "en": "Open file", "es": "Abrir archivo", "de": "Datei öffnen"],
    "sync.retry": ["fr": "Relancer les échecs", "en": "Retry failures", "es": "Reintentar errores", "de": "Fehler erneut ausführen"],
    "sync.empty.title": ["fr": "Aucun dossier synchronisé", "en": "No synced folders", "es": "No hay carpetas sincronizadas", "de": "Keine synchronisierten Ordner"],
    "sync.empty.body": ["fr": "Choisissez un dossier local et son emplacement sur Google Drive. La synchronisation tourne en tâche de fond, uniquement quand quelque chose change.",
                        "en": "Pick a local folder and its location on Google Drive. Syncing runs in the background, only when something changes.",
                        "es": "Elige una carpeta local y su ubicación en Google Drive. La sincronización funciona en segundo plano, solo cuando algo cambia.",
                        "de": "Wähle einen lokalen Ordner und seinen Ort auf Google Drive. Die Synchronisierung läuft im Hintergrund, nur wenn sich etwas ändert."],
    "sync.local": ["fr": "Dossier local", "en": "Local folder", "es": "Carpeta local", "de": "Lokaler Ordner"],
    "sync.drive": ["fr": "Dossier Google Drive", "en": "Google Drive folder", "es": "Carpeta de Google Drive", "de": "Google-Drive-Ordner"],
    "sync.drive.hint": ["fr": "Chemin sur le Drive, ex. Sync/Photos", "en": "Path on Drive, e.g. Sync/Photos", "es": "Ruta en Drive, p. ej. Sync/Photos", "de": "Pfad auf Drive, z. B. Sync/Fotos"],
    "sync.choose": ["fr": "Choisir…", "en": "Choose…", "es": "Elegir…", "de": "Wählen…"],
    "sync.direction": ["fr": "Direction", "en": "Direction", "es": "Dirección", "de": "Richtung"],
    "dir.bidirectional": ["fr": "⇄ Bidirectionnel", "en": "⇄ Two-way", "es": "⇄ Bidireccional", "de": "⇄ Bidirektional"],
    "dir.push": ["fr": "↑ Vers Drive", "en": "↑ To Drive", "es": "↑ A Drive", "de": "↑ Zu Drive"],
    "dir.pull": ["fr": "↓ Depuis Drive", "en": "↓ From Drive", "es": "↓ Desde Drive", "de": "↓ Von Drive"],
    "dir.bidirectional.desc": ["fr": "Les deux côtés restent identiques (rclone bisync).",
                               "en": "Both sides stay identical (rclone bisync).",
                               "es": "Ambos lados se mantienen iguales (rclone bisync).",
                               "de": "Beide Seiten bleiben gleich (rclone bisync)."],
    "dir.push.desc": ["fr": "Ajoute et met à jour vers Drive, ne supprime rien (sans risque).",
                      "en": "Adds and updates to Drive, deletes nothing (safe).",
                      "es": "Añade y actualiza hacia Drive, no borra nada (seguro).",
                      "de": "Fügt zu Drive hinzu und aktualisiert, löscht nichts (sicher)."],
    "dir.pull.desc": ["fr": "Récupère Drive vers le Mac, ne supprime rien (sans risque).",
                      "en": "Pulls Drive to the Mac, deletes nothing (safe).",
                      "es": "Trae Drive al Mac, no borra nada (seguro).",
                      "de": "Holt Drive auf den Mac, löscht nichts (sicher)."],
    "sync.conflict": ["fr": "En cas de conflit", "en": "On conflict", "es": "En conflicto", "de": "Bei Konflikt"],
    "conflict.newest": ["fr": "Le plus récent gagne", "en": "Newest wins", "es": "Gana el más reciente", "de": "Neueste gewinnt"],
    "conflict.local": ["fr": "Le Mac gagne", "en": "Mac wins", "es": "Gana el Mac", "de": "Mac gewinnt"],
    "conflict.remote": ["fr": "Drive gagne", "en": "Drive wins", "es": "Gana Drive", "de": "Drive gewinnt"],
    "sync.ignores": ["fr": "Fichiers ignorés (un motif par ligne)", "en": "Ignored files (one pattern per line)", "es": "Archivos ignorados (un patrón por línea)", "de": "Ignorierte Dateien (ein Muster pro Zeile)"],
    "sync.activated": ["fr": "Paire activée", "en": "Pair enabled", "es": "Pareja activada", "de": "Paar aktiviert"],
    "sync.now": ["fr": "Synchroniser", "en": "Sync", "es": "Sincronizar", "de": "Synchronisieren"],
    "sync.resync": ["fr": "Première synchronisation…", "en": "First sync…", "es": "Primera sincronización…", "de": "Erste Synchronisierung…"],
    "sync.resync.confirm.title": ["fr": "Première synchronisation bidirectionnelle", "en": "First two-way sync", "es": "Primera sincronización bidireccional", "de": "Erste bidirektionale Synchronisierung"],
    "sync.resync.confirm.message": ["fr": "Les contenus des deux côtés seront comparés puis fusionnés : les fichiers plus récents de chaque côté seront copiés de l'autre. Rien n'est écrasé silencieusement.",
                                    "en": "Both sides will be compared then merged: newer files on each side are copied to the other. Nothing is silently overwritten.",
                                    "es": "Ambos lados se comparan y se fusionan: los archivos más recientes de cada lado se copian al otro. Nada se sobrescribe en silencio.",
                                    "de": "Beide Seiten werden verglichen und zusammengeführt: Neuere Dateien jeder Seite werden auf die andere kopiert. Nichts wird stillschweigend überschrieben."],
    "sync.resync.go": ["fr": "Fusionner maintenant", "en": "Merge now", "es": "Fusionar ahora", "de": "Jetzt zusammenführen"],
    "sync.delete.confirm.title": ["fr": "Supprimer cette paire ?", "en": "Remove this pair?", "es": "¿Eliminar esta pareja?", "de": "Dieses Paar entfernen?"],
    "sync.delete.confirm.message": ["fr": "La paire « %@ » ne sera plus synchronisée. Rien n'est supprimé sur le Mac ni sur Drive.",
                                    "en": "The pair “%@” will no longer sync. Nothing is deleted on the Mac or Drive.",
                                    "es": "La pareja «%@» dejará de sincronizarse. No se borra nada en el Mac ni en Drive.",
                                    "de": "Das Paar „%@“ wird nicht mehr synchronisiert. Nichts wird auf dem Mac oder Drive gelöscht."],
    "sync.never": ["fr": "Jamais synchronisé", "en": "Never synced", "es": "Nunca sincronizado", "de": "Nie synchronisiert"],
    "sync.running": ["fr": "Synchronisation…", "en": "Syncing…", "es": "Sincronizando…", "de": "Synchronisierung…"],
    "sync.error.label": ["fr": "Échec", "en": "Failed", "es": "Error", "de": "Fehlgeschlagen"],
    "sync.needsresync": ["fr": "Première fusion requise", "en": "First merge required", "es": "Primera fusión requerida", "de": "Erste Zusammenführung nötig"],
    "sync.edit": ["fr": "Modifier", "en": "Edit", "es": "Editar", "de": "Bearbeiten"],
    "sync.delete": ["fr": "Supprimer la paire", "en": "Remove pair", "es": "Eliminar pareja", "de": "Paar entfernen"],
    "sync.stop": ["fr": "Arrêter", "en": "Stop", "es": "Detener", "de": "Stoppen"],
    "sync.sheet.add.title": ["fr": "Nouveau dossier synchronisé", "en": "New synced folder", "es": "Nueva carpeta sincronizada", "de": "Neuer synchronisierter Ordner"],
    "sync.sheet.edit.title": ["fr": "Modifier la paire", "en": "Edit pair", "es": "Editar pareja", "de": "Paar bearbeiten"],
    "sync.save": ["fr": "Ajouter", "en": "Add", "es": "Añadir", "de": "Hinzufügen"],
    "sync.files.ok": ["fr": "%d fichier(s) synchronisé(s)", "en": "%d file(s) synced", "es": "%d archivo(s) sincronizado(s)", "de": "%d Datei(en) synchronisiert"],
    "sync.auto.retry": ["fr": "reprise auto dans %@", "en": "auto-retry in %@", "es": "reintento auto en %@", "de": "Auto-Wiederholung in %@"],
]

func syncText(_ key: String, language: String? = nil) -> String {
    let lang = language ?? UserDefaults.standard.string(forKey: "app-language") ?? "fr"
    return syncCopy[key]?[lang] ?? syncCopy[key]?["en"] ?? key
}

// MARK: - Modèle

enum SyncDirection: String, Codable, CaseIterable {
    case bidirectional, push, pull
    var symbol: String {
        switch self {
        case .bidirectional: "arrow.left.arrow.right"
        case .push: "arrow.up"
        case .pull: "arrow.down"
        }
    }
    var label: String { syncText("dir.\(rawValue)") }
    var detail: String { syncText("dir.\(rawValue).desc") }
    var usesBisync: Bool { self == .bidirectional }
}

enum SyncConflictPolicy: String, Codable, CaseIterable {
    case newest, local, remote
    var label: String { syncText("conflict.\(rawValue)") }
}

struct SyncStats: Codable, Equatable {
    var files: Int = 0
    var conflicts: Int = 0
    var duration: TimeInterval = 0
}

struct SyncPair: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var localPath: String = ""
    var drivePath: String = ""
    var direction: SyncDirection = .bidirectional
    var conflictPolicy: SyncConflictPolicy = .newest
    var ignores: [String] = SyncPair.defaultIgnores
    var enabled: Bool = true
    var remoteOverride: String? = nil

    // État d'exécution, persisté pour reprise après relance de l'app.
    var lastRun: Date? = nil
    var lastOutcome: String = "idle"   // idle | ok | error | needsResync
    var lastMessage: String? = nil
    var lastStats: SyncStats? = nil
    var needsResync: Bool = false      // bidir : première fusion non encore faite
    var consecutiveFailures: Int = 0
    var nextRetryAt: Date? = nil       // backoff auto ; nil = pas de reprise en attente

    static let defaultIgnores = [".DS_Store", "Thumbs.db", "~$*", ".TemporaryItems/**", ".Trashes/**", "node_modules/**"]

    // Codable tolérant : les champs absents (vieilles versions du JSON) gardent leur défaut.
    enum CodingKeys: String, CodingKey {
        case id, name, localPath, drivePath, direction, conflictPolicy, ignores,
             enabled, remoteOverride, lastRun, lastOutcome, lastMessage,
             lastStats, needsResync, consecutiveFailures, nextRetryAt
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        localPath = try c.decodeIfPresent(String.self, forKey: .localPath) ?? ""
        drivePath = try c.decodeIfPresent(String.self, forKey: .drivePath) ?? ""
        direction = try c.decodeIfPresent(SyncDirection.self, forKey: .direction) ?? .bidirectional
        conflictPolicy = try c.decodeIfPresent(SyncConflictPolicy.self, forKey: .conflictPolicy) ?? .newest
        ignores = try c.decodeIfPresent([String].self, forKey: .ignores) ?? SyncPair.defaultIgnores
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        remoteOverride = try c.decodeIfPresent(String.self, forKey: .remoteOverride)
        lastRun = try c.decodeIfPresent(Date.self, forKey: .lastRun)
        lastOutcome = try c.decodeIfPresent(String.self, forKey: .lastOutcome) ?? "idle"
        lastMessage = try c.decodeIfPresent(String.self, forKey: .lastMessage)
        lastStats = try c.decodeIfPresent(SyncStats.self, forKey: .lastStats)
        needsResync = try c.decodeIfPresent(Bool.self, forKey: .needsResync) ?? false
        consecutiveFailures = try c.decodeIfPresent(Int.self, forKey: .consecutiveFailures) ?? 0
        nextRetryAt = try c.decodeIfPresent(Date.self, forKey: .nextRetryAt)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(localPath, forKey: .localPath)
        try c.encode(drivePath, forKey: .drivePath)
        try c.encode(direction, forKey: .direction)
        try c.encode(conflictPolicy, forKey: .conflictPolicy)
        try c.encode(ignores, forKey: .ignores)
        try c.encode(enabled, forKey: .enabled)
        try c.encodeIfPresent(remoteOverride, forKey: .remoteOverride)
        try c.encodeIfPresent(lastRun, forKey: .lastRun)
        try c.encode(lastOutcome, forKey: .lastOutcome)
        try c.encodeIfPresent(lastMessage, forKey: .lastMessage)
        try c.encodeIfPresent(lastStats, forKey: .lastStats)
        try c.encode(needsResync, forKey: .needsResync)
        try c.encode(consecutiveFailures, forKey: .consecutiveFailures)
        try c.encodeIfPresent(nextRetryAt, forKey: .nextRetryAt)
    }
}

// MARK: - Persistance (~/Library/Application Support/PKarchives/sync.json)

enum SyncStore {
    static var baseURL: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/PKarchives", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    static var fileURL: URL { baseURL.appendingPathComponent("sync.json") }

    static func load() -> [SyncPair] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([SyncPair].self, from: data)) ?? []
    }
    static func save(_ pairs: [SyncPair]) {
        guard let data = try? JSONEncoder().encode(pairs) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
    static func workdir(for pair: SyncPair) -> String {
        let dir = baseURL.appendingPathComponent("bisync/\(pair.id.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }
    static func removeWorkdir(of pair: SyncPair) {
        try? FileManager.default.removeItem(at: baseURL.appendingPathComponent("bisync/\(pair.id.uuidString)"))
    }
}

// MARK: - Journal lisible (~/Library/Logs/PKarchives/sync.log)

final class SyncLog {
    static let shared = SyncLog()
    let directory: URL
    let fileURL: URL
    private let maxBytes = 512 * 1024
    private let keepRotated = 3

    init() {
        directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/PKarchives", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("sync.log")
    }

    func write(_ line: String) {
        rotateIfNeeded()
        if let data = (line + "\n").data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: fileURL)
            }
        }
    }

    /// Uniquement pour le rechargement UI — queue lecture simple.
    func tail(maxLines: Int = 400) -> [String] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        var lines = content.components(separatedBy: .newlines)
        lines.removeAll { $0.isEmpty }
        return Array(lines.suffix(maxLines))
    }

    private func rotateIfNeeded() {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))[.size] as? Int,
              size >= maxBytes else { return }
        let stamp = DateFormatter("yyyy-MM-dd_HHmmss").string(from: Date())
        let rotated = directory.appendingPathComponent("sync-\(stamp).log")
        try? FileManager.default.moveItem(at: fileURL, to: rotated)
        // garde les N plus récents
        let olds = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix("sync-") && $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent } ?? []
        for old in olds.dropFirst(keepRotated) {
            try? FileManager.default.removeItem(at: old)
        }
    }
}

private extension DateFormatter {
    convenience init(_ format: String) {
        self.init()
        dateFormat = format
        locale = Locale(identifier: "fr_FR")
    }
}

// MARK: - Moteur

/// ObservableObject non-MainActor : toutes les mutations passent par DispatchQueue.main
/// (même style que AppDelegate dans PKarchivesV2.swift, Swift 5 mode).
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published private(set) var pairs: [SyncPair]
    @Published private(set) var runningPairID: UUID?
    @Published private(set) var progressPct: Int = -1          // -1 = indéterminé
    @Published private(set) var progressText: String = ""
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var journalLines: [String] = []
    /// Miroir publié du badge menu bar (calculé) — observé par AppDelegate.
    @Published private(set) var statusBadgeSubject: String = "📦"

    // Un seul rclone à la fois : c'est LA clé de la légèreté.
    private var runQueue: [UUID] = []
    private var process: Process?
    private var currentResync = false
    private var outputTail: [String] = []       // dernières lignes du run courant (diagnostic)
    private var monitorTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        pairs = SyncStore.load()
        // Bidir jamais fusionnée : marquée « première fusion requise » au chargement.
        journalLines = SyncLog.shared.tail()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.pumpRetries() }
        }
    }

    // MARK: état dérivé pour la barre des menus

    var statusBadge: String {
        if pausedUntil != nil { return "⏸" }
        if runningPairID != nil {
            return progressPct >= 0 ? "⟳ \(progressPct)%" : "⟳"
        }
        if pairs.contains(where: { $0.lastOutcome == "error" }) { return "⚠️" }
        return "📦"
    }

    private func refreshBadge() {
        let badge = statusBadge
        if statusBadgeSubject != badge { statusBadgeSubject = badge }
    }

    var isPaused: Bool { pausedUntil != nil }

    // MARK: actions publiques

    func syncAll() {
        for pair in pairs where pair.enabled {
            if pair.direction.usesBisync && pair.needsResync {
                // Une paire bidir jamais fusionnée ne part pas toute seule :
                // elle attend la confirmation de l'utilisateur (fusion ou refus).
                continue
            }
            enqueue(pair.id)
        }
        startNextIfNeeded()
    }

    func syncPair(_ id: UUID) {
        guard let idx = pairs.firstIndex(where: { $0.id == id }) else { return }
        pairs[idx].nextRetryAt = nil
        enqueue(id)
        startNextIfNeeded()
    }

    /// Première fusion bidirectionnelle (bisync --resync), après confirmation UI.
    func resyncPair(_ id: UUID) {
        guard let idx = pairs.firstIndex(where: { $0.id == id }) else { return }
        pairs[idx].nextRetryAt = nil
        enqueue(id, resync: true)
        startNextIfNeeded()
    }

    func retryFailed() {
        for pair in pairs where pair.lastOutcome == "error" && pair.enabled {
            enqueue(pair.id)
        }
        startNextIfNeeded()
    }

    func stopRunning() {
        process?.terminate()
    }

    func pauseForHours(_ hours: Double) {
        pausedUntil = Date().addingTimeInterval(hours * 3600)
        refreshBadge()
    }

    func resume() {
        pausedUntil = nil
        refreshBadge()
        startNextIfNeeded()
    }

    func addPair(_ pair: SyncPair) {
        var p = pair
        if p.name.isEmpty { p.name = URL(fileURLWithPath: p.localPath).lastPathComponent }
        if p.direction.usesBisync { p.needsResync = true }
        pairs.append(p)
        persist()
    }

    func updatePair(_ pair: SyncPair) {
        guard let idx = pairs.firstIndex(where: { $0.id == pair.id }) else { return }
        var p = pair
        if pairs[idx].direction != p.direction { p.needsResync = p.direction.usesBisync }
        // Si la config d'une paire change, l'état précédent ne veut plus rien dire.
        if pairs[idx].localPath != p.localPath || pairs[idx].drivePath != p.drivePath {
            p.needsResync = p.direction.usesBisync
            p.lastOutcome = "idle"
            p.lastMessage = nil
            p.lastStats = nil
        }
        pairs[idx] = p
        persist()
    }

    func deletePair(_ id: UUID) {
        if runningPairID == id { stopRunning() }
        runQueue.removeAll { $0 == id }
        if let pair = pairs.first(where: { $0.id == id }) {
            SyncStore.removeWorkdir(of: pair)
        }
        pairs.removeAll { $0.id == id }
        persist()
    }

    func refreshJournal() {
        journalLines = SyncLog.shared.tail()
    }

    // MARK: file d'attente

    private func enqueue(_ id: UUID, resync: Bool = false) {
        guard runningPairID != id, !runQueue.contains(where: { $0 == id }) else { return }
        if resync { currentResync = true }
        runQueue.append(id)
    }

    private func startNextIfNeeded() {
        guard runningPairID == nil, pausedUntil == nil, !runQueue.isEmpty else { return }
        let id = runQueue.removeFirst()
        guard let idx = pairs.firstIndex(where: { $0.id == id }) else { startNextIfNeeded(); return }
        guard pairs[idx].enabled, FileManager.default.fileExists(atPath: pairs[idx].localPath) else {
            pairs[idx].lastOutcome = "error"
            pairs[idx].lastMessage = "Dossier local introuvable : \(pairs[idx].localPath)"
            persist()
            startNextIfNeeded()
            return
        }
        launch(pairID: id, resync: currentResync)
        currentResync = false
    }

    private func pumpRetries() {
        guard pausedUntil == nil, runningPairID == nil else { return }
        let due = pairs.filter {
            $0.enabled && $0.nextRetryAt != nil && $0.nextRetryAt! <= Date()
                && !runQueue.contains($0.id)
                && !($0.direction.usesBisync && $0.needsResync)   // fusion bidir : confirmation requise
        }
        guard !due.isEmpty else { return }
        for pair in due { runQueue.append(pair.id) }
        startNextIfNeeded()
    }

    // MARK: construction de la commande rclone

    private func remote(for pair: SyncPair) -> String {
        if let over = pair.remoteOverride, !over.isEmpty { return over }
        return (loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive").trimmingCharacters(in: CharacterSet(charactersIn: ":"))
    }

    private func driveTarget(_ pair: SyncPair) -> String {
        let path = pair.drivePath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return "\(remote(for: pair)):\(path)"
    }

    private func filtersFile(_ pair: SyncPair) -> String {
        let path = SyncStore.workdir(for: pair) + "/filter.txt"
        let content = pair.ignores
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { "- \($0)" }
            .joined(separator: "\n") + "\n"
        let existing = try? String(contentsOfFile: path, encoding: .utf8)
        if existing != content {
            try? content.write(toFile: path, atomically: true, encoding: .utf8)
        }
        return path
    }

    /// Flags communs : limités volontairement — pas de burst agressif,
    /// buffers courts, stats cadencées. Le process meurt à la fin du run.
    private func lightFlags() -> [String] {
        ["--transfers", "4",
         "--checkers", "8",
         "--buffer-size", "8M",
         "--drive-chunk-size", "8M",
         "--drive-pacer-min-sleep", "10ms",
         "--drive-pacer-burst", "200",
         "--stats", "2s",
         "--stats-one-line",
         "--stats-unit", "files",
         "--log-level", "NOTICE"]
    }

    private func conflictFlags(_ pair: SyncPair) -> [String] {
        let suffix = DateFormatter("yyyy-MM-dd").string(from: Date())
        switch pair.conflictPolicy {
        case .newest: return ["--conflict-resolve", "newer", "--conflict-suffix", "conflict-\(suffix)"]
        case .local: return ["--conflict-resolve", "path1", "--conflict-suffix", "conflict-\(suffix)"]
        case .remote: return ["--conflict-resolve", "path2", "--conflict-suffix", "conflict-\(suffix)"]
        }
    }

    private func args(for pair: SyncPair, resync: Bool) -> [String] {
        let dest = driveTarget(pair)
        let filter = filtersFile(pair)
        switch pair.direction {
        case .push:
            return ["copy", pair.localPath, dest, "--update", "--filters-file", filter] + lightFlags()
        case .pull:
            return ["copy", dest, pair.localPath, "--update", "--filters-file", filter] + lightFlags()
        case .bidirectional:
            var a = ["bisync", pair.localPath, dest]
            if resync { a += ["--resync"] }
            a += lightFlags()
            a += ["--filters-file", filter, "--workdir", SyncStore.workdir(for: pair)]
            if !resync { a += conflictFlags(pair) }
            return a
        }
    }

    // MARK: exécution

    private func launch(pairID: UUID, resync: Bool) {
        guard let idx = pairs.firstIndex(where: { $0.id == pairID }) else { return }
        let pair = pairs[idx]
        let binary = rcloneBinary()
        let startedAt = Date()
        let arrow: String
        switch pair.direction {
        case .bidirectional: arrow = "⇄ bidirectionnel"
        case .push: arrow = "↑ vers Drive"
        case .pull: arrow = "↓ depuis Drive"
        }
        log("─".padding(toLength: 62, withPad: "─", startingAt: 0))
        log("⟳ \(Self.stamp(startedAt)) — « \(pair.name) » \(arrow)")
        log("   \(shortPath(pair.localPath))  \(pair.direction == .pull ? "←" : pair.direction == .push ? "→" : "⇄")  \(driveTarget(pair))")
        if resync { log("   première fusion (--resync)") }

        runningPairID = pairID
        progressPct = -1
        progressText = ""
        outputTail = []
        refreshBadge()
        pairs[idx].lastMessage = nil

        let proc = Process()
        let arguments = args(for: pairs[idx], resync: resync)
        if binary.contains("/") {
            proc.executableURL = URL(fileURLWithPath: binary)
            proc.arguments = arguments
        } else {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = ["rclone"] + arguments
        }
        var env = ProcessInfo.processInfo.environment
        env["PKARCHIVES_RCLONE_BINARY"] = binary
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        process = proc

        let collect: (Pipe) -> Void = { pipe in
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else {
                    if data.isEmpty { handle.readabilityHandler = nil }
                    return
                }
                let lines = stripAnsi(s).components(separatedBy: .newlines).filter { !$0.isEmpty }
                DispatchQueue.main.async { [weak self] in
                    self?.ingest(lines: lines)
                }
            }
        }
        collect(outPipe)
        collect(errPipe)

        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                p.terminationHandler = nil
                self?.finish(pairID: pairID, exit: p.terminationStatus, startedAt: startedAt)
            }
        }

        do {
            try proc.run()
        } catch {
            finish(pairID: pairID, exit: -1, startedAt: startedAt, spawnError: error.localizedDescription)
        }
    }

    /// Analyse progressive de la sortie rclone (progression %).
    private func ingest(lines: [String]) {
        for line in lines {
            outputTail.append(line)
            if outputTail.count > 200 { outputTail.removeFirst(outputTail.count - 200) }
            if let pct = Self.percent(in: line) {
                progressPct = pct
                progressText = Self.cleanStatLine(line)
                refreshBadge()
            }
        }
    }

    private func finish(pairID: UUID, exit: Int32, startedAt: Date, spawnError: String? = nil) {
        process = nil
        runningPairID = nil
        progressPct = -1
        guard let idx = pairs.firstIndex(where: { $0.id == pairID }) else { return }
        let duration = Date().timeIntervalSince(startedAt)
        let tail = outputTail
        let wasResync = pairs[idx].direction.usesBisync && needsResyncFlag(pairID)

        if exit == 0 {
            let files = tail.compactMap(Self.transferredFiles).last ?? 0
            let conflicts = tail.filter { $0.contains("conflict-") }.count
            pairs[idx].lastRun = Date()
            pairs[idx].lastOutcome = "ok"
            pairs[idx].lastMessage = String(format: syncText("sync.files.ok"), files)
            pairs[idx].lastStats = SyncStats(files: files, conflicts: conflicts, duration: duration)
            pairs[idx].consecutiveFailures = 0
            pairs[idx].nextRetryAt = nil
            if wasResync { pairs[idx].needsResync = false }
            log("   ✓ \(files) fichier(s) vérifié(s) — terminé en \(Int(duration)) s")
            if conflicts > 0 { log("   ⚠ \(conflicts) conflit(s) conservé(s) en copie suffixée") }
            log("   ── ok — « \(pairs[idx].name) » synchronisé ──")
        } else if let spawnError {
            pairs[idx].lastOutcome = "error"
            pairs[idx].lastMessage = spawnError
            scheduleRetry(idx)
            log("   ✗ lancement impossible : \(spawnError)")
            log("   ── échec — reprise automatique prévue ──")
        } else {
            let out = tail.joined(separator: "\n")
            if out.contains("must run --resync") || out.contains("Bisync error") && out.contains("--resync") {
                pairs[idx].needsResync = true
                pairs[idx].lastOutcome = "needsResync"
                pairs[idx].lastMessage = syncText("sync.needsresync")
                pairs[idx].nextRetryAt = nil
                log("   ⚠ listings de référence requis : première fusion à confirmer")
            } else {
                let reason = Self.errorMessage(from: tail) ?? "rclone a quitté avec le code \(exit)"
                pairs[idx].lastOutcome = "error"
                pairs[idx].lastMessage = reason
                pairs[idx].consecutiveFailures += 1
                scheduleRetry(idx)
                log("   ✗ \(reason)")
                log("   ── échec — rien n'est marqué synchronisé, reprise prévue ──")
            }
        }
        persist()
        refreshBadge()
        startNextIfNeeded()
    }

    private func needsResyncFlag(_ id: UUID) -> Bool {
        pairs.first(where: { $0.id == id })?.needsResync ?? false
    }

    /// Backoff : 2, 5, 15, 30 min puis 60 min max. La paire reste visible
    /// en erreur jusqu'à succès ; rien n'est jamais « à moitié » déclaré.
    private func scheduleRetry(_ idx: Int) {
        let delays = [120.0, 300.0, 900.0, 1800.0]
        let delay = delays[min(pairs[idx].consecutiveFailures - 1, delays.count - 1)]
        pairs[idx].nextRetryAt = Date().addingTimeInterval(delay)
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        log("   ↻ \(syncText("sync.auto.retry").replacingOccurrences(of: "%@", with: formatter.localizedString(for: pairs[idx].nextRetryAt!, relativeTo: Date())))")
    }

    private func persist() {
        SyncStore.save(pairs)
        objectWillChange.send()
    }

    private func log(_ line: String) {
        SyncLog.shared.write(line)
        journalLines.append(line)
        if journalLines.count > 400 { journalLines.removeFirst(journalLines.count - 400) }
    }

    // MARK: parsing sortie rclone

    static func percent(in line: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: "(?:^|\\s)(\\d{1,3})%") else { return nil }
        let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
        guard let last = matches.last, let range = Range(last.range(at: 1), in: line),
              let value = Int(line[range]), (0...100).contains(value) else { return nil }
        return value
    }

    static func transferredFiles(in line: String) -> Int? {
        guard line.contains("Transferred:") || line.contains("Transféré") else { return nil }
        guard let regex = try? NSRegularExpression(pattern: "Transferred:\\s*(\\d+)\\s*/\\s*(\\d+)") else { return nil }
        guard let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 2), in: line), let total = Int(line[range]) else { return nil }
        return total
    }

    static func cleanStatLine(_ line: String) -> String {
        var l = line
        // retire l'horodatage rclone "2026/10/27 09:12:33.123456 "
        if let regex = try? NSRegularExpression(pattern: "^\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2}(\\.\\d+)?\\s+") {
            l = regex.stringByReplacingMatches(in: l, range: NSRange(l.startIndex..., in: l), withTemplate: "")
        }
        return l
    }

    static func errorMessage(from tail: [String]) -> String? {
        for line in tail.reversed() {
            let l = cleanStatLine(line)
            let lower = l.lowercased()
            if lower.contains("error") || lower.contains("failed") || lower.contains("directory not found")
                || lower.contains("couldn't") || lower.contains("404") || lower.contains("403")
                || lower.contains("quota") || lower.contains("couldn't fetch") {
                return String(l.prefix(180))
            }
        }
        return tail.last.map { String(cleanStatLine($0).prefix(180)) }
    }

    static func stamp(_ date: Date) -> String {
        DateFormatter("d MMM yyyy 'à' HH:mm").string(from: date)
    }
}

// MARK: - Vue réglages « Dossiers »

struct SyncSectionView: View {
    @ObservedObject private var engine = SyncEngine.shared
    @State private var pairInForm: SyncPair?
    @State private var pairToDelete: SyncPair?
    @State private var pairToResync: SyncPair?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSectionHeader(title: sectionTitle,
                                      subtitle: syncText("sync.subtitle"),
                                      icon: "arrow.triangle.2.circlepath")
                toolbar
                if engine.pairs.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(engine.pairs) { pair in
                            PairCard(pair: pair,
                                     isRunning: engine.runningPairID == pair.id,
                                     progressPct: engine.runningPairID == pair.id ? engine.progressPct : -1,
                                     progressText: engine.runningPairID == pair.id ? engine.progressText : "",
                                     paused: engine.isPaused,
                                     onSync: { engine.syncPair(pair.id) },
                                     onResync: { pairToResync = pair },
                                     onStop: { engine.stopRunning() },
                                     onEdit: { pairInForm = pair },
                                     onDelete: { pairToDelete = pair })
                        }
                    }
                }
                journal
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .sheet(item: $pairInForm) { pair in
            PairFormSheet(original: pair) { updated in
                if engine.pairs.contains(where: { $0.id == updated.id }) {
                    engine.updatePair(updated)
                } else {
                    engine.addPair(updated)
                }
            }
        }
        .alert(syncText("sync.resync.confirm.title"), isPresented: resyncBinding) {
            Button(syncText("sync.resync.go")) {
                if let p = pairToResync { engine.resyncPair(p.id) }
            }
            Button("Annuler", role: .cancel) { pairToResync = nil }
        } message: {
            Text(syncText("sync.resync.confirm.message"))
        }
        .alert(syncText("sync.delete.confirm.title"), isPresented: deleteBinding) {
            Button(syncText("sync.delete"), role: .destructive) {
                if let p = pairToDelete { engine.deletePair(p.id) }
            }
            Button("Annuler", role: .cancel) { pairToDelete = nil }
        } message: {
            Text(String(format: syncText("sync.delete.confirm.message"), pairToDelete?.name ?? ""))
        }
    }

    private var sectionTitle: String {
        let lang = UserDefaults.standard.string(forKey: "app-language") ?? "fr"
        return ["fr": "Dossiers synchronisés", "en": "Synced folders",
                "es": "Carpetas sincronizadas", "de": "Synchronisierte Ordner"][lang] ?? "Dossiers"
    }

    private var resyncBinding: Binding<Bool> { Binding(get: { pairToResync != nil }, set: { if !$0 { pairToResync = nil } }) }
    private var deleteBinding: Binding<Bool> { Binding(get: { pairToDelete != nil }, set: { if !$0 { pairToDelete = nil } }) }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                pairInForm = SyncPair()
            } label: {
                Label(syncText("sync.add"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            Button {
                engine.syncAll()
            } label: {
                Label(syncText("sync.all"), systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(engine.pairs.isEmpty || engine.runningPairID != nil)
            if engine.isPaused {
                Button { engine.resume() } label: { Label(syncText("sync.resume"), systemImage: "play.fill") }
            } else {
                Button { engine.pauseForHours(1) } label: { Label(syncText("sync.pause"), systemImage: "pause.fill") }
                    .disabled(engine.pairs.isEmpty)
            }
            if engine.pairs.contains(where: { $0.lastOutcome == "error" }) {
                Button { engine.retryFailed() } label: { Label(syncText("sync.retry"), systemImage: "arrow.clockwise") }
                    .disabled(engine.runningPairID != nil)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 42))
                .foregroundStyle(.quaternary)
            Text(syncText("sync.empty.title")).font(.system(size: 15, weight: .semibold))
            Text(syncText("sync.empty.body"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.025)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    private var journal: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(syncText("sync.journal")).font(.headline)
                Spacer()
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([SyncLog.shared.fileURL])
                } label: { Label(syncText("sync.openlog"), systemImage: "doc.text") }
                    .buttonStyle(.bordered)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(engine.journalLines.enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                                .foregroundStyle(lineColor(line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        Color.clear.frame(height: 1).id("journal-bottom")
                    }
                    .padding(10)
                }
                .frame(height: 200)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
                .onChange(of: engine.journalLines.count) { _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("journal-bottom", anchor: .bottom) }
                }
            }
        }
    }

    private func lineColor(_ line: String) -> Color {
        if line.contains("✗") { return .red }
        if line.contains("⚠") { return .orange }
        if line.contains("✓") { return .green }
        if line.hasPrefix("─") || line.hasPrefix("⟳") { return .primary }
        return .secondary
    }
}

// MARK: - Carte d'une paire

private struct PairCard: View {
    let pair: SyncPair
    let isRunning: Bool
    let progressPct: Int
    let progressText: String
    let paused: Bool
    let onSync: () -> Void
    let onResync: () -> Void
    let onStop: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(pair.name).font(.system(size: 14, weight: .semibold))
                    Text(directionSummary).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                directionBadge
                statusView
            }
            HStack(spacing: 8) {
                if isRunning {
                    ProgressView().controlSize(.small)
                    Text(progressText.isEmpty ? syncText("sync.running") : progressText)
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Button(syncText("sync.stop"), action: onStop).buttonStyle(.bordered).controlSize(.small)
                } else {
                    Button {
                        if pair.direction.usesBisync && pair.needsResync { onResync() } else { onSync() }
                    } label: {
                        Label(pair.direction.usesBisync && pair.needsResync ? syncText("sync.resync") : syncText("sync.now"),
                              systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    Menu {
                        Button(syncText("sync.edit"), action: onEdit)
                        if pair.direction.usesBisync {
                            Button(syncText("sync.resync"), action: onResync)
                        }
                        Divider()
                        Button(syncText("sync.delete"), role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .controlSize(.small)
                    Spacer()
                    Text(detailLine).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private var directionSummary: String {
        "\(shortPath(pair.localPath))  \(pair.direction == .push ? "→" : pair.direction == .pull ? "←" : "⇄")  \(driveTargetDisplay)"
    }
    private var driveTargetDisplay: String {
        let remote = pair.remoteOverride ?? (loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive").trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        return "\(remote):\(pair.drivePath)"
    }

    private var directionBadge: some View {
        Text(pair.direction == .bidirectional ? "⇄" : pair.direction == .push ? "↑" : "↓")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(badgeTint, in: Circle())
            .help(pair.direction.detail)
    }
    private var badgeTint: Color {
        switch pair.direction {
        case .bidirectional: Color.accentColor
        case .push: Color(red: 0.20, green: 0.62, blue: 0.43)
        case .pull: Color(red: 0.89, green: 0.58, blue: 0.16)
        }
    }

    @ViewBuilder private var statusView: some View {
        if isRunning {
            Text(syncText("sync.running")).font(.system(size: 11, weight: .medium)).foregroundStyle(.blue)
        } else if !pair.enabled {
            Text("⏸").font(.system(size: 12))
        } else {
            switch pair.lastOutcome {
            case "ok":
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text(relativeRun).font(.system(size: 11)).foregroundStyle(.secondary)
                }.help(pair.lastMessage ?? "")
            case "error":
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 7, height: 7)
                    Text(syncText("sync.error.label")).font(.system(size: 11, weight: .medium)).foregroundStyle(.red)
                }.help(pair.lastMessage ?? "")
            case "needsResync":
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 7, height: 7)
                    Text(syncText("sync.needsresync")).font(.system(size: 11, weight: .medium)).foregroundStyle(.orange)
                }
            default:
                HStack(spacing: 4) {
                    Circle().fill(.secondary).frame(width: 7, height: 7)
                    Text(syncText("sync.never")).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var detailLine: String {
        var parts: [String] = []
        if let run = pair.lastRun {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            parts.append(formatter.localizedString(for: run, relativeTo: Date()))
            if let stats = pair.lastStats { parts.append(String(format: syncText("sync.files.ok"), stats.files)) }
        }
        if let retry = pair.nextRetryAt, pair.lastOutcome == "error" {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            parts.append(syncText("sync.auto.retry").replacingOccurrences(of: "%@", with: formatter.localizedString(for: retry, relativeTo: Date())))
        }
        return parts.joined(separator: " · ")
    }

    private var relativeRun: String {
        guard let run = pair.lastRun else { return syncText("sync.never") }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.localizedString(for: run, relativeTo: Date())
    }
}

// MARK: - Formulaire d'ajout / édition

private struct PairFormSheet: View {
    let original: SyncPair
    let onSave: (SyncPair) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var localPath: String
    @State private var drivePath: String
    @State private var direction: SyncDirection
    @State private var conflictPolicy: SyncConflictPolicy
    @State private var ignoresText: String
    @State private var enabled: Bool
    @State private var errorMessage: String?

    init(original: SyncPair, onSave: @escaping (SyncPair) -> Void) {
        self.original = original
        self.onSave = onSave
        _name = State(initialValue: original.name)
        _localPath = State(initialValue: original.localPath)
        _drivePath = State(initialValue: original.drivePath)
        _direction = State(initialValue: original.direction)
        _conflictPolicy = State(initialValue: original.conflictPolicy)
        _ignoresText = State(initialValue: (original.ignores.isEmpty ? SyncPair.defaultIgnores : original.ignores).joined(separator: "\n"))
        _enabled = State(initialValue: original.enabled)
    }

    private var isEdit: Bool { engineHasPair }
    private var engineHasPair: Bool { SyncEngine.shared.pairs.contains(where: { $0.id == original.id }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEdit ? syncText("sync.sheet.edit.title") : syncText("sync.sheet.add.title"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Form {
                Section(syncText("sync.local")) {
                    HStack {
                        TextField("/Users/…/Dossier", text: $localPath).textFieldStyle(.roundedBorder)
                        Button(syncText("sync.choose")) { chooseLocal() }
                    }
                    TextField(syncText("sync.add").isEmpty ? "" : "Nom", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                Section(syncText("sync.drive")) {
                    TextField(syncText("sync.drive.hint"), text: $drivePathHintBinding)
                        .textFieldStyle(.roundedBorder)
                    Text(preview).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                Section(syncText("sync.direction")) {
                    Picker("", selection: $direction) {
                        ForEach(SyncDirection.allCases, id: \.self) { d in
                            Text(d.label).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text(direction.detail).font(.caption).foregroundStyle(.secondary)
                    if direction.usesBisync {
                        Picker(syncText("sync.conflict"), selection: $conflictPolicy) {
                            ForEach(SyncConflictPolicy.allCases, id: \.self) { p in
                                Text(p.label).tag(p)
                            }
                        }
                    }
                    Toggle(syncText("sync.activated"), isOn: $enabled)
                        .font(.caption)
                }
                Section(syncText("sync.ignores")) {
                    TextEditor(text: $ignoresText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 84)
                        .scrollContentBackground(.hidden)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .formStyle(.grouped)
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Annuler") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isEdit ? syncText("sync.edit") : syncText("sync.save")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(localPath.isEmpty || drivePath.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    /// Stockage : on garde « Sync/Photos » dans le champ, sans le préfixe remote.
    private var drivePathHintBinding: Binding<String> {
        Binding(get: { drivePath },
                set: { newValue in
                    var v = newValue
                    if let colon = v.firstIndex(of: ":") { v = String(v[v.index(after: colon)...]) }
                    drivePath = v.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                })
    }

    private var preview: String {
        let remote = (loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive").trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        return "\(remote):\(drivePath)"
    }

    private func chooseLocal() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = localPath.isEmpty ? nil : URL(fileURLWithPath: localPath)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        localPath = url.path
        if name.isEmpty || name == URL(fileURLWithPath: original.localPath).lastPathComponent {
            name = url.lastPathComponent
        }
        if drivePath.isEmpty {
            drivePath = "Sync/\(url.lastPathComponent)"
        }
    }

    private func save() {
        let expanded = expandedPath(localPath)
        guard FileManager.default.fileExists(atPath: expanded) else {
            errorMessage = "Dossier introuvable : \(expanded)"
            return
        }
        var pair = original
        pair.name = name.isEmpty ? URL(fileURLWithPath: expanded).lastPathComponent : name
        pair.localPath = expanded
        pair.drivePath = drivePath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        pair.direction = direction
        pair.conflictPolicy = conflictPolicy
        pair.ignores = ignoresText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        pair.enabled = enabled
        onSave(pair)
        dismiss()
    }
}
