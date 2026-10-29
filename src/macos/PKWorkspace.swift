// Primary product navigation and lightweight menu-bar panel. No transfer is triggered by opening a view.
import SwiftUI
import AppKit
import Combine
import ServiceManagement

/// System registration is the source of truth; no preference that can drift from macOS.
@MainActor final class WorkspaceLoginItem: ObservableObject {
    static let shared = WorkspaceLoginItem()
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var error: String?
    var requested: Bool { status == .enabled || status == .requiresApproval }
    func refresh() { status = SMAppService.mainApp.status }
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch { self.error = error.localizedDescription }
        refresh()
    }
}

enum MenuActivityDisplay: String, CaseIterable {
    case speed, remaining, icon
    var title: String { workspaceText("display.\(rawValue)") }
}

/// Only the active rclone run has a known total; queued pairs have not been scanned yet.
enum MenuActivity {
    static func title(display: MenuActivityDisplay, busy: Bool, dryRun: Bool, progress: RunProgress?) -> String {
        guard busy, display != .icon else { return "" }
        guard !dryRun else { return workspaceText("previewShort") }
        guard let progress else { return "…" }
        if progress.phase == .verifying { return workspaceText("checkingShort") }
        if progress.phase == .listing { return "…" }
        if progress.phase == .deleting { return workspaceText("deletingShort") }
        if display == .remaining, progress.transfersTotal > 0 {
            return syncFileCount(max(0, progress.transfersTotal - progress.transfersDone))
        }
        if display == .speed, progress.speed.isFinite, progress.speed >= 0, progress.speed < Double(Int64.max) {
            return "\(SyncEngine.byteText(Int64(progress.speed)))/s"
        }
        return "…"
    }
}

struct WorkspaceGeneralSettings: View {
    @ObservedObject private var login = WorkspaceLoginItem.shared
    @AppStorage("menu-activity-display") private var display = MenuActivityDisplay.speed.rawValue
    @AppStorage("menu-panel-on-hover") private var hover = true
    @AppStorage("app-language") private var language = "fr"
    var body: some View {
        Form {
            Section(workspaceText("startup")) {
                Toggle(workspaceText("login"), isOn: Binding(get: { login.requested }, set: { login.setEnabled($0) }))
                    .disabled(CommandLine.arguments.contains("--qa-screen"))
                Text(workspaceText("loginNote")).font(.caption).foregroundStyle(.secondary)
                if login.status == .requiresApproval {
                    Label(workspaceText("loginApproval"), systemImage: "exclamationmark.circle").foregroundStyle(.orange)
                    Button(workspaceText("systemSettings")) { SMAppService.openSystemSettingsLoginItems() }
                }
                if let error = login.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            }
            Section(workspaceText("menuBar")) {
                Picker(workspaceText("activityDisplay"), selection: $display) {
                    ForEach(MenuActivityDisplay.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Text(workspaceText("activityNote")).font(.caption).foregroundStyle(.secondary)
                Toggle(workspaceText("hover"), isOn: $hover)
            }
        }
        .formStyle(.grouped).scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login.refresh() }
    }
}

enum WorkspaceAppVersion {
    // Always identify the running app, not a published version or selected update channel.
    static var installed: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

enum WorkspaceMode: String, CaseIterable {
    case archive, sync
    var title: String { workspaceText(rawValue) }
    var symbol: String { self == .sync ? "arrow.triangle.2.circlepath" : "archivebox" }
    var detail: String { workspaceText(self == .sync ? "syncDetail" : "archiveDetail") }
}

final class WorkspaceNavigation: ObservableObject {
    // Always start a new app session on Archive, regardless of the last tab used.
    // The current tab is retained in memory when returning from Settings.
    @Published var mode: WorkspaceMode = .archive
    @Published var showingSettings = false
    @Published var archiveRunning = false
    @Published var archiveCount = 0
    @Published var archiveTotal = 0
}

func workspaceText(_ key: String) -> String {
    let values: [String: [String]] = [
        "sync": ["Synchronisation", "Synchronization", "Sincronización", "Synchronisierung"],
        "archive": ["Archives", "Archives", "Archivos", "Archive"],
        "syncDetail": ["En arrière-plan · Mac ⇄ Drive", "In the background · Mac ⇄ Drive", "En segundo plano · Mac ⇄ Drive", "Im Hintergrund · Mac ⇄ Drive"],
        "archiveDetail": ["Libérer le Bureau → archive mensuelle", "Clear Desktop → monthly archive", "Limpiar Escritorio → archivo mensual", "Schreibtisch leeren → Monatsarchiv"],
        "settings": ["Réglages", "Settings", "Ajustes", "Einstellungen"],
        "settingsDetail": ["Préférences de l’app", "App preferences", "Preferencias de la app", "App-Einstellungen"],
        "editMenu": ["Édition", "Edit", "Edición", "Bearbeiten"],
        "undo": ["Annuler", "Undo", "Deshacer", "Rückgängig"],
        "redo": ["Rétablir", "Redo", "Rehacer", "Wiederholen"],
        "cut": ["Couper", "Cut", "Cortar", "Ausschneiden"],
        "copy": ["Copier", "Copy", "Copiar", "Kopieren"],
        "paste": ["Coller", "Paste", "Pegar", "Einfügen"],
        "selectAll": ["Tout sélectionner", "Select All", "Seleccionar todo", "Alles auswählen"],
        "back": ["Retour", "Back", "Volver", "Zurück"],
        "openSync": ["Ouvrir la synchronisation", "Open synchronization", "Abrir sincronización", "Synchronisierung öffnen"],
        "openArchive": ["Ouvrir l’archivage", "Open archiving", "Abrir archivado", "Archivierung öffnen"],
        "noPairs": ["Aucun dossier configuré", "No folders configured", "Sin carpetas configuradas", "Keine Ordner eingerichtet"],
        "addPairs": ["Choisissez vos dossiers dans l’onglet Synchronisation. Ils démarrent en simulation uniquement.", "Choose your folders in the Synchronization tab. They start in preview-only mode.", "Elige carpetas en la pestaña Sincronización. Comienzan en modo simulación.", "Ordner im Tab Synchronisierung auswählen. Sie starten im Vorschaumodus."],
        "paused": ["Synchronisation en pause", "Synchronization paused", "Sincronización en pausa", "Synchronisierung pausiert"],
        "ready": ["Aucun transfert en cours", "No transfer running", "Sin transferencias en curso", "Keine laufende Übertragung"],
        "previewOnly": ["Simulation uniquement", "Preview only", "Solo simulación", "Nur Vorschau"],
        "needsAttention": ["À vérifier", "Needs attention", "Requiere atención", "Prüfung erforderlich"],
        "recent": ["Dernière activité", "Latest activity", "Actividad reciente", "Letzte Aktivität"],
        "noActivity": ["Aucune exécution pour l’instant", "No runs yet", "Aún no hay ejecuciones", "Noch keine Ausführungen"],
        "archiveNote": ["Envoie les fichiers du Bureau dans une archive mensuelle sur Drive, puis les retire du Mac après succès. Ce mode ne synchronise pas vos dossiers dans les deux sens.", "Sends Desktop files to a monthly Drive archive, then removes them from the Mac after success. This mode does not synchronize folders in both directions.", "Envía los archivos del Escritorio a un archivo mensual en Drive y los retira del Mac tras el éxito. Este modo no sincroniza carpetas en ambos sentidos.", "Sendet Schreibtischdateien in ein Monatsarchiv auf Drive und entfernt sie nach Erfolg vom Mac. Dieser Modus synchronisiert Ordner nicht in beide Richtungen."],
        "source": ["Source", "Source", "Origen", "Quelle"],
        "destination": ["Archive du mois", "Monthly archive", "Archivo del mes", "Monatsarchiv"],
        "support": ["Soutenir sur Ko-fi", "Support on Ko-fi", "Apoyar en Ko-fi", "Auf Ko-fi unterstützen"],
        "updates": ["Rechercher les mises à jour…", "Check for Updates…", "Buscar actualizaciones…", "Nach Updates suchen…"],
        "about": ["À propos de PKarchives", "About PKarchives", "Acerca de PKarchives", "Über PKarchives"],
        "quit": ["Quitter PKarchives", "Quit PKarchives", "Salir de PKarchives", "PKarchives beenden"],
        "options": ["Options de PKarchives", "PKarchives options", "Opciones de PKarchives", "PKarchives-Optionen"],
        "hover": ["Ouvrir ce panneau au survol", "Show this panel on hover", "Mostrar este panel al pasar el cursor", "Dieses Panel beim Darüberfahren öffnen"],
        "history": ["Historique et rapports", "History and reports", "Historial e informes", "Verlauf und Berichte"],
        "inProgress": ["Archivage en cours", "Archiving in progress", "Archivando", "Archivierung läuft"],
        "general": ["Général", "General", "General", "Allgemein"],
        "startup": ["Démarrage", "Startup", "Inicio", "Start"],
        "login": ["Lancer à l’ouverture de session", "Launch at login", "Iniciar al entrar en sesión", "Bei Anmeldung starten"],
        "loginNote": ["Démarre discrètement dans la barre des menus à l’ouverture de votre session Mac.", "Starts quietly in the menu bar when you log in to your Mac.", "Se inicia en la barra de menús al entrar en tu Mac.", "Startet bei der Mac-Anmeldung unauffällig in der Menüleiste."],
        "loginApproval": ["Autorisation requise dans les réglages macOS.", "Approval required in macOS settings.", "Se requiere autorización en los ajustes de macOS.", "Genehmigung in den macOS-Einstellungen erforderlich."],
        "systemSettings": ["Ouvrir les éléments d’ouverture…", "Open Login Items…", "Abrir ítems de inicio…", "Anmeldeobjekte öffnen…"],
        "menuBar": ["Barre des menus", "Menu bar", "Barra de menús", "Menüleiste"],
        "activityDisplay": ["Afficher pendant un transfert", "Show during transfers", "Mostrar durante transferencias", "Während Übertragungen anzeigen"],
        "display.speed": ["Débit", "Transfer speed", "Velocidad", "Übertragungsrate"],
        "display.remaining": ["Fichiers restants", "Remaining files", "Archivos restantes", "Verbleibende Dateien"],
        "display.icon": ["Icône seule", "Icon only", "Solo icono", "Nur Symbol"],
        "activityNote": ["Données rclone réelles pour l’exécution en cours. Le total peut évoluer pendant l’analyse ; les paires en attente ne sont pas incluses. Au repos, seule l’icône reste affichée.", "Real rclone data for the current run. Totals may change during scanning; queued pairs are not included. Only the icon remains when idle.", "Datos reales de rclone de la ejecución actual. El total puede cambiar durante el análisis; no incluye parejas en cola. En reposo solo aparece el icono.", "Echte rclone-Daten des aktuellen Laufs. Summen können sich beim Scannen ändern; wartende Paare sind nicht enthalten. Im Leerlauf bleibt nur das Symbol."],
        "previewShort": ["Simulation", "Preview", "Simulación", "Vorschau"],
        "checkingShort": ["Vérification", "Checking", "Verificación", "Prüfung"],
        "deletingShort": ["Suppressions", "Deleting", "Borrando", "Löschen"],
        "pairDetails": ["Inventaire et comparaison", "Inventory and comparison", "Inventario y comparación", "Bestand und Vergleich"],
        "showFolder": ["Afficher dans le Finder", "Show in Finder", "Mostrar en Finder", "Im Finder anzeigen"],
        "currentPhase": ["Exécution en cours", "Current run", "Ejecución actual", "Aktueller Lauf"],
    ]
    let lang = UserDefaults.standard.string(forKey: "app-language") ?? "fr"
    return values[key]?[["fr": 0, "en": 1, "es": 2, "de": 3][lang] ?? 1] ?? key
}

struct WorkspaceHeaderView: View {
    @ObservedObject var navigation: WorkspaceNavigation
    let select: (WorkspaceMode) -> Void
    let settings: () -> Void
    @AppStorage("app-language") private var language = "fr"

    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PKarchives").font(.system(size: 14, weight: .semibold))
                    Text(WorkspaceAppVersion.installed)
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 32)
            HStack(spacing: 4) {
                ForEach(WorkspaceMode.allCases, id: \.self) { mode in
                    Button { select(mode) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: mode.symbol).font(.system(size: 15, weight: .medium))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(mode.title).font(.system(size: 13, weight: .semibold))
                                Text(mode.detail).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(navigation.mode == mode && !navigation.showingSettings ? Color.accentColor : Color.primary)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(navigation.mode == mode && !navigation.showingSettings ? Color.accentColor.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(mode == .archive ? "1" : "2", modifiers: .command)
                    .accessibilityLabel(mode.title)
                    .accessibilityAddTraits(navigation.mode == mode && !navigation.showingSettings ? .isSelected : [])
                    .help(mode.detail)
                }
                Button(action: settings) {
                    HStack(spacing: 9) {
                        Image(systemName: "gearshape").font(.system(size: 15, weight: .medium))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(workspaceText("settings")).font(.system(size: 13, weight: .semibold))
                            Text(workspaceText("settingsDetail")).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(navigation.showingSettings ? Color.accentColor : Color.primary)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(navigation.showingSettings ? Color.accentColor.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain).keyboardShortcut(",", modifiers: .command)
                .accessibilityLabel(workspaceText("settings"))
                .accessibilityAddTraits(navigation.showingSettings ? .isSelected : [])
                .help(workspaceText("settingsDetail"))
            }
        }
        .padding(.horizontal, 24).frame(maxWidth: .infinity).frame(height: 80)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// Shared production panel, also rendered directly by the offscreen UI tests.
struct WorkspacePopoverView: View {
    @ObservedObject var engine: SyncEngine
    @ObservedObject var navigation: WorkspaceNavigation
    let open: @MainActor (WorkspaceMode, Bool) -> Void
    let settings: @MainActor () -> Void
    let support: @MainActor () -> Void
    let updates: @MainActor () -> Void
    let about: @MainActor () -> Void
    let quit: @MainActor () -> Void
    let hoverChanged: @MainActor (Bool) -> Void
    @State private var mode: WorkspaceMode
    @State private var expandedPairs: Set<UUID> = []
    @State private var confirmingPair: SyncPair?
    @AppStorage("app-language") private var language = "fr"
    @AppStorage("menu-panel-on-hover") private var hoverEnabled = true

    init(engine: SyncEngine, navigation: WorkspaceNavigation,
         open: @escaping @MainActor (WorkspaceMode, Bool) -> Void, settings: @escaping @MainActor () -> Void,
         support: @escaping @MainActor () -> Void, updates: @escaping @MainActor () -> Void, about: @escaping @MainActor () -> Void,
         quit: @escaping @MainActor () -> Void, hoverChanged: @escaping @MainActor (Bool) -> Void) {
        self.engine = engine; self.navigation = navigation
        self.open = open; self.settings = settings; self.support = support; self.updates = updates
        self.about = about; self.quit = quit; self.hoverChanged = hoverChanged
        _mode = State(initialValue: engine.busy || !engine.pairs.isEmpty ? .sync : navigation.mode)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PKarchives").font(.headline)
                    Text(WorkspaceAppVersion.installed)
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Menu {
                    Button(action: settings) { Label(workspaceText("settings"), systemImage: "gearshape") }
                    Toggle(workspaceText("hover"), isOn: $hoverEnabled)
                    Button(action: support) {
                        Label {
                            Text(workspaceText("support"))
                        } icon: {
                            if let url = Bundle.main.url(forResource: "kofi-logo", withExtension: "png"), let image = NSImage(contentsOf: url) {
                                Image(nsImage: image).resizable().scaledToFit().frame(width: 16, height: 16)
                            } else { Image(systemName: "heart") }
                        }
                    }
                    Button(action: updates) { Label(workspaceText("updates"), systemImage: "arrow.down.circle") }
                    Button(action: about) { Label(workspaceText("about"), systemImage: "info.circle") }
                    Divider()
                    Button(action: quit) { Label(workspaceText("quit"), systemImage: "power") }
                } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                    .menuStyle(.borderlessButton).frame(width: 28)
                    .accessibilityLabel(workspaceText("options"))
            }.padding(18)
            Picker(workspaceText("options"), selection: $mode) {
                ForEach(WorkspaceMode.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 16).padding(.bottom, 16)
            Divider()
            if mode == .sync { syncPanel } else { archivePanel }
            Divider()
            HStack(spacing: 12) {
                if mode == .sync {
                    Button { open(.sync, true) } label: {
                        Label(workspaceText("history"), systemImage: "clock.arrow.circlepath")
                    }.buttonStyle(.plain).font(.caption)
                } else {
                    Text(workspaceText("destination")).font(.caption)
                }
                Spacer()
                Button(action: settings) { Image(systemName: "gearshape") }
                    .buttonStyle(.plain).help(workspaceText("settings")).accessibilityLabel(workspaceText("settings"))
                Button(action: quit) { Image(systemName: "power") }
                    .buttonStyle(.plain).help(workspaceText("quit")).accessibilityLabel(workspaceText("quit"))
            }.padding(16).foregroundStyle(.secondary)
        }
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
        .onHover(perform: hoverChanged)
        .alert(syncText("realRun"), isPresented: Binding(get: { confirmingPair != nil }, set: { if !$0 { confirmingPair = nil } })) {
            Button(syncText("sync")) {
                if let pair = confirmingPair { engine.syncPair(pair.id, resync: pair.direction.usesBisync && pair.needsResync) }
            }
            Button(syncText("cancel"), role: .cancel) {}
        } message: { Text(syncText(confirmingPair?.direction.usesBisync == true ? "mergeNote" : "directionNote")) }
    }

    private var summary: String {
        if let error = engine.storageError { return error }
        if engine.busy { return engine.progressText }
        if navigation.archiveRunning { return workspaceText("inProgress") }
        if engine.isPaused { return workspaceText("paused") }
        if engine.pairs.contains(where: { engine.cooldownUntil(for: $0) != nil }) { return syncText("rateLimited") }
        if engine.pairs.contains(where: { ["error", "unverified", "needsResync", "rateLimited"].contains($0.lastOutcome) }) { return workspaceText("needsAttention") }
        return workspaceText("ready")
    }

    private var syncPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if engine.busy { liveProgress }
            if engine.pairs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text(workspaceText("noPairs")).font(.headline)
                    Text(workspaceText("addPairs")).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 14)
            } else {
                // The running pair already lives in the block above: listing it again
                // showed the same pair twice ("Analyse…" / "Transfert en cours").
                let visiblePairs = engine.pairs.filter { $0.id != engine.runningPairID }
                if !visiblePairs.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(visiblePairs.enumerated()), id: \.element.id) { index, pair in
                                pairRow(pair)
                                if index < visiblePairs.count - 1 { Divider() }
                            }
                        }
                    }.frame(height: min(CGFloat(visiblePairs.count) * 78 + CGFloat(expandedPairs.count) * 160, engine.busy ? 220 : 300))
                }
            }
            HStack {
                Button { engine.pairs.isEmpty ? open(.sync, false) : engine.syncAll() } label: {
                    Label(engine.pairs.isEmpty ? syncText("add") : syncText("all"), systemImage: "arrow.triangle.2.circlepath")
                }.buttonStyle(.borderedProminent)
                    .disabled(engine.busy || engine.storageError != nil || (!engine.pairs.isEmpty && !engine.pairs.contains { $0.enabled && engine.cooldownUntil(for: $0) == nil && ($0.previewOnly || !$0.direction.usesBisync || !$0.needsResync) }))
                Spacer()
                if !engine.pairs.isEmpty {
                    Button { engine.syncAll(dryRun: true) } label: { Image(systemName: "eye") }
                        .help(syncText("simulateAll")).accessibilityLabel(syncText("simulateAll"))
                        .disabled(engine.busy || !engine.pairs.contains(where: { $0.enabled && engine.cooldownUntil(for: $0) == nil }))
                    Button { if engine.isPaused { engine.resume() } else { engine.pauseForHours(1) } } label: {
                        Image(systemName: engine.isPaused ? "play" : "pause")
                    }.help(syncText(engine.isPaused ? "resume" : "pause")).accessibilityLabel(syncText(engine.isPaused ? "resume" : "pause"))
                }
            }.controlSize(.regular)
            Button { open(.sync, false) } label: { Label(workspaceText("openSync"), systemImage: "arrow.up.right.square") }
                .buttonStyle(.plain).font(.caption).foregroundStyle(Color.accentColor)
            if let run = engine.runs.first, !engine.busy {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: run.dryRun ? "eye" : "clock.arrow.circlepath").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(run.pair.name) · \(syncText(run.outcome))").font(.caption)
                        Text(run.started.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(10).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            }
        }.padding(16)
    }

    private var liveProgress: some View {
        let progress = engine.runProgress ?? RunProgress()
        let pair = engine.pairs.first { $0.id == engine.runningPairID }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pair?.name ?? syncText("running")).font(.headline)
                    Text(engine.isDryRun ? syncText("simulating") : syncText("phase.\(progress.phase.rawValue)"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { engine.stopRunning() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).help(syncText("stopRun")).accessibilityLabel(syncText("stopRun"))
            }
            if !engine.isDryRun, progress.bytesTotal > 0, progress.phase != .listing, progress.phase != .verifying {
                ProgressView(value: min(1, max(0, Double(progress.bytesDone) / Double(progress.bytesTotal))))
                Text("\(SyncEngine.byteText(progress.bytesDone)) / \(SyncEngine.byteText(progress.bytesTotal))")
                    .font(.caption.monospacedDigit())
            } else { ProgressView().controlSize(.small) }
            if !engine.isDryRun, progress.phase == .push || progress.phase == .pull {
                HStack {
                    Text(MenuActivity.title(display: .speed, busy: true, dryRun: false, progress: progress))
                    Spacer()
                    if progress.transfersTotal > 0 {
                        Text("\(syncFileCount(max(0, progress.transfersTotal - progress.transfersDone))) · \(syncText("remaining"))")
                    }
                }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if let eta = progress.eta { Text("~\(SyncEngine.durationText(eta)) · \(syncText("remaining"))").font(.caption).foregroundStyle(.secondary) }
            }
            if !engine.queue.isEmpty { Text("\(syncText("queueTitle")) · \(engine.queue.count)").font(.caption).foregroundStyle(.secondary) }
        }.padding(12).background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func pairRow(_ pair: SyncPair) -> some View {
        let state = engine.presentationState(for: pair)
        let attention = ["error", "unverified", "needsResync", "rateLimited", "interrupted"].contains(state)
        let running = engine.runningPairID == pair.id
        let tint: Color = attention ? .orange : state == "verified" ? .green : .secondary
        return DisclosureGroup(isExpanded: Binding(get: { expandedPairs.contains(pair.id) }, set: {
            if $0 { expandedPairs.insert(pair.id) } else { expandedPairs.remove(pair.id) }
        })) {
            VStack(alignment: .leading, spacing: 10) {
                SyncPairLocations(pair: pair, plan: engine.previewRun(for: pair.id)?.plan)
                if let message = pair.lastMessage, attention {
                    Text(SyncDiagnostic.clean(message)).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
                if let date = pair.lastRun {
                    Text("\(syncText("verified")) · \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary)
                }
                HStack {
                    Button(syncText("simulate")) { engine.syncPair(pair.id, dryRun: true) }
                        .disabled(engine.busy || !pair.enabled || engine.storageError != nil || engine.cooldownUntil(for: pair) != nil)
                    Button(syncText("sync")) {
                        if pair.previewOnly || pair.direction.usesBisync && pair.needsResync { confirmingPair = pair }
                        else { engine.syncPair(pair.id) }
                    }.disabled(engine.busy || !pair.enabled || engine.storageError != nil || engine.cooldownUntil(for: pair) != nil)
                    Spacer()
                    Button { open(.sync, false) } label: { Image(systemName: "arrow.up.right.square") }
                        .accessibilityLabel(workspaceText("openSync")).help(workspaceText("openSync"))
                }.controlSize(.small)
                if let run = engine.runs.first(where: { $0.pair.id == pair.id }) {
                    Button(syncText("report")) { if let url = engine.readableReportURL(for: run) { NSWorkspace.shared.open(url) } }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(Color.accentColor)
                }
            }.padding(.top, 8).padding(.bottom, 4)
        } label: {
            HStack(spacing: 10) {
                if running { ProgressView().controlSize(.small).frame(width: 20) }
                else { Image(systemName: attention ? "exclamationmark.triangle" : state == "verified" ? "checkmark.circle" : !pair.enabled ? "pause.circle" : "folder").foregroundStyle(tint).frame(width: 20) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(pair.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                    Text(syncText(state)).font(.caption).foregroundStyle(tint)
                    if pair.previewOnly { Text(syncText("previewOnly")).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer()
                Text(pair.direction.arrow).foregroundStyle(.secondary).accessibilityLabel(pair.direction.label)
            }.padding(.vertical, 10)
        }
    }

    private var archivePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(workspaceText("archiveDetail"), systemImage: "archivebox").font(.headline)
            Text(workspaceText("archiveNote")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspaceText("source")).font(.caption).foregroundStyle(.secondary)
                    Text(shortPath(desktopPath())).font(.system(.caption, design: .monospaced))
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspaceText("destination")).font(.caption).foregroundStyle(.secondary)
                    Text(monthFolder()).font(.system(.caption, design: .monospaced))
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            if navigation.archiveRunning {
                HStack { ProgressView().controlSize(.small); Text("\(navigation.archiveCount) / \(navigation.archiveTotal)").monospacedDigit() }.font(.caption)
            }
            Button { open(.archive, false) } label: { Label(workspaceText("openArchive"), systemImage: "arrow.up.right.square") }
                .buttonStyle(.borderedProminent)
        }.padding(18)
    }
}

/// Passive tracking overlay: hit testing is always forwarded to the native status button.
final class StatusHoverView: NSView {
    var entered: (() -> Void)?
    var exited: (() -> Void)?
    private var area: NSTrackingArea?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func updateTrackingAreas() {
        if let area { removeTrackingArea(area) }
        let next = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(next); area = next
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { entered?() }
    override func mouseExited(with event: NSEvent) { exited?() }
}
