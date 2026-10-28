// Isolated tests: all rclone remotes are aliases to temporary local directories.
// No Google credentials, no user's folders, no installed app data.
import Foundation
import AppKit

func loadEnv(_ key: String) -> String? { ProcessInfo.processInfo.environment[key] }
func rcloneBinary() -> String { ProcessInfo.processInfo.environment["PK_TEST_RCLONE"]! }
func expandedPath(_ path: String) -> String { (path as NSString).expandingTildeInPath }
func shortPath(_ path: String) -> String { path }
func mountPath() -> String { "/__pk_tests_no_mount__" }
func desktopPath() -> String { "/__pk_tests_no_archive__" }
func syncText(_ key: String) -> String { key }

struct TestFailure: Error { let message: String }

@main struct SyncEngineTests {
    static let fm = FileManager.default
    static var root: URL!
    static var checks = 0

    static func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
        checks += 1
        if !value() { throw TestFailure(message: message) }
    }
    static func write(_ text: String, _ url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
    static func read(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "<missing>" }
    static func wait(_ engine: SyncEngine, seconds: TimeInterval = 40) throws {
        let until = Date().addingTimeInterval(seconds)
        while engine.busy || !engine.queue.isEmpty {
            if until < Date() { throw TestFailure(message: "Timeout: \(engine.progressText)") }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        try expect(engine.storageError == nil, "Storage error: \(engine.storageError ?? "")")
    }
    static func waitInventory(_ engine: SyncEngine, seconds: TimeInterval = 60) throws {
        let until = Date().addingTimeInterval(seconds)
        while engine.inventoryActive {
            if until < Date() { throw TestFailure(message: "Timeout: inventory") }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        try expect(engine.storageError == nil, "Storage error: \(engine.storageError ?? "")")
    }
    static func setup(_ name: String, direction: SyncDirection = .push, binary: String? = nil) throws -> (SyncEngine, SyncPair, URL) {
        let base = root.appendingPathComponent(name)
        let disk = SyncDisk(base: base.appendingPathComponent("data"), logs: base.appendingPathComponent("logs"))
        let engine = SyncEngine(disk: disk, binary: binary, automatic: false)
        let local = base.appendingPathComponent("local")
        try fm.createDirectory(at: local, withIntermediateDirectories: true)
        var pair = SyncPair()
        pair.name = name; pair.localPath = local.path; pair.drivePath = name; pair.remoteOverride = "testdrive"
        pair.direction = direction
        try expect(engine.savePair(pair), "Save \(name): \(engine.progressText)")
        return (engine, engine.pairs[0], root.appendingPathComponent("remote/\(name)"))
    }
    static func files(_ url: URL) -> [String: Data] {
        var result = [String: Data]()
        if let en = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let file as URL in en {
                if (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    result[String(file.path.dropFirst(url.path.count))] = try? Data(contentsOf: file)
                }
            }
        }
        return result
    }
    static func main() {
        do { try runTests() }
        catch { fputs("FAIL · \(error)\n", stderr); exit(1) }
    }
    static func runTests() throws {
        root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PK_TEST_ROOT"]!)
        print("Evidence: \(root.path)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try write("[testdrive]\ntype = alias\nremote = \(root.path)/remote\n\n[folderdrive]\ntype = alias\nremote = \(root.path)/folder-root\n", root.appendingPathComponent("rclone.conf"))
        setenv("RCLONE_CONFIG", root.appendingPathComponent("rclone.conf").path, 1)

        let folderID = "1FolderExample_1234567890"
        let sharedID = try DriveFolderLink.folderID(from: "https://drive.google.com/drive/folders/\(folderID)?usp=sharing")
        let accountID = try DriveFolderLink.folderID(from: "https://drive.google.com/drive/u/2/folders/\(folderID)")
        let rawID = try DriveFolderLink.folderID(from: folderID)
        try expect(sharedID == folderID, "Shared folder URL not parsed")
        try expect(accountID == folderID, "Multi-account folder URL not parsed")
        try expect(rawID == folderID, "Raw folder ID not parsed")
        for invalid in ["gdrive", "gdrive:gdrive", "https://drive.google.com/file/d/\(folderID)/view", "https://drive.google.com.evil.example/drive/folders/\(folderID)", "http://drive.google.com/drive/folders/\(folderID)", "https://drive.google.com/drive/my-drive"] {
            var rejected = false
            do { _ = try DriveFolderLink.folderID(from: invalid) } catch { rejected = true }
            try expect(rejected, "Invalid folder link accepted: \(invalid)")
        }
        try expect(!DriveFolderLink.validID(folderID + "\n"), "Control character accepted in folder ID")

        // The default preview preference only affects newly created pairs.
        UserDefaults.standard.set(false, forKey: "sync-default-preview-only")
        try expect(!SyncPair().previewOnly, "New-pair preview preference ignored")
        UserDefaults.standard.set(true, forKey: "sync-default-preview-only")
        try expect(SyncPair().previewOnly, "Explicit preview default ignored")
        UserDefaults.standard.removeObject(forKey: "sync-default-preview-only")
        try expect(SyncPair().previewOnly, "New pairs must default to preview when no preference is set")

        let quotaMessage = "error reading source root directory: googleapi: Error 403: Quota exceeded for quota metric 'Queries', reason RATE_LIMIT_EXCEEDED, rateLimitExceeded"
        let abortedMessage = "\u{1B}[31mBisync aborted. Must run --resync to recover.\u{1B}[0m"
        let quotaDiagnosis = SyncDiagnostic.classify([quotaMessage, abortedMessage])
        try expect(quotaDiagnosis.kind == .quota && quotaDiagnosis.outcome == "rateLimited", "Generic bisync footer masked quota root cause")
        try expect(!quotaDiagnosis.summary.contains("--resync"), "Quota diagnosis recommends a merge")
        try expect(SyncDiagnostic.classify(["googleapi Error 403: storageQuotaExceeded", abortedMessage]).kind == .storage, "Full storage confused with API request quota")
        try expect(SyncDiagnostic.clean("\u{1B}[31mErreur\u{1B}[0m") == "Erreur", "ANSI colors leaked into UI")
        try expect(SyncDiagnostic.clean("[31mErreur[0m") == "Erreur", "Bare color codes leaked into UI")
        try expect(SyncDiagnostic.classify(["directory not found", abortedMessage]).kind == .notFound, "Missing folder misclassified as merge")
        try expect(SyncDiagnostic.classify(["permission denied", abortedMessage]).kind == .permission, "Permission failure misclassified as merge")
        try expect(SyncDiagnostic.classify(["invalid_grant", abortedMessage]).kind == .authentication, "Expired authorization misclassified as merge")
        try expect(SyncDiagnostic.classify(["i/o timeout", abortedMessage]).kind == .network, "Network failure misclassified as merge")
        try expect(SyncDiagnostic.classify(["Safety abort: all files were changed", abortedMessage]).kind == .safety, "Safety stop misclassified as merge")
        try expect(SyncDiagnostic.classify(["cannot find prior Path1/2 listings. Must run --resync", abortedMessage]).kind == .resync, "Actual baseline failure not recognized")

        let quotaBinary = root.appendingPathComponent("quota-rclone")
        let quotaLog = try [quotaMessage, abortedMessage].map { message -> String in
            let data = try JSONSerialization.data(withJSONObject: ["level": "error", "msg": message])
            return String(decoding: data, as: UTF8.self)
        }.joined(separator: "\n")
        try write("#!/bin/bash\ncat <<'PK_QUOTA_LOG'\n\(quotaLog)\nPK_QUOTA_LOG\nexit 9\n", quotaBinary)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: quotaBinary.path)
        let (quota, qp, _) = try setup("quota", direction: .bidirectional, binary: quotaBinary.path)
        let quotaBefore = quota.pairs[0]
        quota.syncPair(qp.id, dryRun: true)
        try wait(quota)
        try expect(quota.runs[0].outcome == "rateLimited" && quota.runs[0].diagnostic?.kind == .quota, "Quota integration still shows merge confirmation")
        try expect(quota.pairs[0] == quotaBefore, "Failed preview mutated live pair metadata")
        try expect(quota.cooldownUntil(for: qp) != nil, "Quota did not establish backoff")
        let persistedCooldown = try quota.disk.load([String: Date].self, at: quota.disk.base.appendingPathComponent("cooldowns.json"), fallback: [:])
        try expect(persistedCooldown[qp.remote] != nil, "Quota backoff not durable")
        let countBeforeReplay = quota.runs.count
        quota.replay(quota.runs[0])
        try expect(quota.runs.count == countBeforeReplay && !quota.busy, "Replay bypassed quota cooldown")
        quota.syncPair(qp.id, resync: true)
        try expect(quota.pairs[0].previewOnly, "Quota-blocked action activated real sync")
        var anotherConnection = SyncPair()
        anotherConnection.name = "other connection"
        anotherConnection.localPath = root.appendingPathComponent("another-connection-local").path
        anotherConnection.drivePath = "other"
        anotherConnection.remoteOverride = "anotherConnection"
        try fm.createDirectory(atPath: anotherConnection.localPath, withIntermediateDirectories: true)
        try expect(quota.savePair(anotherConnection), "Could not add independent connection")
        quota.syncPair(anotherConnection.id, dryRun: true)
        try wait(quota)
        try expect(quota.runs[0].pair.id == anotherConnection.id && quota.runs[0].finished != nil, "One account cooldown blocked another account")
        quota.tick(now: Date().addingTimeInterval(901))
        try expect(quota.cooldownUntil(for: qp) == nil && !quota.busy, "Quota expiry started a real initial merge")

        // Historical errors are reclassified from their raw evidence without rewriting it.
        let past = SyncDisk(base: root.appendingPathComponent("past-quota/data"), logs: root.appendingPathComponent("past-quota/logs"))
        try past.prepare()
        try past.save([qp], to: past.config)
        let pastDir = past.logs.appendingPathComponent("runs/old")
        try write(quotaLog, pastDir.appendingPathComponent("rclone.jsonl"))
        try write("original report — preserve this", pastDir.appendingPathComponent("rapport.md"))
        var old = SyncRun(pair: qp, dryRun: true, resync: true, directory: pastDir.path)
        old.outcome = "needsResync"; old.message = abortedMessage; old.finished = Date()
        try past.save([old], to: past.history)
        let migrated = SyncEngine(disk: past, automatic: false)
        try expect(migrated.runs[0].outcome == "rateLimited", "Historical quota still labelled merge required")
        try expect(migrated.runs[0].message == abortedMessage, "Historical raw message was discarded rather than separately diagnosed")
        try expect(read(pastDir.appendingPathComponent("rapport.md")) == "original report — preserve this", "Historical raw report overwritten")
        try expect(read(pastDir.appendingPathComponent("rclone.jsonl")) == quotaLog, "Historical raw log overwritten")
        let reading = migrated.readableReportURL(for: migrated.runs[0])!
        try expect(!read(reading).contains("\u{1B}") && !read(reading).contains("Must run --resync"), "Reading report exposes misleading colorized footer")

        // Local alias emulates the scoped endpoint boundary, including the excluded in-root
        // recovery namespace. No Drive account is used for these URL-destination tests.
        let (linked, linkedOriginal, _) = try setup("linked", direction: .bidirectional)
        var linkedPair = linkedOriginal
        linkedPair.remoteOverride = "folderdrive"; linkedPair.driveFolderID = folderID; linkedPair.drivePath = ""
        try expect(linked.savePair(linkedPair), "Folder link destination rejected")
        try expect(linked.pairs[0].target == "folderdrive,root_folder_id=\(folderID):", "ID was not scoped to target")
        let linkedLocal = URL(fileURLWithPath: linkedPair.localPath)
        let linkedRemote = root.appendingPathComponent("folder-root")
        // A copied Drive folder link refers to an existing folder, including an empty one.
        try fm.createDirectory(at: linkedRemote, withIntermediateDirectories: true)
        try write("initial version", linkedLocal.appendingPathComponent("a.txt"))
        try write("unchanged reference", linkedLocal.appendingPathComponent("stable.txt"))
        linked.syncPair(linkedPair.id, dryRun: true)
        try wait(linked)
        try expect(linked.runs[0].outcome == "preview", "Folder-link preview failed: \(linked.runs[0].message)")
        try expect(files(linkedRemote).isEmpty, "Folder-link preview changed remote")
        linked.syncPair(linkedPair.id, resync: true)
        try wait(linked)
        try expect(linked.pairs[0].lastOutcome == "verified", "Folder-link initial merge failed: \(linked.runs[0].message)")
        try write("updated local content", linkedLocal.appendingPathComponent("a.txt"))
        linked.syncPair(linkedPair.id)
        try wait(linked)
        try expect(linked.pairs[0].lastOutcome == "verified", "In-root recovery broke verification: \(linked.runs[0].message)")
        try expect(files(linkedRemote.appendingPathComponent(".PKarchives-recovery")).values.contains(Data("initial version".utf8)), "In-root recovery did not preserve old contents")
        try expect(!fm.fileExists(atPath: linkedLocal.appendingPathComponent(".PKarchives-recovery").path), "Recovery namespace was downloaded into local folder")

        let (engine, pair, dest) = try setup("push")
        let local = URL(fileURLWithPath: pair.localPath)
        try write("bonjour 🌍", local.appendingPathComponent("sous dossier/été.txt"))
        try write("excluded", local.appendingPathComponent("node_modules/cache.txt"))
        try write("A", local.appendingPathComponent("same.txt"))
        let before = engine.pairs[0]
        engine.syncAll()
        try wait(engine)
        try expect(engine.runs[0].outcome == "preview" && engine.pairs[0].previewOnly, "Global action promoted default dry-run mode")
        try expect(!fm.fileExists(atPath: dest.path), "Default preview-only mode wrote files")
        engine.tick(now: Date().addingTimeInterval(3601))
        try wait(engine)
        try expect(engine.runs[0].outcome == "preview" && engine.pairs[0].lastRun == nil, "Scheduler promoted preview-only mode")
        engine.syncPair(pair.id, dryRun: true)
        try wait(engine)
        try expect(engine.runs[0].outcome == "preview", "Push preview failed: \(engine.runs[0].message)")
        try expect(engine.pairs[0] == before, "Preview changed pair status")
        try expect(!fm.fileExists(atPath: dest.path), "Preview wrote destination")
        if let plan = engine.runs[0].plan {
            try expect(plan.pushNew.count == 2 && plan.pullNew.isEmpty, "Preview plan wrong: \(plan.pushNew) / \(plan.pullNew)")
        } else {
            throw TestFailure(message: "Preview produced no comparison plan")
        }
        try expect(read(engine.disk.journal).contains("Skipped"), "Readable preview contains no planned operation")
        engine.syncPair(pair.id)
        try wait(engine)
        try expect(engine.pairs[0].lastOutcome == "verified", "Push not verified: \(engine.runs[0].message)")
        try expect(read(dest.appendingPathComponent("sous dossier/été.txt")) == "bonjour 🌍", "UTF8/nested file missing")
        try expect(!fm.fileExists(atPath: dest.appendingPathComponent("node_modules/cache.txt").path), "Exclude ignored")
        try expect(read(URL(fileURLWithPath: engine.runs[0].directory).appendingPathComponent("verification.txt")).contains("= same.txt"), "Missing verification evidence")

        // Live progress parsing uses the exact bisync/rclone INFO wording (ANSI stripped upstream).
        var progress = RunProgress()
        SyncEngine.apply(message: "\u{1B}[36mPath1\u{1B}[0m    \u{1B}[35mQueue copy to\u{1B}[0m Path2 - gdrive:x/a.txt", object: "", to: &progress)
        SyncEngine.apply(message: "- Path2    Queue copy to Path1 - /Users/x/pull.txt", object: "", to: &progress)
        SyncEngine.apply(message: "- Path2    Queue delete - gdrive:x/del.txt", object: "", to: &progress)
        SyncEngine.apply(message: "- Path1    Queue delete - /Users/x/local.txt", object: "", to: &progress)
        try expect(progress.plannedPushes == 1 && progress.plannedPulls == 1, "Push/pull plans not counted")
        try expect(progress.deleteRemotePlanned == 1 && progress.deleteLocalPlanned == 1 && progress.plannedDeletes == 2, "Planned deletions not split by side")
        SyncEngine.apply(message: "- Path2    Do queued copies to Path1", object: "", to: &progress)
        SyncEngine.apply(message: "Copied (new)", object: "pull.txt", to: &progress)
        SyncEngine.apply(message: "- Path1    Do queued copies to Path2", object: "", to: &progress)
        SyncEngine.apply(message: "Copied (replaced existing)", object: "a.txt", to: &progress)
        SyncEngine.apply(message: "Deleted", object: "del.txt", to: &progress)
        try expect(progress.pullDone == 1 && progress.pushDone == 1 && progress.deleteDone == 1, "Executed operations misattributed")
        SyncEngine.apply(stats: ["transfers": 3, "totalTransfers": 7, "bytes": 1200, "totalBytes": 4800, "speed": 250.0, "eta": 15.0, "elapsedTime": 42.0, "listed": 900], to: &progress)
        try expect(progress.transfersDone == 3 && progress.transfersTotal == 7, "Transfer counters not parsed")
        try expect(progress.bytesDone == 1200 && progress.bytesTotal == 4800 && progress.eta == 15, "Volume/ETA not parsed")
        SyncEngine.apply(stats: ["eta": NSNull()], to: &progress)
        try expect(progress.eta == nil, "Null ETA not cleared")
        try expect(SyncEngine.durationText(75) == "1 min 15 s" && SyncEngine.durationText(3700) == "1 h 1 min", "Duration formatting wrong")

        // Preview comparison: per-file plan parsed from bisync, conflicts collapsed, totals coherent.
        var plan = PreviewPlan()
        var planDirection: String?
        func planLine(_ message: String, _ object: String = "") {
            SyncEngine.applyPlan(message: message, object: object, to: &plan, resyncDirection: &planDirection, oneWay: nil)
        }
        planLine("- Path1    File is new               - a.txt")
        planLine("- Path2    File is new               - distant.txt")
        planLine("- \u{1B}[36mPath1\u{1B}[0m File changed: size (larger) - b.txt")
        planLine("- Path1    File changed: time (newer) - both.txt")
        planLine("- Path2    File changed: time (newer) - both.txt")
        planLine("- Path2    File was deleted            - old.txt")
        planLine("- Path1    File was deleted            - gone.txt")
        try expect(plan.pushNew == ["a.txt"] && plan.pullNew == ["distant.txt"], "New files not split by side")
        try expect(plan.pushModified == ["b.txt", "both.txt"] && plan.pullModified == ["both.txt"], "Modified files not split by side")
        try expect(plan.deleteRemote == ["gone.txt"] && plan.deleteLocal == ["old.txt"], "Deletions attributed to the wrong side")
        plan.localFiles = 10
        plan = SyncEngine.finalizePlan(plan)
        try expect(plan.conflicts == ["both.txt"] && plan.pushModified == ["b.txt"] && plan.pullModified.isEmpty, "Both-side modification not treated as one conflict")
        try expect(plan.totalOps == 6, "Plan total double-counts a conflict: \(plan.totalOps)")
        try expect(plan.unchanged == 6, "Unchanged count wrong: \(String(describing: plan.unchanged))")
        try expect(SyncEngine.comparisonText(plan).contains("Identiques (non touchés) : 6"), "Report comparison missing unchanged count")

        // First merge (resync) lists copies under direction headers, path in the object field.
        var resyncDir: String?
        var resyncPlan = PreviewPlan()
        SyncEngine.applyPlan(message: "- Path2    Resync is copying files to - Path1", object: "", to: &resyncPlan, resyncDirection: &resyncDir, oneWay: nil)
        SyncEngine.applyPlan(message: "Skipped copy as --dry-run is set (size 29)", object: "distant.txt", to: &resyncPlan, resyncDirection: &resyncDir, oneWay: nil)
        SyncEngine.applyPlan(message: "Copying Path2 files to Path1", object: "", to: &resyncPlan, resyncDirection: &resyncDir, oneWay: nil)
        SyncEngine.applyPlan(message: "Skipped copy as --dry-run is set (size 22)", object: "note-distant.txt", to: &resyncPlan, resyncDirection: &resyncDir, oneWay: nil)
        SyncEngine.applyPlan(message: "- Path1    Resync is copying files to - Path2", object: "", to: &resyncPlan, resyncDirection: &resyncDir, oneWay: nil)
        SyncEngine.applyPlan(message: "Skipped copy as --dry-run is set (size 18)", object: "a.txt", to: &resyncPlan, resyncDirection: &resyncDir, oneWay: nil)
        SyncEngine.applyPlan(message: "Skipped set directory modification time as --dry-run is set", object: "sous-dossier", to: &resyncPlan, resyncDirection: &resyncDir, oneWay: nil)
        try expect(resyncPlan.pullNew == ["distant.txt", "note-distant.txt"], "Resync pull copies missing: \(resyncPlan.pullNew)")
        try expect(resyncPlan.pushNew == ["a.txt"], "Resync push copies wrong: \(resyncPlan.pushNew)")

        // One-way copies log "Skipped copy" without direction headers.
        var oneWayDir: String?
        var oneWayPlan = PreviewPlan()
        SyncEngine.applyPlan(message: "Skipped copy as --dry-run is set (size 1)", object: "same.txt", to: &oneWayPlan, resyncDirection: &oneWayDir, oneWay: true)
        SyncEngine.applyPlan(message: "Skipped set directory modification time as --dry-run is set", object: "sous dossier", to: &oneWayPlan, resyncDirection: &oneWayDir, oneWay: true)
        try expect(oneWayPlan.pushNew == ["same.txt"], "One-way push plan missing copies")

        // Inventory: real per-side counts with the pair's exclusions, gap and durable storage.
        try expect(SyncEngine.parseSize(#"{"count":3,"bytes":123}"#)?.bytes == 123, "size JSON not parsed")
        try expect(SyncEngine.parseSize("not json") == nil, "Garbage accepted as size output")
        try expect(SyncEngine.etaText(0) == syncText("etaSeconds"), "Zero gap must show the instant estimate")
        try expect(SyncEngine.etaText(SyncEngine.referenceThroughput * 60) == "1 min", "1-minute reference estimate wrong")
        let (gapEngine, gapPair, gapDest) = try setup("gap")
        let gapLocal = URL(fileURLWithPath: gapPair.localPath)
        try fm.createDirectory(at: gapDest, withIntermediateDirectories: true) // empty, existing remote
        try write("one", gapLocal.appendingPathComponent("one.txt"))
        try write("two", gapLocal.appendingPathComponent("node_modules/skip.txt"))
        gapEngine.refreshInventory(gapPair.id)
        try waitInventory(gapEngine)
        var gapInventory = gapEngine.inventories[gapPair.id]
        try expect(gapInventory?.localFiles == 1, "Excluded file counted locally: \(String(describing: gapInventory?.localFiles))")
        try expect(gapInventory?.remoteFiles == 0 && gapInventory?.aligned == false, "Empty remote not reported as a gap")
        let storedInventory = try gapEngine.disk.load([UUID: PairInventory].self, at: gapEngine.disk.base.appendingPathComponent("inventories.json"), fallback: [:])
        try expect(storedInventory[gapPair.id]?.localFiles == 1, "Inventory not persisted")
        gapEngine.syncPair(gapPair.id)
        try wait(gapEngine)
        try expect(gapEngine.pairs[0].lastOutcome == "verified", "Gap pair not verified: \(gapEngine.runs[0].message)")
        gapEngine.refreshInventory(gapPair.id)
        try waitInventory(gapEngine)
        gapInventory = gapEngine.inventories[gapPair.id]
        try expect(gapInventory?.remoteFiles == 1 && gapInventory?.aligned == true, "Aligned pair still shown as a gap")
        try write("late", gapLocal.appendingPathComponent("late.txt"))
        gapEngine.refreshInventory(gapPair.id)
        try waitInventory(gapEngine)
        try expect(gapEngine.inventories[gapPair.id]?.gapFiles == 1, "New local file not reported in the gap")
        // A quota refusal defers the remote count and extends the shared cooldown.
        let (quotaInv, quotaInvPair, _) = try setup("quota-inv", direction: .push, binary: quotaBinary.path)
        quotaInv.refreshInventory(quotaInvPair.id)
        try waitInventory(quotaInv)
        try expect(quotaInv.inventories[quotaInvPair.id]?.remoteDeferred == true, "Failed remote read not marked deferred")
        try expect(quotaInv.cooldownUntil(for: quotaInvPair) != nil, "Quota refusal during inventory did not extend cooldown")
        _ = gapDest

        // Same size and timestamp corruption must not be silently skipped.
        let date = try fm.attributesOfItem(atPath: dest.appendingPathComponent("same.txt").path)[.modificationDate]!
        try write("B", dest.appendingPathComponent("same.txt"))
        try fm.setAttributes([.modificationDate: date], ofItemAtPath: dest.appendingPathComponent("same.txt").path)
        engine.syncPair(pair.id)
        try wait(engine)
        try expect(read(dest.appendingPathComponent("same.txt")) == "A", "Checksum copy did not repair equal-size corruption")
        try expect(files(root.appendingPathComponent("remote/.PKarchives-recovery")).values.contains(Data("B".utf8)), "Replaced version was not retained")

        let verified = engine.pairs[0]
        let snapshot = files(dest)
        engine.syncPair(pair.id, dryRun: true)
        try wait(engine)
        try expect(engine.pairs[0] == verified && files(dest) == snapshot, "Preview invalidated verified state or modified files")

        let (symlinks, slp, _) = try setup("symlinks")
        try fm.createSymbolicLink(atPath: URL(fileURLWithPath: slp.localPath).appendingPathComponent("external-link").path,
                                 withDestinationPath: local.appendingPathComponent("same.txt").path)
        symlinks.syncPair(slp.id)
        try wait(symlinks)
        try expect(symlinks.pairs[0].lastOutcome == "unverified", "Unsupported symlink falsely declared backed up")

        let (permission, pp, pd) = try setup("permission")
        let inaccessible = URL(fileURLWithPath: pp.localPath).appendingPathComponent("unreadable.txt")
        try write("no access", inaccessible)
        try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: inaccessible.path)
        try write("keep going", URL(fileURLWithPath: pp.localPath).appendingPathComponent("readable.txt"))
        permission.syncPair(pp.id)
        try wait(permission)
        try expect(permission.pairs[0].lastOutcome == "error", "Unreadable file falsely green")
        try expect(read(pd.appendingPathComponent("readable.txt")) == "keep going", "File error stopped readable transfers")
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: inaccessible.path)
        permission.retryFailed()
        try wait(permission)
        try expect(permission.pairs[0].lastOutcome == "verified", "Permission repair retry failed")

        let (pull, pullPair, pullRemote) = try setup("pull", direction: .pull)
        try write("cloud", pullRemote.appendingPathComponent("remote.txt"))
        pull.syncPair(pullPair.id, dryRun: true)
        try wait(pull)
        try expect(files(URL(fileURLWithPath: pullPair.localPath)).isEmpty, "Pull preview wrote files")
        pull.syncPair(pullPair.id)
        try wait(pull)
        try expect(pull.pairs[0].lastOutcome == "verified", "Pull failed: \(pull.runs[0].message)")

        let (bidir, bp, bd) = try setup("bidir", direction: .bidirectional)
        let bl = URL(fileURLWithPath: bp.localPath)
        try write("mac", bl.appendingPathComponent("mac.txt"))
        try write("drive", bd.appendingPathComponent("drive.txt"))
        try write("initial mac version", bl.appendingPathComponent("shared.txt"))
        try write("initial drive version", bd.appendingPathComponent("shared.txt"))
        try fm.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: bd.appendingPathComponent("shared.txt").path)
        bidir.syncPair(bp.id) // Cannot bypass explicit initial-merge approval.
        try expect(!bidir.busy && bidir.runs.isEmpty, "First merge started without confirmation")
        bidir.syncPair(bp.id, dryRun: true)
        try wait(bidir)
        try expect(bidir.runs[0].outcome == "preview", "First bisync preview failed: \(bidir.runs[0].message)")
        try expect(bidir.pairs[0].needsResync, "Preview initialized live bisync")
        try expect(!fm.fileExists(atPath: bidir.disk.workdir(bp.id).path), "Preview wrote live state directory")
        try expect(read(bl.appendingPathComponent("drive.txt")) == "<missing>", "Bidir preview downloaded")
        bidir.syncPair(bp.id, resync: true)
        try wait(bidir)
        try expect(bidir.pairs[0].lastOutcome == "verified" && !bidir.pairs[0].needsResync, "First merge failed: \(bidir.runs[0].message)")
        try expect(read(bl.appendingPathComponent("drive.txt")) == "drive" && read(bd.appendingPathComponent("mac.txt")) == "mac", "Merge not bidirectional")
        let initialBackups = Array(files(bidir.disk.base.appendingPathComponent("recovery")).values) + Array(files(root.appendingPathComponent("remote/.PKarchives-recovery")).values)
        try expect(initialBackups.contains(Data("initial mac version".utf8)), "Initial-merge loser was not retained")

        let state = files(bidir.disk.workdir(bp.id))
        let beforePreview = bidir.pairs[0]
        try write("preview this", bl.appendingPathComponent("new.txt"))
        bidir.syncPair(bp.id, dryRun: true)
        try wait(bidir)
        try expect(bidir.runs[0].outcome == "preview", "Incremental preview failed")
        try expect(files(bidir.disk.workdir(bp.id)) == state, "Preview modified bisync baseline")
        try expect(bidir.pairs[0] == beforePreview, "Preview mutated bisync success metadata")
        try expect(!fm.fileExists(atPath: bd.appendingPathComponent("new.txt").path), "Preview uploaded file")
        bidir.syncPair(bp.id)
        try wait(bidir)
        try expect(bidir.pairs[0].lastOutcome == "verified", "Incremental bisync failed: \(bidir.runs[0].message)")

        // Conflicting edits preserve both contents; no silent winner-only success.
        try write("MAC EDIT", bl.appendingPathComponent("drive.txt"))
        try write("DRIVE EDIT", bd.appendingPathComponent("drive.txt"))
        try fm.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: bd.appendingPathComponent("drive.txt").path)
        bidir.syncPair(bp.id)
        try wait(bidir)
        try expect(bidir.pairs[0].lastOutcome == "verified", "Conflict run failed: \(bidir.runs[0].message)")
        let preserved = Array(files(bl).values) + Array(files(root.appendingPathComponent("remote/.PKarchives-recovery")).values)
        try expect(preserved.contains(Data("MAC EDIT".utf8)) && preserved.contains(Data("DRIVE EDIT".utf8)), "Conflict version lost")

        try fm.removeItem(at: bl.appendingPathComponent("mac.txt"))
        bidir.syncPair(bp.id)
        try wait(bidir)
        try expect(bidir.pairs[0].lastOutcome == "verified", "Delete propagation failed: \(bidir.runs[0].message)")
        try expect(!fm.fileExists(atPath: bd.appendingPathComponent("mac.txt").path), "Deleted file remained")
        try expect(files(root.appendingPathComponent("remote/.PKarchives-recovery")).values.contains(Data("mac".utf8)), "Deleted file not recoverable")

        // A failing pair must not stop another pair in the same queue.
        var second = SyncPair()
        second.name = "second"; second.localPath = root.appendingPathComponent("second-local").path
        second.drivePath = "second-remote"; second.direction = .push; second.remoteOverride = "testdrive"
        second.previewOnly = false
        try write("safe", URL(fileURLWithPath: second.localPath).appendingPathComponent("ok.txt"))
        try expect(engine.savePair(second), "Cannot add second pair")
        try fm.moveItem(at: local, to: local.appendingPathExtension("offline"))
        engine.syncAll()
        try wait(engine)
        try expect(engine.pairs[0].lastOutcome == "error", "Missing local not failed")
        try expect(engine.pairs[0].nextRetryAt != nil, "Missing local not retryable")
        try expect(engine.pairs[1].lastOutcome == "verified", "Error stopped subsequent pair")
        let failedRun = engine.runs.first { $0.pair.id == pair.id && $0.outcome == "error" }!
        try fm.moveItem(at: local.appendingPathExtension("offline"), to: local)
        engine.replay(failedRun)
        try wait(engine)
        try expect(engine.pairs[0].lastOutcome == "verified", "Replay did not recover")

        // A *failed* preview also preserves the prior verified state and retry policy.
        let successBeforeFailedPreview = engine.pairs[0]
        try fm.moveItem(at: local, to: local.appendingPathExtension("offline"))
        engine.syncPair(pair.id, dryRun: true)
        try wait(engine)
        try expect(engine.runs[0].outcome == "error" && engine.runs[0].dryRun, "Failed preview missing report")
        try expect(engine.pairs[0] == successBeforeFailedPreview, "Failed preview changed verified metadata")
        try fm.moveItem(at: local.appendingPathExtension("offline"), to: local)

        let (spawn, sp, _) = try setup("spawn", binary: "/__nonexistent_rclone__")
        spawn.syncPair(sp.id)
        try wait(spawn)
        try expect(spawn.pairs[0].lastOutcome == "error" && spawn.pairs[0].consecutiveFailures == 1, "Spawn failure not durable/retryable")
        try expect(SyncEngine.retryDelay(0) == 120 && SyncEngine.retryDelay(99) == 3600, "Backoff underflow or no cap")

        // Exit 0 is not proof of hash verification. Deliberately emulate a hashless backend.
        let hashlessBinary = root.appendingPathComponent("hashless-rclone")
        try write("#!/bin/bash\nif [[ $1 == check ]]; then echo '{\"level\":\"notice\",\"msg\":\"1 hashes could not be checked\"}'; fi\nexit 0\n", hashlessBinary)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hashlessBinary.path)
        let (hashless, hp, _) = try setup("hashless", binary: hashlessBinary.path)
        hashless.syncPair(hp.id)
        try wait(hashless)
        try expect(hashless.pairs[0].lastOutcome == "unverified" && hashless.pairs[0].lastRun == nil, "Hashless verification falsely green")

        // Failed content checks must not declare an apparently successful transfer verified.
        let failedCheckBinary = root.appendingPathComponent("failed-check-rclone")
        try write("#!/bin/bash\nif [[ $1 == check ]]; then echo '{\"level\":\"error\",\"msg\":\"1 differences found\"}'; exit 1; fi\nexit 0\n", failedCheckBinary)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: failedCheckBinary.path)
        let (failedCheck, fp, _) = try setup("failedcheck", binary: failedCheckBinary.path)
        failedCheck.syncPair(fp.id)
        try wait(failedCheck)
        try expect(failedCheck.pairs[0].lastOutcome == "error" && failedCheck.pairs[0].lastRun == nil, "Failed check falsely green")
        try expect(failedCheck.pairs[0].lastMessage?.contains("differences") == true, "Final error was lost at pipe EOF")

        let slowBinary = root.appendingPathComponent("slow-rclone")
        try write("#!/bin/bash\ntrap 'exit 130' INT TERM\nwhile true; do sleep 0.1; done\n", slowBinary)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: slowBinary.path)
        let (stoppable, stopPair, _) = try setup("cancel", binary: slowBinary.path)
        stoppable.syncPair(stopPair.id)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        stoppable.stopRunning()
        try wait(stoppable, seconds: 8)
        try expect(stoppable.pairs[0].lastOutcome == "cancelled" && stoppable.pairs[0].nextRetryAt == nil, "User cancellation restarted automatically")

        // A change during verification cannot be reported as a current verified snapshot.
        engine.syncPair(pair.id)
        engine.localChanged(path: local.appendingPathComponent("changed.txt").path)
        try wait(engine)
        try expect(engine.pairs[0].lastOutcome == "pending", "Concurrent local change falsely green")

        // Persisted malformed configuration must fail closed, never be silently replaced by [].
        let badDisk = SyncDisk(base: root.appendingPathComponent("bad-data"), logs: root.appendingPathComponent("bad-logs"))
        try badDisk.prepare()
        try write("not json", badDisk.config)
        let bad = SyncEngine(disk: badDisk, automatic: false)
        try expect(bad.storageError != nil && read(badDisk.config) == "not json", "Corrupt config silently discarded")

        engine.pauseForHours(1)
        let runCount = engine.runs.count
        engine.syncPair(pair.id, dryRun: true)
        try expect(!engine.busy && !engine.queue.isEmpty, "Pause started work")
        engine.tick(now: Date().addingTimeInterval(3601))
        try wait(engine)
        try expect(!engine.isPaused && engine.runs.prefix(engine.runs.count - runCount).contains(where: { $0.dryRun && $0.outcome == "preview" }), "Timed pause did not resume")

        let lock = SyncEngine(disk: engine.disk, automatic: false)
        try expect(lock.storageError != nil, "Second instance acquired the same data")
        var overlapping = second
        overlapping.id = UUID(); overlapping.localPath += "/child"
        try fm.createDirectory(atPath: overlapping.localPath, withIntermediateDirectories: true)
        try expect(engine.validationError(overlapping) != nil, "Overlapping pair accepted")
        var unsafe = second
        unsafe.drivePath = "../escape"
        try expect(engine.validationError(unsafe) != nil, "Remote traversal accepted")

        // Reload interrupted durable history, preserving a failed dry-run's previous verification.
        let interruptedDisk = SyncDisk(base: root.appendingPathComponent("interrupted-data"), logs: root.appendingPathComponent("interrupted-logs"))
        try interruptedDisk.prepare()
        var interruptedPair = pair
        interruptedPair.lastOutcome = "running"
        try interruptedDisk.save([interruptedPair], to: interruptedDisk.config)
        let rd = interruptedDisk.logs.appendingPathComponent("runs/test")
        try fm.createDirectory(at: rd, withIntermediateDirectories: true)
        let interrupted = SyncRun(pair: interruptedPair, dryRun: false, resync: false, directory: rd.path)
        try interruptedDisk.save([interrupted], to: interruptedDisk.history)
        let recovered = SyncEngine(disk: interruptedDisk, automatic: false)
        try expect(recovered.runs[0].outcome == "interrupted" && recovered.pairs[0].lastOutcome == "error", "Crash recovery falsely green")

        let orphanDisk = SyncDisk(base: root.appendingPathComponent("orphan-data"), logs: root.appendingPathComponent("orphan-logs"))
        try orphanDisk.prepare()
        var orphan = interrupted
        orphan.processID = getpid() // Safe live process: this test itself. Must never be killed.
        try orphanDisk.save([orphan], to: orphanDisk.history)
        let orphanEngine = SyncEngine(disk: orphanDisk, automatic: false)
        try expect(orphanEngine.storageError != nil, "A live orphan process was ignored")

        // Actual FSEvents, on an isolated local pair. No clock-based scans are involved.
        let watcherBase = root.appendingPathComponent("watcher")
        let watcher = SyncEngine(disk: SyncDisk(base: watcherBase.appendingPathComponent("data"), logs: watcherBase.appendingPathComponent("logs")), automatic: true)
        var watched = SyncPair()
        watched.name = "watched"; watched.localPath = watcherBase.appendingPathComponent("local").path
        watched.drivePath = "watcher"; watched.remoteOverride = "testdrive"; watched.direction = .push
        try write("before", URL(fileURLWithPath: watched.localPath).appendingPathComponent("file.txt"))
        try expect(watcher.savePair(watched), "Cannot install native watcher")
        watcher.syncPair(watched.id)
        try wait(watcher)
        RunLoop.main.run(until: Date().addingTimeInterval(4))
        try write("after", URL(fileURLWithPath: watched.localPath).appendingPathComponent("file.txt"))
        let eventDeadline = Date().addingTimeInterval(10)
        while watcher.pairs[0].lastOutcome == "verified" && Date() < eventDeadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        try expect(watcher.pairs[0].lastOutcome == "pending", "Native FSEvents missed modification")
        watcher.tick(now: Date().addingTimeInterval(46))
        try wait(watcher)
        try expect(read(root.appendingPathComponent("remote/watcher/file.txt")) == "after", "Watcher queue did not sync change")
        watcher.shutdown()

        print("PASS · \(checks) assertions · previews, push/pull/bisync, verification, recovery, retries, pause, locks")
    }
}
