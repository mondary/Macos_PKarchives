// PKarchives v2 — interface moderne (WKWebView)
// Même moteur que la v1 (archive.sh + rclone) : scan du Bureau avec vignettes,
// cartes animées qui s'envolent vers le Drive puis se dissolvent (suppression).
import SwiftUI
import AppKit
import Combine
import WebKit
import QuickLookThumbnailing
import CoreServices
import CryptoKit
import Sparkle

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

// Un seul nom partout : dossier de montage, volume Finder, journal, interface.
func mountLinkName() -> String {
    loadEnv("PKARCHIVES_DESKTOP_LINK_NAME") ?? "DesktopArchive"
}

func mountPath() -> String {
    "\(NSHomeDirectory())/\(mountLinkName())"
}

func shortPath(_ p: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
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

// MARK: - Réglages natifs

private enum ArchiveLanguage: String, CaseIterable {
    case fr, en, es, de
    var flag: String { ["fr":"🇫🇷", "en":"🇬🇧", "es":"🇪🇸", "de":"🇩🇪"][rawValue]! }
    var name: String { ["fr":"Français", "en":"English", "es":"Español", "de":"Deutsch"][rawValue]! }
}

private struct ArchivePreferencesView: View {
    let delegate: AppDelegate
    @ObservedObject var navigation: ArchivePreferencesNavigation
    @ObservedObject private var updater = ArchiveUpdaterManager.shared
    @AppStorage("app-language") private var language = "fr"
    @AppStorage("updateChannel") private var updateChannel = "stable"
    @State private var query = ""
    @State private var folder = loadEnv("PKARCHIVES_DRIVE_FOLDER_ID") ?? ""
    @State private var desktop = desktopPath()
    @State private var remote = loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive"
    private let sections: [(String, String)] = [("archive","archivebox"),("library","square.grid.2x2"),("credits","text.book.closed"),("support","heart.fill"),("about","info.circle")]
    private var copy: [String: [String: String]] { [
        "archive":["fr":"Archivage","en":"Archiving","es":"Archivo","de":"Archivierung"],
        "library":["fr":"Project Library","en":"Project Library","es":"Biblioteca de proyectos","de":"Projektbibliothek"],
        "support":["fr":"Soutenir","en":"Support","es":"Apoyar","de":"Unterstützen"],
        "credits":["fr":"Crédits","en":"Credits","es":"Créditos","de":"Credits"],
        "about":["fr":"À propos","en":"About","es":"Acerca de","de":"Über"],
        "search":["fr":"Rechercher dans les réglages","en":"Search settings","es":"Buscar ajustes","de":"Einstellungen suchen"],
        "back.archive":["fr":"Retour à l’archive","en":"Back to archive","es":"Volver al archivo","de":"Zurück zum Archiv"],
        "save":["fr":"Enregistrer les réglages","en":"Save settings","es":"Guardar ajustes","de":"Einstellungen sichern"],
        "destination":["fr":"Identifiant du dossier Google Drive","en":"Google Drive folder ID","es":"ID de carpeta de Google Drive","de":"Google-Drive-Ordner-ID"],
        "source":["fr":"Dossier source à archiver","en":"Desktop folder to archive","es":"Carpeta de origen","de":"Zu archivierender Quellordner"],
        "remote":["fr":"Remote rclone","en":"rclone remote","es":"Remote de rclone","de":"rclone-Remote"],
        "googleDrive":["fr":"Google Drive","en":"Google Drive","es":"Google Drive","de":"Google Drive"],
        "license":["fr":"Licence MIT · macOS 14+","en":"MIT License · macOS 14+","es":"Licencia MIT · macOS 14+","de":"MIT-Lizenz · macOS 14+"],
        "group.app":["fr":"APPLICATION","en":"APP","es":"APLICACIÓN","de":"APP"],
        "group.projects":["fr":"PROJETS PK","en":"PK PROJECTS","es":"PROYECTOS PK","de":"PK-PROJEKTE"],
        "search.none":["fr":"Aucun réglage trouvé","en":"No setting found","es":"No se encontró ningún ajuste","de":"Keine Einstellung gefunden"],
        "library.title":["fr":"Project Library","en":"Project Library","es":"Biblioteca de proyectos","de":"Projekt-Bibliothek"],
        "library.subtitle":["fr":"Découvrez les autres outils et projets que je développe.","en":"Discover the other tools and projects I build.","es":"Descubre las demás herramientas y proyectos que creo.","de":"Entdecke die anderen Tools und Projekte, die ich baue."],
        "library.more":["fr":"Plus de projets","en":"More projects","es":"Más proyectos","de":"Weitere Projekte"],
        "library.star":["fr":"Étoiler sur GitHub","en":"Star on GitHub","es":"Añadir estrella en GitHub","de":"Auf GitHub markieren"],
        "library.viewAll":["fr":"Voir tous les dépôts sur GitHub","en":"View all repositories on GitHub","es":"Ver todos los repositorios en GitHub","de":"Alle Repositories auf GitHub ansehen"],
        "kind.macos":["fr":"APP MACOS","en":"MACOS APP","es":"APP MACOS","de":"MACOS-APP"],
        "kind.chrome":["fr":"EXTENSION CHROME","en":"CHROME EXTENSION","es":"EXTENSIÓN CHROME","de":"CHROME-ERWEITERUNG"],
        "kind.cross":["fr":"CHROME / MACOS / WINDOWS / LINUX","en":"CHROME / MACOS / WINDOWS / LINUX","es":"CHROME / MACOS / WINDOWS / LINUX","de":"CHROME / MACOS / WINDOWS / LINUX"],
        "desc.PKwindowsManagement":["fr":"Gérez vos fenêtres au clavier, organisez vos sessions en Rooms et lancez vite vos applications depuis la barre de menus.","en":"Manage windows by keyboard, organize sessions in Rooms and launch apps quickly from the menu bar.","es":"Gestiona ventanas con el teclado, organiza sesiones en Rooms y lanza apps desde la barra de menús.","de":"Fenster per Tastatur verwalten, Sitzungen in Rooms organisieren und Apps über die Menüleiste starten."],
        "desc.PKbrain":["fr":"App de notes avec calcul intégré, palette de commandes et raccourcis clavier en priorité.","en":"Notes app with inline calculation, command palette, and keyboard-first shortcuts.","es":"App de notas con cálculo integrado, paleta de comandos y atajos de teclado.","de":"Notizen-App mit integrierter Berechnung, Befehlspalette und Tastaturkürzeln."],
        "desc.MonoCodePK":["fr":"Tous vos agents de code dans une app native — Claude Code, Codex, Cursor, OpenCode et plus.","en":"All your coding agents in one native app — Claude Code, Codex, Cursor, OpenCode and more.","es":"Todos tus agentes de código en una app nativa: Claude Code, Codex, Cursor, OpenCode y más.","de":"Alle Coding-Agenten in einer nativen App — Claude Code, Codex, Cursor, OpenCode und mehr."],
        "desc.PKMediaDownloader":["fr":"Téléchargeur vidéo propulsé par yt-dlp — YouTube, Instagram, X, TikTok et des milliers d'autres.","en":"Video downloader powered by yt-dlp — YouTube, Instagram, X, TikTok and thousands more.","es":"Descargador de vídeo con yt-dlp: YouTube, Instagram, X, TikTok y miles más.","de":"Video-Downloader mit yt-dlp — YouTube, Instagram, X, TikTok und Tausende mehr."],
        "desc.PKarchives":["fr":"Archivez votre Bureau vers Google Drive avec rclone, via une interface macOS native ou en CLI/TUI.","en":"Archive your Desktop to Google Drive with rclone, using a native macOS interface or CLI/TUI.","es":"Archiva el Escritorio en Google Drive con rclone, desde macOS o la CLI/TUI.","de":"Desktop mit rclone über die native macOS-App oder CLI/TUI in Google Drive archivieren."],
        "desc.PKmonitor":["fr":"CPU, GPU, RAM, réseau et disque dans la barre de menus.","en":"CPU, GPU, RAM, network and disk metrics in the menu bar.","es":"Métricas de CPU, GPU, RAM, red y disco en la barra de menús.","de":"CPU-, GPU-, RAM-, Netzwerk- und Festplattenwerte in der Menüleiste."],
        "desc.PKpowerlines":["fr":"Une powerline native multi-écrans affichant RAM, CPU, réseau ou batterie en temps réel.","en":"A native multi-display powerline showing RAM, CPU, network or battery in real time.","es":"Powerline nativa multidispositivo con RAM, CPU, red o batería en tiempo real.","de":"Native Multi-Display-Powerline mit RAM, CPU, Netzwerk oder Akku in Echtzeit."],
        "desc.LaunchPad":["fr":"Analysez les agents utilisateur et démons système avec une analyse de sécurité locale.","en":"Scan and audit user agents and system daemons with local security analysis.","es":"Audita agentes de usuario y demonios del sistema con análisis local de seguridad.","de":"Benutzeragenten und System-Daemons lokal auf Sicherheit prüfen."],
        "desc.PKMail":["fr":"Client mail IMAP immersif avec interface HTML vanilla et workflows façon Gmail.","en":"An immersive IMAP mail client with a vanilla HTML interface and Gmail-style workflows.","es":"Cliente de correo IMAP con interfaz HTML y flujos de trabajo al estilo Gmail.","de":"Immersiver IMAP-Mailclient mit HTML-Oberfläche und Gmail-ähnlichen Abläufen."],
        "desc.PKChromeShortcuts":["fr":"Contrôlez onglets, navigation et split view au clavier.","en":"Control tabs, navigation and split view with keyboard shortcuts.","es":"Controla pestañas, navegación y pantalla dividida con atajos de teclado.","de":"Tabs, Navigation und geteilte Ansicht per Tastenkürzeln steuern."],
        "support.title":["fr":"Soutenir PKarchives","en":"Support PKarchives","es":"Apoyar PKarchives","de":"PKarchives unterstützen"],
        "support.subtitle":["fr":"Si cette application vous est utile, vous pouvez soutenir son développement.","en":"If you enjoy using this app, consider supporting its development."],
        "support.coffee":["fr":"Offrir un café au développeur","en":"Support the developer with a coffee","es":"Invita un café al desarrollador","de":"Unterstütze den Entwickler mit einem Kaffee"],
        "support.donate":["fr":"Soutenir sur Ko-fi","en":"Support on Ko-fi","es":"Apoyar en Ko-fi","de":"Auf Ko-fi unterstützen"],
        "support.github.subtitle":["fr":"Code source et versions","en":"Source code and releases","es":"Código fuente y versiones","de":"Quellcode und Releases"],
        "support.issues.title":["fr":"Signaler un problème","en":"Report an issue","es":"Informar de un problema","de":"Problem melden"],
        "support.issues.subtitle":["fr":"Bugs, demandes de fonctionnalités, retours","en":"Bugs, feature requests, feedback","es":"Errores, solicitudes y comentarios","de":"Fehler, Funktionswünsche, Feedback"],
        "support.profile.title":["fr":"PK sur GitHub","en":"PK on GitHub","es":"PK en GitHub","de":"PK auf GitHub"],
        "support.profile.subtitle":["fr":"Le reste de la collection de projets","en":"The rest of the project collection","es":"El resto de la colección de proyectos","de":"Der Rest der Projektsammlung"],
        "about.greeting":["fr":"Salut l’ami,","en":"Hey friend,","es":"Hola, amiga/o:","de":"Hallo!"],
        "about.pitch":["fr":"PKarchives est né d’une envie simple : garder un Bureau net sans perdre ses fichiers, en les archivant proprement sur Google Drive.","en":"PKarchives was born from a simple idea: keep your Desktop clean without losing files, by archiving them safely to Google Drive.","es":"PKarchives nació de una idea sencilla: mantener el Escritorio limpio sin perder archivos, archivándolos en Google Drive.","de":"PKarchives entstand aus einer einfachen Idee: den Schreibtisch aufgeräumt halten und Dateien sicher in Google Drive archivieren."],
        "about.body":["fr":"L’application repère les fichiers et dossiers du Bureau, les envoie dans une archive mensuelle via rclone, puis garde un historique consultable. Une interface macOS et une CLI/TUI sont disponibles.","en":"The app scans Desktop files and folders, sends them to a monthly archive through rclone, and keeps a browsable history. A macOS app and CLI/TUI are available.","es":"La app detecta archivos y carpetas del Escritorio, los envía a un archivo mensual mediante rclone y conserva un historial. Incluye app para macOS y CLI/TUI.","de":"Die App erkennt Dateien und Ordner auf dem Schreibtisch, archiviert sie monatlich mit rclone und führt einen Verlauf. Verfügbar für macOS und als CLI/TUI."],
        "about.care":["fr":"Conçu pour automatiser sans masquer ce qui se passe : destination, progression et historique restent visibles.","en":"Built to automate without hiding what happens: destination, progress and history stay visible.","es":"Automatiza sin ocultar lo que ocurre: destino, progreso e historial siguen visibles.","de":"Automatisiert, ohne Abläufe zu verbergen: Ziel, Fortschritt und Verlauf bleiben sichtbar."],
        "about.credits.title":["fr":"Crédits & inspirations","en":"Credits & inspirations","es":"Créditos e inspiraciones","de":"Credits & Inspirationen"],
        "about.credits.intro":["fr":"Les composants et outils utilisés par PKarchives, avec les inspirations visuelles clairement séparées.","en":"The components and tools used by PKarchives, with visual inspirations clearly separated.","es":"Los componentes y herramientas de PKarchives, con las inspiraciones visuales claramente separadas.","de":"Die von PKarchives verwendeten Komponenten und Tools, mit klar getrennten visuellen Inspirationen."],
        "about.credit.rclone":["fr":"Transferts de fichiers vers Google Drive.","en":"File transfers to Google Drive.","es":"Transferencias de archivos a Google Drive.","de":"Dateiübertragungen zu Google Drive."],
        "about.credit.sparkle":["fr":"Mises à jour intégrées de l’app macOS.","en":"In-app updates for the macOS app.","es":"Actualizaciones integradas de la app macOS.","de":"Integrierte Updates für die macOS-App."],
        "about.credit.fuse":["fr":"Prérequis externe, à installer séparément, pour monter un remote comme volume macOS.","en":"External prerequisite, installed separately, for mounting a remote as a macOS volume.","es":"Requisito externo, de instalación separada, para montar un remote como volumen macOS.","de":"Externe, separat zu installierende Voraussetzung, um ein Remote als macOS-Volume einzubinden."],
        "about.credit.charm":["fr":"Bibliothèques Go utilisées pour construire l’interface terminale (TUI).","en":"Go libraries used to build the terminal interface (TUI).","es":"Bibliotecas Go utilizadas para construir la interfaz de terminal (TUI).","de":"Go-Bibliotheken für die Terminal-Oberfläche (TUI)."],
        "about.credit.riptide":["fr":"Inspiration pour la navigation et les panneaux de la TUI.","en":"Inspiration for the TUI navigation and panels.","es":"Inspiración para la navegación y los paneles de la TUI.","de":"Inspiration für Navigation und Panels der TUI."],
        "credits.components":["fr":"Composants & outils","en":"Components & tools","es":"Componentes y herramientas","de":"Komponenten & Tools"],
        "credits.inspiration":["fr":"Inspiration d’interface","en":"Interface inspiration","es":"Inspiración de interfaz","de":"Interface-Inspiration"],
        "credits.footer":["fr":"Merci aux auteurs et équipes qui développent ces outils.","en":"Thanks to the authors and teams behind these tools.","es":"Gracias a los autores y equipos que desarrollan estas herramientas.","de":"Danke an die Autorinnen, Autoren und Teams hinter diesen Tools."],
        "about.thanks":["fr":"Merci de l’utiliser et de soutenir les projets indépendants.","en":"Thanks for using it and supporting independent projects.","es":"Gracias por usarla y apoyar proyectos independientes.","de":"Danke, dass du die App nutzt und unabhängige Projekte unterstützt."],
        "about.updates":["fr":"Mises à jour","en":"Updates","es":"Actualizaciones","de":"Aktualisierungen"],
        "about.stable":["fr":"Canal Stable","en":"Stable channel","es":"Canal estable","de":"Stable-Kanal"],
        "about.dev":["fr":"Canal Dev","en":"Dev channel","es":"Canal Dev","de":"Dev-Kanal"],
        "about.notPublished":["fr":"Non publiée","en":"Not published","es":"No publicada","de":"Nicht veröffentlicht"],
        "about.channel.stable":["fr":"Versions publiées et testées. Les mises à jour arrivent avec une release Stable.","en":"Published, tested releases. Stable updates arrive with a published release.","es":"Versiones publicadas y probadas. Las actualizaciones llegan con una release estable.","de":"Veröffentlichte, getestete Versionen. Stable-Updates erscheinen mit einem Release."],
        "about.channel.dev":["fr":"Builds automatiques de main. En Dev, les mises à jour sont téléchargées et installées automatiquement.","en":"Automatic builds from main. Dev updates download and install automatically.","es":"Builds automáticas de main. En Dev, las actualizaciones se descargan e instalan automáticamente.","de":"Automatische Builds von main. Dev-Updates werden automatisch geladen und installiert."],
        "about.check":["fr":"Rechercher les mises à jour…","en":"Check for Updates…","es":"Buscar actualizaciones…","de":"Nach Updates suchen…"],
        "about.version":["fr":"Version installée","en":"Installed version","es":"Versión instalada","de":"Installierte Version"],
        "about.installed":["fr":"Version installée %@","en":"Installed version %@","es":"Versión instalada %@","de":"Installierte Version %@"],
        "footer.kofi":["fr":"Soutenir sur Ko-fi","en":"Support on Ko-fi","es":"Apoyar en Ko-fi","de":"Auf Ko-fi unterstützen"],
        "byPK":["fr":"Par PK","en":"By PK","es":"Por PK","de":"Von PK"],
        "macApp":["fr":"Application macOS","en":"macOS app","es":"Aplicación macOS","de":"macOS-App"],
        "settings.subtitle":["fr":"Configurez la source et la destination de vos archives.","en":"Configure your archive source and destination.","es":"Configura el origen y el destino de tus archivos.","de":"Konfiguriere Quelle und Ziel deiner Archive."],
        "updates.caption":["fr":"Choisissez le canal de mise à jour qui vous convient.","en":"Choose the update channel that works for you.","es":"Elige el canal de actualización que prefieras.","de":"Wähle den passenden Update-Kanal."],
        "update.status.available":["fr":"Mise à jour disponible","en":"Update available","es":"Actualización disponible","de":"Update verfügbar"],
        "update.status.current":["fr":"À jour","en":"Up to date","es":"Actualizado","de":"Aktuell"],
        "update.status.ahead":["fr":"Version installée plus récente","en":"Installed version is newer","es":"La versión instalada es más reciente","de":"Installierte Version ist neuer"],
        "update.status.other":["fr":"Autre canal","en":"Other channel","es":"Otro canal","de":"Anderer Kanal"],
        "update.status.unavailable":["fr":"Version indisponible","en":"Version unavailable","es":"Versión no disponible","de":"Version nicht verfügbar"],
        "update.install":["fr":"Installer %@","en":"Install %@","es":"Instalar %@","de":"%@ installieren"],
        "update.installing":["fr":"Installation de la mise à jour…","en":"Installing update…","es":"Instalando actualización…","de":"Update wird installiert…"],
        "update.failed":["fr":"Échec de l’installation : %@","en":"Installation failed: %@","es":"Error de instalación: %@","de":"Installation fehlgeschlagen: %@"],
        "update.offer.title":["fr":"Installer cette version ?","en":"Install this version?","es":"¿Instalar esta versión?","de":"Diese Version installieren?"],
        "update.offer.message":["fr":"Installer la version %@ du canal %@ ?","en":"Install version %@ from the %@ channel?","es":"¿Instalar la versión %@ del canal %@?","de":"Version %@ aus dem %@-Kanal installieren?"],
        "update.cancel":["fr":"Plus tard","en":"Later","es":"Más tarde","de":"Später"]
    ] }
    private func text(_ key: String) -> String { copy[key]?[language] ?? copy[key]?["en"] ?? key }
    private var filtered: [(String,String)] {
        guard !query.isEmpty else { return sections }
        let terms = query.lowercased().split(separator: " ").map(String.init)
        return sections.filter { item in
             let synonyms = item.0 == "archive" ? "drive bureau desktop folder dossier source rclone remote destination google sauvegarde archivage" : item.0 == "library" ? "projects projets github apps applications" : item.0 == "support" ? "kofi ko-fi donate donation don" : item.0 == "credits" ? "inspirations dépendances dependencies tools outils technologies références references" : "version stable dev update mise à jour about versionning"
            return terms.allSatisfy { (text(item.0) + " " + synonyms).lowercased().contains($0) }
        }
    }
    private let projects: [ArchiveProject] = ArchiveProject.catalog
    private var featuredProject: ArchiveProject { projects[0] }
    private var otherProjects: [ArchiveProject] { Array(projects.dropFirst()) }
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—" }
    private var isDevBuild: Bool { version.localizedCaseInsensitiveContains("-dev") }
    private var effectiveUpdateChannel: String { isDevBuild ? "dev" : updateChannel }
    private var githubURL: URL { URL(string: "https://github.com/mondary/Macos_PKarchives")! }
    private var issuesURL: URL { URL(string: "https://github.com/mondary/Macos_PKarchives/issues")! }
    private var githubProfileURL: URL { URL(string: "https://github.com/mondary")! }
    private var kofiURL: URL { URL(string: "https://ko-fi.com/pouark")! }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading) { Text("PKarchives").font(.headline); Text("Desktop archive / Google Drive").font(.caption).foregroundStyle(.secondary) }
                }.padding(.top, 22).padding(.bottom, 8)
                TextField(text("search"), text: $query).textFieldStyle(.roundedBorder)
                ForEach(filtered, id: \.0) { item in
                    Button { navigation.section = item.0 } label: {
                        HStack(spacing: 9) {
                            Image(systemName: item.1).foregroundStyle(sectionIconTint(item.0) ?? (navigation.section == item.0 ? Color.accentColor : Color.secondary)).frame(width: 18)
                            Text(text(item.0)).foregroundStyle(navigation.section == item.0 ? Color.accentColor : Color.primary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                            .background(navigation.section == item.0 ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).accessibilityLabel(text(item.0))
                }
                if !query.isEmpty && filtered.isEmpty {
                    Text(text("search.none")).font(.caption).foregroundStyle(.tertiary).padding(.horizontal, 8)
                }
                Spacer()
                HStack(spacing: 8) { ForEach(ArchiveLanguage.allCases, id: \.rawValue) { lang in
                    Button(lang.flag) { language = lang.rawValue }.buttonStyle(.plain).opacity(language == lang.rawValue ? 1 : 0.55).help(lang.name)
                } }
                HStack(spacing: 5) {
                    Text("PKarchives  \(version)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let available = updater.availableUpdateVersion {
                        Button { updater.checkForUpdates() } label: {
                            Label(available, systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .help(String(format: text("update.install"), available))
                    }
                }
                .padding(.bottom, 14)
            }.padding(.horizontal, 16).frame(width: 230).background(.regularMaterial)
            Divider()
            Group {
                switch navigation.section {
                case "library": projectLibrary
                case "support": supportView
                case "credits": creditsView
                case "about": aboutView
                default: archiveSettings
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Button { delegate.showWindow() } label: {
                    Label(text("back.archive"), systemImage: "arrow.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .padding(.top, 12)
                .padding(.trailing, 18)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { updater.refreshAvailableVersions() }
    }

    private var archiveSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSectionHeader(title: text("archive"), subtitle: text("settings.subtitle"), icon: "archivebox")
                GroupBox(text("googleDrive")) {
                    VStack(alignment: .leading, spacing: 14) {
                        labeled(text("destination"), value: $folder)
                        labeled(text("source"), value: $desktop)
                        labeled(text("remote"), value: $remote)
                        HStack { Spacer(); Button(text("save")) {
                            delegate.saveSettings(folderId: folder, desktop: desktop, remote: remote, permanent: (loadEnv("PKARCHIVES_DELETE_MODE") ?? "trash") == "delete")
                            delegate.sendDest(); delegate.refreshItems(mode: "files")
                        }.keyboardShortcut(.defaultAction) }
                    }.padding(8)
                }
            }.padding(28).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var projectLibrary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSectionHeader(title: text("library.title"), subtitle: text("library.subtitle"), icon: "square.grid.2x2")
                featuredCard(featuredProject)
                Text(text("library.more")).font(.system(size: 18, weight: .bold, design: .rounded))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(otherProjects) { projectCard($0) }
                }
                Link(destination: githubProfileURL) { Label(text("library.viewAll"), systemImage: "arrow.up.right.square") }
                    .buttonStyle(.borderedProminent).padding(.top, 6)
            }.padding(28).frame(maxWidth: 860).frame(maxWidth: .infinity)
        }
    }

    private var supportView: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill").font(.system(size: 36)).foregroundStyle(Color(red: 1, green: 0.37, blue: 0.36))
                    Text(text("support.title")).font(.system(size: 20, weight: .bold))
                    Text(text("support.subtitle")).font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(.top, 36).padding(.bottom, 24)
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(nsImage: kofiImage ?? NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Ko-fi")!)
                            .resizable().interpolation(.high).scaledToFit().frame(width: 28, height: 28).frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) { Text("Ko-fi").font(.system(size: 14, weight: .semibold)); Text(text("support.coffee")).font(.system(size: 12)).foregroundStyle(.secondary) }
                        Spacer()
                        Link(destination: kofiURL) {
                            Text(text("support.donate")).font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                                .padding(.horizontal, 16).padding(.vertical, 7)
                                .background(Color(red: 1, green: 0.37, blue: 0.36), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }.buttonStyle(.plain)
                    }.padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(spacing: 0) {
                        supportLink(icon: "network", title: "GitHub", subtitle: text("support.github.subtitle"), url: githubURL)
                        Divider().padding(.leading, 52)
                        supportLink(icon: "exclamationmark.bubble", title: text("support.issues.title"), subtitle: text("support.issues.subtitle"), url: issuesURL)
                        Divider().padding(.leading, 52)
                        supportLink(icon: "person.crop.circle", title: text("support.profile.title"), subtitle: text("support.profile.subtitle"), url: githubProfileURL)
                    }.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }.frame(maxWidth: 480).padding(.bottom, 32)
            }.frame(maxWidth: .infinity)
        }
    }

    private var aboutView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).padding(.top, 36).padding(.bottom, 16)
                    Text("PKarchives").font(.system(size: 24, weight: .bold))
                    Text(String(format: text("about.installed"), version))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary).padding(.top, 4)
                    Text(text("byPK")).font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 2).padding(.bottom, 32)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(text("about.greeting")).italic().font(.system(size: 13))
                        Text(text("about.pitch")).font(.system(size: 13)).foregroundStyle(.secondary)
                        Text(text("about.body")).font(.system(size: 13)).foregroundStyle(.secondary)
                        Text(text("about.care")).font(.system(size: 13)).foregroundStyle(.secondary)
                        Text(text("about.thanks")).font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 8)
                        Text("— PK").font(.system(size: 13)).foregroundStyle(.secondary)
                    }.frame(maxWidth: 480, alignment: .leading).padding(.bottom, 30)
                }.frame(maxWidth: .infinity)
            }
            Divider()
            updatesCard.frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.vertical, 12)
            Divider()
            HStack(spacing: 16) {
                Link(destination: githubURL) { Label("GitHub", systemImage: "network").font(.caption).foregroundStyle(.secondary) }
                Link(destination: issuesURL) { Label("Issues", systemImage: "exclamationmark.bubble").font(.caption).foregroundStyle(.secondary) }
                Link(destination: kofiURL) {
                    HStack(spacing: 4) {
                        if let logo = kofiImage { Image(nsImage: logo).resizable().frame(width: 12, height: 12) }
                        Text(text("footer.kofi"))
                    }.font(.caption).foregroundStyle(Color(red: 1, green: 0.37, blue: 0.36))
                }
                Spacer()
                Text(text("license")).font(.caption).foregroundStyle(.tertiary)
            }.padding(.horizontal, 24).padding(.vertical, 14)
        }
    }

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text("about.updates")).font(.headline)
            HStack(spacing: 10) {
                updateVersionColumn(title: text("about.stable"), value: updater.latestStableVersion ?? text("about.notPublished"), status: updater.versionStatus(for: "stable"))
                updateVersionColumn(title: text("about.dev"), value: updater.latestDevVersion ?? text("about.notPublished"), status: updater.versionStatus(for: "dev"))
            }
            HStack(spacing: 12) {
                Picker(text("about.updates"), selection: updateChannelBinding) {
                    Text("Stable").tag("stable")
                    Text("Dev").tag("dev")
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 190).disabled(isDevBuild)
                Spacer(minLength: 0)
                Button { updater.checkForUpdates() } label: {
                    Label(updateButtonTitle, systemImage: updater.availableUpdateVersion == nil ? "arrow.triangle.2.circlepath" : "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(updater.installingUpdate)
            }
            Text(text(effectiveUpdateChannel == "dev" ? "about.channel.dev" : "about.channel.stable"))
                .font(.caption).foregroundStyle(.secondary)
            if updater.installingUpdate {
                Label(text("update.installing"), systemImage: "arrow.down.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = updater.updateError {
                Text(String(format: text("update.failed"), error)).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(16).background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.025)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .alert(text("update.offer.title"), isPresented: updateOfferPresented) {
            Button(text("about.check")) { updater.performUpdateInstall() }
            Button(text("update.cancel"), role: .cancel) { updater.cancelUpdateOffer() }
        } message: {
            if let offer = updater.updateOffer {
                Text(String(format: text("update.offer.message"), offer.version, offer.channel))
            }
        }
    }

    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            creditGroup(title: text("credits.components")) {
                creditRow(symbol: "arrow.triangle.2.circlepath", tint: Color(red: 0.20, green: 0.62, blue: 0.43), name: "rclone", detail: text("about.credit.rclone"), url: "https://rclone.org/")
                creditRow(symbol: "sparkles", tint: Color(red: 0.48, green: 0.38, blue: 0.86), name: "Sparkle", detail: text("about.credit.sparkle"), url: "https://sparkle-project.org/")
                creditRow(symbol: "terminal", tint: Color(red: 0.88, green: 0.48, blue: 0.20), name: "Bubble Tea · Bubbles · Lip Gloss", detail: text("about.credit.charm"), url: "https://github.com/charmbracelet")
                creditRow(symbol: "externaldrive.connected.to.line.below", tint: Color(red: 0.18, green: 0.58, blue: 0.72), name: "FUSE-T", detail: text("about.credit.fuse"), url: "https://github.com/macos-fuse-t/fuse-t", secondaryName: "macFUSE", secondaryURL: "https://github.com/macfuse/macfuse")
            }
            creditGroup(title: text("credits.inspiration")) {
                creditRow(symbol: "rectangle.split.2x1", tint: Color.secondary, name: "Riptide", detail: text("about.credit.riptide"), url: "https://www.reddit.com/r/tui/comments/1usjmvd/riptide_a_polished_terminal_speed_test_live/")
            }
            Text(text("credits.footer")).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private func creditGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(.secondary)
            VStack(spacing: 0, content: content)
        }
    }

    private func creditRow(symbol: String, tint: Color, name: String, detail: String, url: String, secondaryName: String? = nil, secondaryURL: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Link(name, destination: URL(string: url)!).font(.system(size: 13, weight: .semibold))
                    if let secondaryName, let secondaryURL {
                        Link(secondaryName, destination: URL(string: secondaryURL)!).font(.system(size: 13, weight: .semibold))
                    }
                }
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1) }
    }

    private func sectionIconTint(_ section: String) -> Color? {
        switch section {
        case "support": Color(red: 1, green: 0.37, blue: 0.36)
        case "about": .accentColor
        default: nil
        }
    }

    private var creditsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSectionHeader(title: text("credits"), subtitle: text("about.credits.intro"), icon: "text.book.closed")
                creditsCard
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
    }

    private var updateChannelBinding: Binding<String> {
        Binding(get: { effectiveUpdateChannel }, set: { newValue in
            guard !isDevBuild else { return }
            updateChannel = newValue
            NotificationCenter.default.post(name: .pkUpdateChannelDidChange, object: nil)
        })
    }

    private var updateButtonTitle: String {
        guard let update = updater.availableUpdateVersion else { return text("about.check") }
        return String(format: text("update.install"), update)
    }

    private var updateOfferPresented: Binding<Bool> {
        Binding(get: { updater.updateOffer != nil }, set: { if !$0 { updater.cancelUpdateOffer() } })
    }

    private func updateVersionColumn(title: String, value: String, status: ChannelVersionStatus) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.system(size: 14, weight: .semibold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.75).help(value)
            Label(text("update.status.\(status.rawValue)"), systemImage: status.symbol)
                .font(.system(size: 10, weight: .medium)).foregroundStyle(status.color).lineLimit(1).minimumScaleFactor(0.8)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var kofiImage: NSImage? { Bundle.main.url(forResource: "kofi-logo", withExtension: "png").flatMap(NSImage.init(contentsOf:)) }

    private func supportLink(icon: String, title: String, subtitle: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 16).padding(.vertical, 10).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func assetImage(_ name: String, directory: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: directory) else { return nil }
        return NSImage(contentsOf: url)
    }

    private func featuredCard(_ project: ArchiveProject) -> some View {
        Link(destination: project.url) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        projectIcon(project).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.title).font(.system(size: 24, weight: .bold, design: .rounded))
                            Text(text(project.kindKey)).font(.system(size: 10, weight: .bold)).foregroundStyle(project.tint)
                        }
                    }
                    Text(text(project.descriptionKey)).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(3)
                    Label(text("library.star"), systemImage: "star.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7).background(Color.accentColor, in: Capsule())
                }.padding(22).frame(maxWidth: 340, alignment: .topLeading)
                if let shotName = project.screenshot, let shot = assetImage(shotName, directory: "ProjectScreenshots") {
                    GeometryReader { geo in Image(nsImage: shot).resizable().interpolation(.high).scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .leading) { LinearGradient(colors: [Color(nsColor: .controlBackgroundColor), .clear], startPoint: .leading, endPoint: .trailing).frame(width: 60) }
                }
            }.frame(height: 210).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func projectCard(_ project: ArchiveProject) -> some View {
        Link(destination: project.url) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let shotName = project.screenshot, let shot = assetImage(shotName, directory: "ProjectScreenshots") {
                        Image(nsImage: shot).resizable().interpolation(.high).scaledToFill().frame(height: 150).clipped()
                    } else {
                        ZStack {
                            LinearGradient(colors: [project.tint.opacity(0.75), project.tint.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            projectIcon(project).frame(width: 74, height: 74).shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                        }.frame(height: 150)
                    }
                }.frame(maxWidth: .infinity).clipped().overlay(alignment: .topLeading) {
                    Text(text(project.kindKey)).font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial, in: Capsule()).padding(10)
                }
                HStack(alignment: .top, spacing: 10) {
                    projectIcon(project).frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(project.title).font(.system(size: 14, weight: .semibold))
                        Text(text(project.descriptionKey)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                }.padding(14)
            }.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func projectIcon(_ project: ArchiveProject) -> some View {
        if let image = assetImage(project.iconAsset, directory: "ProjectIcons") {
            Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
        } else {
            Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
        }
    }

    private func labeled(_ title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.caption).foregroundStyle(.secondary); TextField(title, text: value).textFieldStyle(.roundedBorder) }
    }
}

final class ArchivePreferencesNavigation: ObservableObject {
    @Published var section = "archive"
}

private struct ArchiveProject: Identifiable {
    let id: String
    let title: String
    let kindKey: String
    let descriptionKey: String
    let iconAsset: String
    let screenshot: String?
    let tint: Color
    var url: URL { URL(string: "https://github.com/mondary/\(id)")! }

    static let catalog = [
        ArchiveProject(id: "PKmonitor", title: "PKMonitor", kindKey: "kind.macos", descriptionKey: "desc.PKmonitor", iconAsset: "PKmonitor", screenshot: "PKmonitor", tint: Color(red: 0.055, green: 0.647, blue: 0.914)),
        ArchiveProject(id: "PKwindowsManagement", title: "PKwindowsManagement", kindKey: "kind.macos", descriptionKey: "desc.PKwindowsManagement", iconAsset: "PKwindowsManagement", screenshot: nil, tint: Color(red: 0.976, green: 0.451, blue: 0.086)),
        ArchiveProject(id: "PKbrain", title: "PKbrain", kindKey: "kind.macos", descriptionKey: "desc.PKbrain", iconAsset: "PKbrain", screenshot: nil, tint: Color(red: 0.388, green: 0.400, blue: 0.945)),
        ArchiveProject(id: "monocode", title: "MonoCode PK", kindKey: "kind.macos", descriptionKey: "desc.MonoCodePK", iconAsset: "MonoCodePK", screenshot: nil, tint: Color(red: 0.133, green: 0.827, blue: 0.933)),
        ArchiveProject(id: "media-downloader", title: "PKMediaDownloader", kindKey: "kind.macos", descriptionKey: "desc.PKMediaDownloader", iconAsset: "PKMediaDownloader", screenshot: nil, tint: Color(red: 0.957, green: 0.259, blue: 0.369)),
        ArchiveProject(id: "Macos_PKarchives", title: "PKarchives", kindKey: "kind.macos", descriptionKey: "desc.PKarchives", iconAsset: "PKarchives", screenshot: "PKarchives", tint: Color(red: 0.545, green: 0.361, blue: 0.965)),
        ArchiveProject(id: "Macos_PKpowerlines", title: "PKpowerlines", kindKey: "kind.macos", descriptionKey: "desc.PKpowerlines", iconAsset: "PKpowerlines", screenshot: "PKpowerlines", tint: Color(red: 0.063, green: 0.725, blue: 0.506)),
        ArchiveProject(id: "PKmac-cleanup", title: "LaunchPad", kindKey: "kind.macos", descriptionKey: "desc.LaunchPad", iconAsset: "PKmac-cleanup", screenshot: nil, tint: Color(red: 0.925, green: 0.282, blue: 0.600)),
        ArchiveProject(id: "Chrome_SimpleGMAIL", title: "PKMail", kindKey: "kind.cross", descriptionKey: "desc.PKMail", iconAsset: "PKMail", screenshot: nil, tint: Color(red: 0.918, green: 0.263, blue: 0.208)),
        ArchiveProject(id: "Chrome_PKshortcuts", title: "PK Chrome Shortcuts", kindKey: "kind.chrome", descriptionKey: "desc.PKChromeShortcuts", iconAsset: "PKshortcuts", screenshot: nil, tint: Color(red: 0.961, green: 0.620, blue: 0.043))
    ]
}

private struct SettingsSectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20, weight: .medium)).foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42).background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding(.bottom, 6)
    }
}

extension Notification.Name {
    static let pkUpdateChannelDidChange = Notification.Name("PKUpdateChannelDidChange")
}

private final class ArchiveChannelFeedProvider: NSObject, SPUUpdaterDelegate {
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let devBuild = version.localizedCaseInsensitiveContains("-dev")
        let devChannel = devBuild || UserDefaults.standard.string(forKey: "updateChannel") == "dev"
        let address = devChannel
            ? "https://raw.githubusercontent.com/mondary/Macos_PKarchives/main/appcast-dev.xml"
            : "https://raw.githubusercontent.com/mondary/Macos_PKarchives/main/appcast.xml"
        guard var components = URLComponents(string: address) else { return address }
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "_pk_refresh", value: UUID().uuidString)]
        return components.url?.absoluteString ?? address
    }
}

enum ChannelVersionStatus {
    case updateAvailable, upToDate, installedAhead, otherChannel, unavailable
    var rawValue: String {
        switch self {
        case .updateAvailable: "available"
        case .upToDate: "current"
        case .installedAhead: "ahead"
        case .otherChannel: "other"
        case .unavailable: "unavailable"
        }
    }
    var symbol: String {
        switch self {
        case .updateAvailable: "arrow.down.circle.fill"
        case .upToDate: "checkmark.circle.fill"
        case .installedAhead: "arrow.up.circle.fill"
        case .otherChannel: "circle.dashed"
        case .unavailable: "questionmark.circle"
        }
    }
    var color: Color {
        switch self {
        case .updateAvailable: .accentColor
        case .upToDate: .green
        case .installedAhead: .orange
        case .otherChannel: .secondary
        case .unavailable: .secondary
        }
    }
}

private struct ArchiveAppcastInfo {
    let shortVersion: String
    let buildVersion: String
    let enclosure: URL?
    let signature: String?
}

struct ArchiveUpdateOffer {
    let version: String
    let channel: String
    let url: URL
    let signature: String
}

@MainActor
final class ArchiveUpdaterManager: NSObject, ObservableObject {
    static let shared = ArchiveUpdaterManager()
    static let stableFeedURL = "https://raw.githubusercontent.com/mondary/Macos_PKarchives/main/appcast.xml"
    static let devFeedURL = "https://raw.githubusercontent.com/mondary/Macos_PKarchives/main/appcast-dev.xml"

    let controller: SPUStandardUpdaterController
    @Published private(set) var latestStableVersion: String?
    @Published private(set) var latestDevVersion: String?
    @Published private(set) var availableUpdateVersion: String?
    @Published private(set) var updateOffer: ArchiveUpdateOffer?
    @Published private(set) var installingUpdate = false
    @Published private(set) var updateError: String?
    private let feedProvider = ArchiveChannelFeedProvider()
    private var channelObserver: NSObjectProtocol?
    private var versionRefreshTimer: Timer?
    private var stableInfo: ArchiveAppcastInfo?
    private var devInfo: ArchiveAppcastInfo?
    private var started = false

    private var selectedChannel: String {
        let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if installed.localizedCaseInsensitiveContains("-dev") { return "dev" }
        return UserDefaults.standard.string(forKey: "updateChannel") ?? "stable"
    }

    private override init() {
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: feedProvider, userDriverDelegate: nil)
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if version.localizedCaseInsensitiveContains("-dev") {
            UserDefaults.standard.set("dev", forKey: "updateChannel")
        }
        applyChannelPreference()
        channelObserver = NotificationCenter.default.addObserver(forName: .pkUpdateChannelDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.applyChannelPreference(); self?.refreshAvailableVersions() }
        }
        controller.startUpdater()
        refreshAvailableVersions()
        versionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAvailableVersions() }
        }
    }

    private func applyChannelPreference() {
        let devBuild = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "").localizedCaseInsensitiveContains("-dev")
        controller.updater.automaticallyDownloadsUpdates = devBuild || selectedChannel == "dev"
    }

    func refreshAvailableVersions() {
        Task {
            async let stable = Self.latestInfo(at: Self.stableFeedURL)
            async let dev = Self.latestInfo(at: Self.devFeedURL)
            let results = await (stable, dev)
            stableInfo = results.0
            devInfo = results.1
            latestStableVersion = results.0?.shortVersion
            latestDevVersion = results.1?.shortVersion
            refreshUpdateAvailability()
        }
    }

    func versionStatus(for channel: String) -> ChannelVersionStatus {
        let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let installedChannel = installedVersion.localizedCaseInsensitiveContains("-dev") ? "dev" : "stable"
        guard installedChannel == channel else { return .otherChannel }
        guard let info = channel == "dev" ? devInfo : stableInfo,
              let installedBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              let order = compareBuildNumbers(info.buildVersion, installedBuild) else { return .unavailable }
        switch order {
        case .orderedDescending: return .updateAvailable
        case .orderedSame: return .upToDate
        case .orderedAscending: return .installedAhead
        }
    }

    private func refreshUpdateAvailability() {
        let info = selectedChannel == "dev" ? devInfo : stableInfo
        guard let info,
              let installedBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              compareBuildNumbers(info.buildVersion, installedBuild) == .orderedDescending else {
            availableUpdateVersion = nil
            return
        }
        availableUpdateVersion = info.shortVersion
    }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updateError = nil
        Task {
            let address = selectedChannel == "dev" ? Self.devFeedURL : Self.stableFeedURL
            let info = await Self.latestInfo(at: address)
            if selectedChannel == "dev" { devInfo = info; latestDevVersion = info?.shortVersion }
            else { stableInfo = info; latestStableVersion = info?.shortVersion }
            refreshUpdateAvailability()
            guard let info, let enclosure = info.enclosure, let signature = info.signature,
                  let installedBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                  let buildOrder = compareBuildNumbers(info.buildVersion, installedBuild) else {
                controller.checkForUpdates(nil)
                return
            }
            let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            guard buildOrder == .orderedDescending else {
                let message = buildOrder == .orderedAscending
                    ? "The installed build is newer than the latest published \(selectedChannel) build (\(info.shortVersion))."
                    : "PKarchives is up to date (\(installedVersion))."
                showInformation(title: "PKarchives", message: message)
                return
            }
            updateOffer = ArchiveUpdateOffer(version: info.shortVersion, channel: selectedChannel, url: enclosure, signature: signature)
        }
    }

    func cancelUpdateOffer() { updateOffer = nil }

    func performUpdateInstall() {
        guard let offer = updateOffer else { return }
        updateOffer = nil
        installingUpdate = true
        updateError = nil
        Task {
            do {
                try await installBuild(from: offer.url, expectedVersion: offer.version, signature: offer.signature)
                installingUpdate = false
                NSApp.terminate(nil)
            } catch {
                installingUpdate = false
                updateError = error.localizedDescription
            }
        }
    }

    private func installBuild(from url: URL, expectedVersion: String, signature: String) async throws {
        let bundleURL = Bundle.main.bundleURL
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("PKarchives-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else {
            throw NSError(domain: "PKarchives.Update", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not download the update archive."])
        }
        guard let signatureData = Data(base64Encoded: signature),
              let publicKeyString = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              let publicKeyData = Data(base64Encoded: publicKeyString),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData),
              publicKey.isValidSignature(signatureData, for: data) else {
            throw NSError(domain: "PKarchives.Update", code: 4, userInfo: [NSLocalizedDescriptionKey: "The update signature is invalid."])
        }
        let zip = work.appendingPathComponent("update.zip")
        try data.write(to: zip)
        try await Task.detached(priority: .userInitiated) {
            try runArchiveProcess("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])
        }.value
        let currentBundleIdentifier = Bundle.main.bundleIdentifier
        let candidates = try FileManager.default.contentsOfDirectory(at: work, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let extracted = candidates.first(where: { candidate in
            guard let info = NSDictionary(contentsOf: candidate.appendingPathComponent("Contents/Info.plist")),
                  let extractedVersion = info["CFBundleShortVersionString"] as? String,
                  let extractedBundleIdentifier = info["CFBundleIdentifier"] as? String else { return false }
            return extractedVersion == expectedVersion && extractedBundleIdentifier == currentBundleIdentifier
        }) else {
            throw NSError(domain: "PKarchives.Update", code: 2, userInfo: [NSLocalizedDescriptionKey: "The downloaded app version did not match the appcast."])
        }
        let stagedApp = bundleURL.deletingLastPathComponent().appendingPathComponent(".PKarchives-update-\(UUID().uuidString).app")
        try FileManager.default.copyItem(at: extracted, to: stagedApp)
        let scriptURL = work.appendingPathComponent("install.sh")
        let target = Self.shellQuote(bundleURL.path)
        let staged = Self.shellQuote(stagedApp.path)
        let backup = Self.shellQuote(bundleURL.deletingLastPathComponent().appendingPathComponent(".PKarchives-backup-\(UUID().uuidString).app").path)
        let cleanup = Self.shellQuote(work.path)
        try "#!/bin/bash\nsleep 2\n/usr/bin/mv \(target) \(backup) || exit 1\nif /usr/bin/mv \(staged) \(target); then\n  /usr/bin/open \(target)\n  /bin/rm -rf \(backup) \(cleanup)\nelse\n  /usr/bin/mv \(backup) \(target)\n  exit 1\nfi\n".write(to: scriptURL, atomically: true, encoding: .utf8)
        let installer = Process()
        installer.executableURL = URL(fileURLWithPath: "/bin/bash")
        installer.arguments = [scriptURL.path]
        installer.qualityOfService = .userInitiated
        try installer.run()
    }

    private static func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private static func freshFeedURL(_ address: String) -> URL? {
        guard var components = URLComponents(string: address) else { return nil }
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "_pk_refresh", value: UUID().uuidString)]
        return components.url
    }

    private static func latestInfo(at address: String) async -> ArchiveAppcastInfo? {
        guard let url = freshFeedURL(address) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let parser = ArchiveAppcastParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        return xml.parse() ? parser.info : nil
    }
}

private func runArchiveProcess(_ path: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "PKarchives.Update", code: 3, userInfo: [NSLocalizedDescriptionKey: "Update extraction failed (\(process.terminationStatus))."])
    }
}

private func compareBuildNumbers(_ lhs: String, _ rhs: String) -> ComparisonResult? {
    func components(_ value: String) -> [UInt64]? {
        let parts = value.split(separator: ".")
        guard !parts.isEmpty else { return nil }
        let numbers = parts.compactMap { UInt64($0) }
        return numbers.count == parts.count ? numbers : nil
    }
    guard let left = components(lhs), let right = components(rhs) else { return nil }
    for index in 0..<max(left.count, right.count) {
        let a = index < left.count ? left[index] : 0
        let b = index < right.count ? right[index] : 0
        if a != b { return a < b ? .orderedAscending : .orderedDescending }
    }
    return .orderedSame
}

@MainActor
private func showInformation(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

private final class ArchiveAppcastParser: NSObject, XMLParserDelegate {
    private var inShortVersion = false
    private var inVersion = false
    private var current = ""
    private var shortVersion: String?
    private var buildVersion: String?
    private var enclosure: URL?
    private var signature: String?
    var info: ArchiveAppcastInfo? {
        guard let shortVersion else { return nil }
        return ArchiveAppcastInfo(shortVersion: shortVersion, buildVersion: buildVersion ?? shortVersion, enclosure: enclosure, signature: signature)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = qName ?? elementName
        if name == "sparkle:shortVersionString" { inShortVersion = true; current = "" }
        else if name == "sparkle:version" { inVersion = true; current = "" }
        else if name == "enclosure", let address = attributeDict["url"] {
            enclosure = URL(string: address)
            signature = attributeDict["sparkle:edSignature"] ?? attributeDict["edSignature"]
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inShortVersion || inVersion { current += string }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = qName ?? elementName
        if name == "sparkle:shortVersionString" { shortVersion = current.trimmingCharacters(in: .whitespacesAndNewlines); inShortVersion = false }
        else if name == "sparkle:version" { buildVersion = current.trimmingCharacters(in: .whitespacesAndNewlines); inVersion = false }
    }
}

// MARK: - App delegate + pont WebView

class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var statusItem: NSStatusItem?
    var statusMenu: NSMenu?
    var window: NSWindow?
    let preferencesNavigation = ArchivePreferencesNavigation()
    private var preferencesHost: NSHostingView<ArchivePreferencesView>?
    var webView: WKWebView?

    // état du run
    var process: Process?
    var timer: Timer?
    var isRunning = false
    var selectedMode = "all"
    var lastTotal = 0
    var deletedCount = 0
    var uploadedBytes: Int64 = 0
    var eventOffset = 0
    var sizeByName: [String: Int64] = [:]
    var currentItems: [DeskItem] = []
    // État du montage Drive — source unique pour l'interface ("" inconnu, mounting, mounted, unmounted, failed)
    var mountStatus = ""
    // Sparkle : détection automatique des mises à jour (appcast GitHub)
    var updaterController: SPUStandardUpdaterController?


    func applicationDidFinishLaunching(_ notification: Notification) {
        setupUpdater()
        // Menu attaché nativement (comme PKwindowsManagement) : rendu système fiable, images d'items incluses
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "📦"
        }
        statusItem = item
        NSApp.applicationIconImage = NSImage(named: NSImage.applicationIconName)
        let menu = NSMenu()
        let versionString = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "?"
        let versionItem = NSMenuItem(title: "Version " + versionString, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        menu.addItem(makeMenuItem("Ouvrir PKarchives", action: #selector(showWindow), symbol: "archivebox"))
        menu.addItem(makeMenuItem("Réglages…", action: #selector(openPreferences), symbol: "gearshape", key: ","))
        menu.addItem(makeMenuItem("Archiver (fichiers)", action: #selector(quickFiles), symbol: "doc"))
        menu.addItem(makeMenuItem("Archiver (tout)", action: #selector(quickAll), symbol: "archivebox.fill"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem("Ouvrir Google Drive", action: #selector(openDrive), symbol: "externaldrive"))
        // Ko-fi : item standard avec image (rendu correct via l'attachement natif du menu)
        let kofiItem = NSMenuItem(title: "Soutenir sur Ko-fi", action: #selector(openKofi), keyEquivalent: "")
        kofiItem.target = self
        if let data = Data(base64Encoded: kofiLogoBase64, options: .ignoreUnknownCharacters),
           let src = NSImage(data: data),
           let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) {
            rep.size = NSSize(width: 16, height: 16)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            src.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16), from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            let kofi = NSImage()
            kofi.addRepresentation(rep)
            kofi.size = NSSize(width: 16, height: 16)
            kofi.isTemplate = false
            kofiItem.image = kofi
        }
        menu.addItem(kofiItem)
        menu.addItem(makeMenuItem("Rechercher les mises à jour…", action: #selector(checkForUpdates), symbol: "arrow.down.circle"))
        menu.addItem(makeMenuItem("À propos de PKarchives", action: #selector(openAbout), symbol: "info.circle"))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem("Quitter PKarchives", action: #selector(quitApp), symbol: "power", key: "q"))
        statusMenu = menu
        statusItem?.menu = menu
        showWindow()

        // Montage automatique du Drive au démarrage (désactivable : PKARCHIVES_AUTO_MOUNT=0)
        if (loadEnv("PKARCHIVES_AUTO_MOUNT") ?? "1") != "0" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.mountDrive()
            }
        }

        // Test/e2e : PKARCHIVES_AUTOSTART=files|all lance l'archivage au démarrage
        if let auto = loadEnv("PKARCHIVES_AUTOSTART"), !auto.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.startArchive(mode: auto)
            }
        }
    }
    @objc func checkForUpdates() {
        ArchiveUpdaterManager.shared.checkForUpdates()
    }
    private func makeMenuItem(_ title: String, action: Selector, symbol: String, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            item.image = image
        }
        return item
    }
    @objc func openPreferences() {
        createMainWindowIfNeeded()
        if preferencesHost == nil {
            preferencesHost = NSHostingView(rootView: ArchivePreferencesView(delegate: self, navigation: preferencesNavigation))
        }
        window?.title = "PKarchives — Réglages"
        window?.contentView = preferencesHost
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func openAbout() {
        preferencesNavigation.section = "about"
        openPreferences()
    }
    @objc func openKofi() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/pouark")!)
    }

    private func setupUpdater() {
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else { return } // désactivé hors release
        ArchiveUpdaterManager.shared.start()
        updaterController = ArchiveUpdaterManager.shared.controller
    }

    private func createMainWindowIfNeeded() {
        guard window == nil else { return }
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
        window = w
        webView = wv
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
    }

    @objc func showWindow() {
        createMainWindowIfNeeded()
        if let webView, window?.contentView !== webView {
            window?.contentView = webView
        }
        window?.title = "PKarchives"
        guard let window else {
            NSLog("PKarchives: main window failed to initialize")
            return
        }
        window.makeKeyAndOrderFront(nil)
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
        case "openUrl":
            if let u = URL(string: body["url"] as? String ?? ""), u.scheme == "https" { NSWorkspace.shared.open(u) }
        case "openFinder":
            openFinder()
        case "mount":
            mountDrive()
        case "openVolume":
            NSWorkspace.shared.open(URL(fileURLWithPath: mountPath()))
        case "chooseDesktop":
            chooseDesktop()
        case "rescan":
            refreshItems(mode: body["mode"] as? String ?? "files")
        case "settingsReq":
            sendSettings()
        case "openPreferences":
            openPreferences()
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
        refreshItems(mode: selectedMode)
        sendMountStateIfKnown()
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
        case "fileurl":
            let fileUrl = parts.count > 2 ? parts[2] : ""
            sendEV(["type": "fileUrl", "name": name, "url": fileUrl])
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

    // MARK: montage Drive — un seul état, une seule source de vérité

    func sendMountState() {
        sendEV(["type": "mountState",
                "state": mountStatus.isEmpty ? "unmounted" : mountStatus,
                "path": shortPath(mountPath())])
    }

    func sendMountStateIfKnown() {
        if !mountStatus.isEmpty { sendMountState(); return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let mounted = isMounted(at: mountPath())
            DispatchQueue.main.async {
                if self?.mountStatus.isEmpty == true {
                    self?.mountStatus = mounted ? "mounted" : "unmounted"
                }
                self?.sendMountState()
            }
        }
    }

    func mountDrive() {
        let linkName = mountLinkName()
        let remote = (loadEnv("PKARCHIVES_RCLONE_REMOTE") ?? "gdrive").trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard let folderID = loadEnv("PKARCHIVES_DRIVE_FOLDER_ID"), !folderID.isEmpty else {
            mountStatus = "failed"
            sendMountState()
            sendEV(["type": "log", "line": "⚠️ Drive Folder ID absent, montage ignoré", "cls": "warn"])
            return
        }
        // ponytail: montage hors du dossier Bureau (rm -rf du Bureau ne doit jamais traverser vers le Drive)
        let mntPath = mountPath()
        mountStatus = "mounting"
        sendMountState()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            func finish(_ state: String) {
                DispatchQueue.main.async {
                    self?.mountStatus = state
                    self?.sendMountState()
                }
            }
            let fm = FileManager.default
            if isMounted(at: mntPath) {
                finish("mounted")
                self?.sendEV(["type": "log", "line": "📁 Google Drive déjà monté : \(shortPath(mntPath))", "cls": "ok"])
                return
            }
            if fm.fileExists(atPath: mntPath) {
                guard (try? fm.contentsOfDirectory(atPath: mntPath).isEmpty) == true else {
                    self?.sendEV(["type": "log", "line": "⚠️ \(linkName) existe déjà et n'est pas vide. Montage annulé.", "cls": "warn"])
                    finish("failed")
                    return
                }
            } else {
                try? fm.createDirectory(atPath: mntPath, withIntermediateDirectories: true)
            }
            let logPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("pkarchives-mount.log").path
            let mount = Process()
            let binary = rcloneBinary()
            if binary.contains("/") {
                mount.executableURL = URL(fileURLWithPath: binary)
                mount.arguments = ["mount", "\(remote):", mntPath,
                                   "--drive-root-folder-id", folderID,
                                   "--daemon", "--daemon-wait", "10s",
                                   "--fast-list",
                                   "--vfs-cache-mode", "minimal", "--volname", linkName,
                                   "--log-file", logPath, "--log-level", "INFO"]
            } else {
                mount.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                mount.arguments = ["rclone", "mount", "\(remote):", mntPath,
                                   "--drive-root-folder-id", folderID,
                                   "--daemon", "--daemon-wait", "10s",
                                   "--fast-list",
                                   "--vfs-cache-mode", "minimal", "--volname", linkName,
                                   "--log-file", logPath, "--log-level", "INFO"]
            }
            do { try mount.run(); mount.waitUntilExit() } catch {
                self?.sendEV(["type": "log", "line": "⚠️ Impossible de lancer rclone mount: \(error.localizedDescription)", "cls": "warn"])
                finish("failed")
                return
            }
            if isMounted(at: mntPath) {
                finish("mounted")
                self?.sendEV(["type": "log", "line": "📁 Google Drive monté : \(shortPath(mntPath)) (volume « \(linkName) »)", "cls": "ok"])
            } else {
                try? fm.removeItem(atPath: mntPath)
                finish("failed")
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
struct PKarchivesV2App {
    private static var retainedDelegate: AppDelegate?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        application.delegate = delegate
        application.run()
    }
}
