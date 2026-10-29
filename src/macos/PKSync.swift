import SwiftUI
import AppKit

// Same inline FR/EN/ES/DE convention as the existing PK settings shell.
private let syncStrings: [String: [String]] = [
    "title": ["Dossiers synchronisés", "Synced folders", "Carpetas sincronizadas", "Synchronisierte Ordner"],
    "subtitle": ["Prévoir · Transférer · Vérifier", "Preview · Transfer · Verify", "Simular · Transferir · Verificar", "Vorschau · Übertragen · Prüfen"],
    "add": ["Ajouter un dossier", "Add folder", "Añadir carpeta", "Ordner hinzufügen"],
    "createPair": ["Créer une paire", "Create a pair", "Crear una pareja", "Paar erstellen"],
    "editPair": ["Modifier la paire", "Edit pair", "Editar pareja", "Paar bearbeiten"],
    "pairName": ["Nom de la paire", "Pair name", "Nombre de la pareja", "Paarname"],
    "pairSetupHelp": ["Une paire relie un dossier de ce Mac à une destination Google Drive. Créez-la ici, puis commencez par une simulation.", "A pair links a folder on this Mac to a Google Drive destination. Create it here, then start with a preview.", "Una pareja conecta una carpeta de este Mac con un destino de Google Drive. Créala aquí y empieza con una simulación.", "Ein Paar verbindet einen Ordner auf diesem Mac mit einem Google-Drive-Ziel. Hier erstellen und zuerst eine Vorschau starten."],
    "pairConnects": ["Relie ce dossier Mac à la destination Drive ci-dessous", "Links this Mac folder to the Drive destination below", "Conecta esta carpeta del Mac con el destino de Drive", "Verbindet diesen Mac-Ordner mit dem Drive-Ziel unten"],
    "pairFormIntro": ["Choisissez un dossier sur ce Mac et sa destination Drive. Enregistrez la paire, puis lancez une simulation pour voir ce qui changerait.", "Choose a folder on this Mac and its Drive destination. Save the pair, then preview to see what would change.", "Elige una carpeta de este Mac y su destino en Drive. Guarda la pareja y simula para ver qué cambiaría.", "Wähle einen Ordner auf diesem Mac und sein Drive-Ziel. Speichere das Paar und starte eine Vorschau, um Änderungen zu sehen."],
    "qaFixtureNotice": ["Mode test : cette paire utilise des données fictives. Aucun dossier Drive réel n’est connecté ; l’ouverture, le montage et les synchronisations sont désactivés.", "Test mode: this pair uses sample data. No real Drive folder is connected; opening, mounting and sync runs are disabled.", "Modo de prueba: esta pareja usa datos de ejemplo. No hay una carpeta real de Drive conectada; abrir, montar y sincronizar están desactivados.", "Testmodus: Dieses Paar verwendet Beispieldaten. Kein echtes Drive-Verzeichnis ist verbunden; Öffnen, Einbinden und Synchronisieren sind deaktiviert."],
    "qaDriveCard": ["Drive de test", "Test Drive", "Drive de prueba", "Test-Drive"],
    "qaDriveHelp": ["Cette paire de démonstration utilise un identifiant fictif et ne peut pas ouvrir Google Drive.", "This sample pair uses a fake ID and cannot open Google Drive.", "Esta pareja de ejemplo usa un ID ficticio y no puede abrir Google Drive.", "Dieses Beispielpaar verwendet eine erfundene ID und kann Google Drive nicht öffnen."],
    "all": ["Synchroniser tout", "Sync all", "Sincronizar todo", "Alles synchronisieren"],
    "simulateAll": ["Tout simuler", "Preview all", "Simular todo", "Alles simulieren"],
    "simulate": ["Simuler · dry run", "Preview · dry run", "Simular · dry run", "Vorschau · dry run"],
    "simulating": ["Simulation", "Preview", "Simulación", "Vorschau"],
    "previewOnly": ["Simulation uniquement", "Preview only", "Solo simulación", "Nur Vorschau"],
    "previewOnlyNote": ["Activé par défaut : les lancements automatiques et globaux restent des simulations. Désactivez ce mode ou confirmez un lancement réel pour activer les transferts.", "Enabled by default: automatic and global runs remain previews. Disable this mode or confirm a real run to activate transfers.", "Activado por defecto: las ejecuciones automáticas y globales siguen siendo simulaciones. Desactiva este modo o confirma una ejecución real para activar transferencias.", "Standardmäßig aktiv: automatische und globale Läufe bleiben Vorschauen. Diesen Modus deaktivieren oder einen echten Lauf bestätigen, um Übertragungen zu aktivieren."],
    "realRun": ["Lancer une synchronisation réelle ?", "Start a real sync?", "¿Iniciar una sincronización real?", "Echte Synchronisierung starten?"],
    "preview": ["Simulation terminée", "Preview complete", "Simulación finalizada", "Vorschau abgeschlossen"],
    "running": ["Transfert en cours", "Transferring", "Transfiriendo", "Übertragung läuft"],
    "verifying": ["Vérification des contenus…", "Verifying contents…", "Verificando contenidos…", "Inhalte werden geprüft…"],
    "sync": ["Synchroniser", "Sync", "Sincronizar", "Synchronisieren"],
    "pause": ["Pause 1 h", "Pause 1 h", "Pausa 1 h", "Pause 1 Std."],
    "resume": ["Reprendre", "Resume", "Reanudar", "Fortsetzen"],
    "pauseNote": ["La pause suspend les prochains départs ; le transfert en cours continue.", "Pause suspends new runs; the current transfer continues.", "La pausa suspende los nuevos inicios; la transferencia actual continúa.", "Pause verhindert neue Starts; die laufende Übertragung wird fortgesetzt."],
    "stop": ["Arrêter", "Stop", "Detener", "Stoppen"],
    "retry": ["Relancer la paire", "Retry pair", "Reintentar pareja", "Paar erneut starten"],
    "retryAll": ["Relancer les échecs", "Retry failures", "Reintentar errores", "Fehler erneut versuchen"],
    "folders": ["Dossiers", "Folders", "Carpetas", "Ordner"],
    "status": ["Statut", "Status", "Estado", "Status"],
    "state": ["État actuel", "Current state", "Estado actual", "Aktueller Status"],
    "mode": ["Mode", "Mode", "Modo", "Modus"],
    "realTransfers": ["Transferts réels", "Real transfers", "Transferencias reales", "Echte Übertragungen"],
    "lastRunLabel": ["Dernière exécution", "Last run", "Última ejecución", "Letzter Lauf"],
    "pairPaused": ["Paire en pause", "Pair paused", "Pareja en pausa", "Paar pausiert"],
    "pausedAll": ["Suspendu globalement", "Paused globally", "En pausa global", "Global pausiert"],
    "inventory": ["Inventaire", "Inventory", "Inventario", "Bestand"],
    "files": ["fichiers", "files", "archivos", "Dateien"],
    "file": ["fichier", "file", "archivo", "Datei"],
    "localSide": ["Local", "Local", "Local", "Lokal"],
    "remoteSide": ["Distant", "Remote", "Remoto", "Entfernt"],
    "fromSide": ["Depuis", "From", "Desde", "Von"],
    "toSide": ["Vers", "To", "Hacia", "Nach"],
    "driveTitle": ["Google Drive", "Google Drive", "Google Drive", "Google Drive"],
    "flowBoth": ["Synchroniser", "Sync", "Sincronizar", "Synchronisieren"],
    "flowToDrive": ["Vers Drive", "To Drive", "A Drive", "Zu Drive"],
    "flowToMac": ["Vers le Mac", "To Mac", "Al Mac", "Zum Mac"],
    "openFinderCard": ["Ouvrir dans Finder", "Open in Finder", "Abrir en Finder", "Im Finder öffnen"],
    "openDriveCard": ["Ouvrir Drive", "Open Drive", "Abrir Drive", "Drive öffnen"],
    "mountDriveCard": ["Monter le Drive", "Mount Drive", "Montar Drive", "Drive mounten"],
    "previewShort": ["à simuler", "preview needed", "por simular", "Vorschau nötig"],
    "sendShort": ["à envoyer", "to send", "por enviar", "zu senden"],
    "downloadShort": ["à rapatrier", "to bring back", "por descargar", "herunterzuladen"],
    "deleteShort": ["à supprimer", "to delete", "por eliminar", "zu löschen"],
    "previewCounters": ["Simulez pour afficher les opérations prévues", "Preview to see planned operations", "Simula para ver las operaciones previstas", "Vorschau starten, um geplante Vorgänge zu sehen"],
    "conflictsShort": ["conflits", "conflicts", "conflictos", "Konflikte"],
    "gap": ["Écart", "Gap", "Diferencia", "Differenz"],
    "aligned": ["Alignés", "Aligned", "Alineados", "Abgeglichen"],
    "gapNote": ["Estimation sur la taille cumulée des écarts, à 4 Mo/s de référence. Les fichiers modifiés des deux côtés et les exclusions ne sont pas comptés ; la simulation liste les opérations exactes.", "Estimate from the cumulative size gap at a 4 MB/s reference. Files modified on both sides and exclusions are not counted; a preview lists the exact operations.", "Estimación sobre el tamaño acumulado de la diferencia a 4 MB/s de referencia. Los archivos modificados en ambos lados y las exclusiones no se cuentan; la simulación lista las operaciones exactas.", "Schätzung anhand der kumulativen Differenzgröße bei 4 MB/s Referenz. Beidseitig geänderte Dateien und Ausnahmen zählen nicht; die Vorschau listet die genauen Vorgänge."],
    "queueTitle": ["File d’attente", "Queue", "Cola", "Warteschlange"],
    "queueEmpty": ["Aucune tâche en attente", "No pending job", "Sin tareas pendientes", "Keine Aufgabe ausstehend"],
    "refreshCounts": ["Actualiser les comptes", "Refresh counts", "Actualizar recuentos", "Zählungen aktualisieren"],
    "counting": ["Comptage des fichiers…", "Counting files…", "Contando archivos…", "Dateien werden gezählt…"],
    "countedAt": ["comptés le", "counted on", "contados el", "gezählt am"],
    "remoteDeferred": ["compte distant différé (attente Google)", "remote count deferred (Google cooldown)", "recuento remoto diferido (espera de Google)", "Fernzählung verschoben (Google-Wartezeit)"],
    "estimateLabel": ["Alignement estimé", "Estimated alignment", "Alineación estimada", "Geschätzter Abgleich"],
    "gapMissing": ["Comptages incomplets : lancez Actualiser les comptes.", "Incomplete counts: run Refresh counts.", "Recuentos incompletos: ejecuta Actualizar recuentos.", "Unvollständige Zählung: Zählungen aktualisieren starten."],
    "etaSeconds": ["< 1 min", "< 1 min", "< 1 min", "< 1 Min."],
    "phase.listing": ["Analyse des deux côtés", "Comparing both sides", "Comparando ambos lados", "Beide Seiten werden verglichen"],
    "phase.pull": ["Rapatriement Drive → Mac", "Bringing back Drive → Mac", "Trayendo Drive → Mac", "Abruf Drive → Mac"],
    "phase.push": ["Envoi Mac → Drive", "Sending Mac → Drive", "Enviando Mac → Drive", "Senden Mac → Drive"],
    "phase.deleting": ["Propagation des suppressions", "Propagating deletions", "Propagando borrados", "Löschungen werden übertragen"],
    "phase.verifying": ["Vérification des contenus", "Verifying contents", "Verificando contenidos", "Inhalte werden geprüft"],
    "planned": ["À faire", "Planned", "Pendiente", "Geplant"],
    "doneCount": ["faits", "done", "hechos", "erledigt"],
    "pushCount": ["↑ %@ vers Drive", "↑ %@ to Drive", "↑ %@ a Drive", "↑ %@ zu Drive"],
    "pullCount": ["↓ %@ vers le Mac", "↓ %@ to the Mac", "↓ %@ al Mac", "↓ %@ zum Mac"],
    "deleteCount": ["🗑 %@ suppressions", "🗑 %@ deletions", "🗑 %@ borrados", "🗑 %@ Löschungen"],
    "remaining": ["restant", "remaining", "restante", "verbleibend"],
    "elapsedShort": ["écoulé", "elapsed", "transcurrido", "vergangen"],
    "analyzing": ["Analyse… %@ objets listés", "Analyzing… %@ objects listed", "Analizando… %@ objetos listados", "Analyse… %@ Objekte gelistet"],
    "filesProgress": ["%@ / %@ fichiers", "%@ / %@ files", "%@ / %@ archivos", "%@ / %@ Dateien"],
    "stopRun": ["Arrêter l’exécution", "Stop run", "Detener la ejecución", "Lauf stoppen"],
    "pairs": ["Paires", "Pairs", "Parejas", "Paare"],
    "linkedFolders": ["Dossiers liés", "Linked folders", "Carpetas vinculadas", "Verknüpfte Ordner"],
    "viewHistory": ["Voir l’historique", "View history", "Ver historial", "Verlauf anzeigen"],
    "status.checked": ["À jour au dernier contrôle", "Up to date at last check", "Al día en la última comprobación", "Beim letzten Abgleich aktuell"],
    "status.checkedNote": ["Les fichiers inclus ont été vérifiés à cette date. Les changements ultérieurs seront contrôlés au prochain passage.", "Included files were verified then. Later changes will be checked on the next pass.", "Los archivos incluidos se verificaron entonces. Los cambios posteriores se comprobarán después.", "Enthaltene Dateien wurden damals geprüft. Spätere Änderungen werden beim nächsten Lauf geprüft."],
    "status.action": ["Action nécessaire", "Action needed", "Acción necesaria", "Aktion erforderlich"],
    "status.pending": ["Changements à vérifier", "Changes awaiting check", "Cambios pendientes de comprobar", "Änderungen warten auf Prüfung"],
    "status.previewChanges": ["La dernière simulation prévoit des opérations. Consultez les compteurs avant de synchroniser.", "The latest preview plans changes. Review the counts before syncing.", "La última simulación prevé cambios. Revise los contadores antes de sincronizar.", "Die letzte Vorschau sieht Änderungen vor. Vor dem Abgleich die Zähler prüfen."],
    "status.previewOnly": ["Simulation uniquement", "Preview only", "Solo simulación", "Nur Vorschau"],
    "status.previewOnlyNote": ["Aucun transfert automatique tant qu’une première synchronisation réelle n’a pas été confirmée.", "No automatic transfer until a first real sync is confirmed.", "No hay transferencia automática hasta confirmar la primera sincronización real.", "Keine automatische Übertragung vor Bestätigung des ersten echten Abgleichs."],
    "status.never": ["Jamais vérifié", "Never verified", "Nunca verificado", "Nie geprüft"],
    "status.running": ["Synchronisation en cours", "Sync in progress", "Sincronización en curso", "Synchronisierung läuft"],
    "status.simulating": ["Simulation en cours", "Preview in progress", "Simulación en curso", "Vorschau läuft"],
    "status.paused": ["Synchronisation en pause", "Sync paused", "Sincronización pausada", "Synchronisierung pausiert"],
    "status.lastChecked": ["Dernier contrôle vérifié", "Last verified check", "Última comprobación verificada", "Letzter bestätigter Abgleich"],
    "status.lastTransfers": ["Dernière synchronisation : %d envoyés · %d rapatriés · %d supprimés", "Last sync: %d sent · %d received · %d deleted", "Última sincronización: %d enviados · %d recibidos · %d borrados", "Letzter Abgleich: %d gesendet · %d empfangen · %d gelöscht"],
    "status.cadence": ["Arrière-plan via l’icône 📦 tant que l’app est ouverte · Mac : 45 s après un changement · Drive : environ chaque heure et au réveil", "Background via the 📦 icon while the app is open · Mac: 45 s after a change · Drive: about hourly and on wake", "Segundo plano con el icono 📦 mientras la app está abierta · Mac: 45 s tras un cambio · Drive: cada hora y al despertar", "Hintergrund über das 📦-Symbol bei geöffneter App · Mac: 45 s nach Änderung · Drive: etwa stündlich und nach dem Aufwachen"],
    "status.nextCheck": ["Prochain contrôle automatique :", "Next automatic check:", "Próxima comprobación automática:", "Nächste automatische Prüfung:"],
    "refreshAllFiles": ["Actualiser tout", "Refresh all", "Actualizar todo", "Alle aktualisieren"],
    "syncAllNow": ["Synchroniser tout", "Sync all", "Sincronizar todo", "Alle synchronisieren"],
    "pausedUntilLabel": ["En pause jusqu’à %@", "Paused until %@", "En pausa hasta %@", "Pausiert bis %@"],
    "status.cadenceOff": ["Contrôle automatique indisponible dans ce mode", "Automatic checks unavailable in this mode", "Comprobación automática no disponible en este modo", "Automatische Prüfung in diesem Modus nicht verfügbar"],
    "syncNow": ["Synchroniser maintenant", "Sync now", "Sincronizar ahora", "Jetzt synchronisieren"],
    "refreshFiles": ["Actualiser les fichiers", "Refresh files", "Actualizar archivos", "Dateien aktualisieren"],
    "unknownFiles": ["À actualiser · aucun transfert ne sera lancé", "Refresh needed · no transfer will start", "Actualizar · no se iniciará ninguna transferencia", "Aktualisieren · keine Übertragung wird gestartet"],
    "comparingFiles": ["Comparaison des fichiers en cours… Aucun transfert.", "Comparing files… No transfer.", "Comparando archivos… Sin transferencia.", "Dateien werden verglichen… Keine Übertragung."],
    "archiveWaiting": ["Archivage prioritaire · synchronisation en attente", "Archive has priority · sync waiting", "Archivado prioritario · sincronización en espera", "Archivierung hat Vorrang · Abgleich wartet"],
    "archiveReview": ["Archivage terminé · copie de travail à réconcilier", "Archive finished · reconcile working copy", "Archivado terminado · reconciliar copia de trabajo", "Archivierung beendet · Arbeitskopie abgleichen"],
    "archiveCleanupTitle": ["Réconcilier après l’archivage ?", "Reconcile after archiving?", "¿Reconciliar tras archivar?", "Nach Archivierung abgleichen?"],
    "archiveCleanupConfirm": ["Confirmer la réconciliation", "Confirm reconciliation", "Confirmar reconciliación", "Abgleich bestätigen"],
    "archiveCleanupNote": ["Les fichiers retirés du Bureau par l’archivage seront aussi retirés de la copie Drive de travail — même si cela dépasse la moitié des fichiers — avec une copie conservée dans le dossier de récupération. Les fichiers présents uniquement sur Drive seront pareillement déplacés vers la récupération. Les archives mensuelles restent dans une destination distincte et ne sont jamais la cible. Actualisez d’abord les fichiers pour vérifier la liste ; l’autorisation ne vaut que pour cette exécution.", "Files removed from the Desktop by archiving will also be removed from the working Drive copy — even if that exceeds half the files — with a copy kept in the recovery folder. Files present only on Drive are likewise moved to recovery. Monthly archives stay in a separate destination and are never targeted. Refresh files first to review the list; approval applies to this run only.", "Los archivos retirados del Escritorio por el archivado también se retirarán de la copia Drive de trabajo — incluso si superan la mitad — con una copia en la carpeta de recuperación. Los archivos presentes solo en Drive también se moverán a recuperación. El archivo mensual permanece en un destino distinto y nunca es el objetivo. Actualice primero los archivos; la autorización solo vale para esta ejecución.", "Durch Archivierung entfernte Desktop-Dateien werden auch aus der Drive-Arbeitskopie entfernt — auch bei mehr als der Hälfte — mit Kopie im Wiederherstellungsordner. Nur auf Drive vorhandene Dateien werden ebenfalls dorthin verschoben. Monatsarchive bleiben getrennt und sind nie das Ziel. Zuerst die Dateiliste aktualisieren; die Freigabe gilt nur für diesen Lauf."],
    "archiveMissingBaseline": ["L’état de comparaison manque. Une fusion pourrait rapatrier les fichiers archivés : aucune réinitialisation automatique n’est autorisée. Consultez l’historique avant de reconstruire la paire.", "Comparison state is missing. A merge could restore archived files: automatic reset is not allowed. Review history before rebuilding the pair.", "Falta el estado de comparación. Una fusión podría restaurar archivos: no se permite reinicio automático. Revise el historial.", "Vergleichsstand fehlt. Zusammenführen könnte archivierte Dateien zurückholen: kein automatisches Zurücksetzen. Verlauf prüfen."],
    "archiveOneWayNote": ["L’archivage a retiré des fichiers de l’espace de travail. Cette paire utilise un seul sens : Mac vers Drive conserve les copies Drive supplémentaires ; Drive vers Mac peut rapatrier les fichiers que vous venez d’archiver. Confirmez seulement si c’est le comportement souhaité.", "Archiving removed working files. This pair is one-way: Mac to Drive keeps extra Drive copies; Drive to Mac may restore files just archived. Confirm only if intended.", "El archivado retiró archivos. Esta pareja es unidireccional: Mac a Drive conserva copias extra; Drive a Mac puede restaurar lo archivado. Confirme solo si lo desea.", "Archivierung hat Arbeitsdateien entfernt. Einseitig: Mac zu Drive behält zusätzliche Drive-Kopien; Drive zu Mac kann gerade archivierte Dateien zurückholen. Nur bestätigen, wenn gewünscht."],
    "resimulate": ["Relancer la simulation", "Re-run preview", "Repetir simulación", "Vorschau erneut"],
    "comparison": ["Comparaison Mac ↔ Drive", "Mac ↔ Drive comparison", "Comparación Mac ↔ Drive", "Vergleich Mac ↔ Drive"],
    "previewOf": ["Comparaison du", "Comparison from", "Comparación del", "Vergleich vom"],
    "identical": ["Identiques, non touchés", "Identical, untouched", "Idénticos, sin tocar", "Identisch, unberührt"],
    "toPush": ["À envoyer vers Drive", "To send to Drive", "A enviar a Drive", "Zu Drive senden"],
    "toPull": ["À rapatrier vers le Mac", "To bring to the Mac", "A traer al Mac", "Zum Mac holen"],
    "deletions": ["Suppressions", "Deletions", "Borrados", "Löschungen"],
    "conflictsLabel": ["Conflits arbitrés", "Resolved conflicts", "Conflictos resueltos", "Gelöste Konflikte"],
    "list.push": ["↑ Vers Drive", "↑ To Drive", "↑ a Drive", "↑ Zu Drive"],
    "list.pull": ["↓ Vers le Mac", "↓ To the Mac", "↓ al Mac", "↓ Zum Mac"],
    "list.deleteRemote": ["🗑 Sur Drive", "🗑 On Drive", "🗑 En Drive", "🗑 Auf Drive"],
    "list.deleteLocal": ["🗑 Sur le Mac", "🗑 On the Mac", "🗑 En el Mac", "🗑 Auf dem Mac"],
    "list.conflicts": ["⚡ Conflits", "⚡ Conflicts", "⚡ Conflictos", "⚡ Konflikte"],
    "pushNewLabel": ["Nouveaux fichiers vers Drive", "New files to Drive", "Archivos nuevos a Drive", "Neue Dateien zu Drive"],
    "pushModifiedLabel": ["Fichiers modifiés vers Drive", "Modified files to Drive", "Archivos modificados a Drive", "Geänderte Dateien zu Drive"],
    "pullNewLabel": ["Nouveaux fichiers vers le Mac", "New files to the Mac", "Archivos nuevos al Mac", "Neue Dateien zum Mac"],
    "pullModifiedLabel": ["Fichiers modifiés vers le Mac", "Modified files to the Mac", "Archivos modificados al Mac", "Geänderte Dateien zum Mac"],
    "deleteOnDrive": ["Suppressions sur Drive", "Deletions on Drive", "Borrados en Drive", "Löschungen auf Drive"],
    "deleteOnMac": ["Suppressions sur le Mac", "Deletions on the Mac", "Borrados en el Mac", "Löschungen auf dem Mac"],
    "alignedVerdict": ["Aligné — rien à faire", "Aligned — nothing to do", "Alineado — nada que hacer", "Abgeglichen — nichts zu tun"],
    "deleteVerdict": ["%@ suppressions seront propagées", "%@ deletions will be propagated", "%@ borrados se propagarán", "%@ Löschungen werden übertragen"],
    "deleteVerdictNote": ["Une synchronisation propage aussi les suppressions, ce n’est pas une sauvegarde immuable. Vérifie la liste avant de confirmer.", "Sync also propagates deletions; it is not an immutable backup. Review the list before confirming.", "La sincronización también propaga borrados; no es una copia inmutable. Revisa la lista antes de confirmar.", "Sync überträgt auch Löschungen; keine unveränderliche Sicherung. Liste vor dem Bestätigen prüfen."],
    "opsVerdict": ["%@ opérations prévues — rien ne bouge avant ta confirmation", "%@ planned operations — nothing changes before you confirm", "%@ operaciones previstas — nada cambia antes de confirmar", "%@ geplante Vorgänge — nichts ändert sich vor deiner Bestätigung"],
    "showDetail": ["Voir le détail", "Show details", "Ver detalles", "Details anzeigen"],
    "plannedFiles": ["Fichiers concernés", "Affected files", "Archivos afectados", "Betroffene Dateien"],
    "closeDrawer": ["Fermer le détail", "Close details", "Cerrar detalles", "Details schließen"],
    "noPlannedFiles": ["Aucun fichier concerné dans cette catégorie.", "No files in this category.", "No hay archivos en esta categoría.", "Keine Dateien in dieser Kategorie."],
    "previewTruncated": ["La simulation limite la liste à 5 000 fichiers par catégorie.", "The preview limits the list to 5,000 files per category.", "La simulación limita la lista a 5.000 archivos por categoría.", "Die Vorschau begrenzt die Liste auf 5.000 Dateien pro Kategorie."],
    "reason.pushNew": ["Nouveau sur le Mac · à ajouter sur Drive", "New on Mac · add to Drive", "Nuevo en Mac · añadir a Drive", "Neu auf dem Mac · zu Drive hinzufügen"],
    "reason.pushModified": ["Version du Mac retenue · remplacer sur Drive", "Mac version selected · replace on Drive", "Versión de Mac elegida · reemplazar en Drive", "Mac-Version ausgewählt · auf Drive ersetzen"],
    "reason.pullNew": ["Nouveau sur Drive · à ajouter sur le Mac", "New on Drive · add to Mac", "Nuevo en Drive · añadir a Mac", "Neu auf Drive · zum Mac hinzufügen"],
    "reason.pullModified": ["Version Drive retenue · remplacer sur le Mac", "Drive version selected · replace on Mac", "Versión de Drive elegida · reemplazar en Mac", "Drive-Version ausgewählt · auf dem Mac ersetzen"],
    "reason.deleteRemote": ["Supprimé sur le Mac · suppression propagée sur Drive", "Deleted on Mac · deletion propagates to Drive", "Borrado en Mac · eliminación propagada a Drive", "Auf dem Mac gelöscht · Löschung auf Drive übertragen"],
    "reason.deleteLocal": ["Supprimé sur Drive · suppression propagée sur le Mac", "Deleted on Drive · deletion propagates to Mac", "Borrado en Drive · eliminación propagada a Mac", "Auf Drive gelöscht · Löschung auf den Mac übertragen"],
    "runForReal": ["Lancer pour de vrai…", "Run for real…", "Ejecutar de verdad…", "Wirklich ausführen…"],
    "noComparison": ["Aucune comparaison récente. Lance « Simuler · dry run » pour voir précisément ce qui serait ajouté, remplacé ou supprimé — et ce qui reste intact.", "No recent comparison. Run “Preview · dry run” to see exactly what would be added, replaced or deleted — and what stays untouched.", "Sin comparación reciente. Ejecuta «Simular · dry run» para ver qué se añadiría, reemplazaría o borraría, y qué queda intacto.", "Kein aktueller Vergleich. „Vorschau · dry run“ zeigt genau, was hinzugefügt, ersetzt oder gelöscht würde — und was unberührt bleibt."],
    "history": ["Activité", "Activity", "Actividad", "Aktivität"],
    "journal": ["Journal technique", "Technical log", "Registro técnico", "Technisches Protokoll"],
    "report": ["Voir le rapport", "View report", "Ver informe", "Bericht anzeigen"],
    "openlog": ["Ouvrir le journal", "Open journal", "Abrir registro", "Protokoll öffnen"],
    "empty": ["Un dossier. Deux emplacements. Un état explicite.", "One folder. Two locations. One explicit status.", "Una carpeta. Dos ubicaciones. Un estado explícito.", "Ein Ordner. Zwei Orte. Ein eindeutiger Status."],
    "emptyBody": ["Ajoutez une paire puis commencez par une simulation. Vos fichiers restent intacts jusqu’au lancement réel.", "Add a pair, then start with a preview. Your files remain untouched until a real run.", "Añade una pareja y comienza con una simulación. Los archivos permanecen intactos hasta una ejecución real.", "Füge ein Paar hinzu und starte mit einer Vorschau. Dateien bleiben bis zum echten Lauf unverändert."],
    "safe": ["La simulation ne copie, n’écrase et ne supprime aucun fichier. Elle ne valide jamais une sauvegarde.", "Preview never copies, overwrites or deletes files. It never validates a backup.", "La simulación no copia, sobrescribe ni borra archivos. Nunca valida una copia de seguridad.", "Die Vorschau kopiert, überschreibt oder löscht keine Dateien. Sie bestätigt niemals eine Sicherung."],
    "verificationNote": ["Vérifié = contenus inclus comparés par taille et empreinte à la date indiquée. Les exclusions ne sont pas sauvegardées. Une synchronisation propage aussi les suppressions : ce n’est pas une sauvegarde immuable.", "Verified = included contents compared by size and hash at the stated time. Excluded files are not backed up. Two-way sync also propagates deletions: it is not an immutable backup.", "Verificado = contenidos incluidos comparados por tamaño y huella en la fecha indicada. Las exclusiones no se respaldan. La sincronización bidireccional también propaga borrados: no es una copia inmutable.", "Geprüft = eingeschlossene Inhalte zum angegebenen Zeitpunkt nach Größe und Hash verglichen. Ausnahmen werden nicht gesichert. Bidirektionaler Sync überträgt auch Löschungen: keine unveränderliche Sicherung."],
    "local": ["Dossier Mac", "Mac folder", "Carpeta Mac", "Mac-Ordner"],
    "drive": ["Chemin Google Drive", "Google Drive path", "Ruta de Google Drive", "Google-Drive-Pfad"],
    "remote": ["Remote rclone", "rclone remote", "Remote rclone", "rclone-Remote"],
    "driveDestination": ["Destination sur Google Drive", "Google Drive destination", "Destino en Google Drive", "Google-Drive-Ziel"],
    "driveAccount": ["Connexion configurée", "Configured connection", "Conexión configurada", "Konfigurierte Verbindung"],
    "openDrive": ["Ouvrir Google Drive", "Open Google Drive", "Abrir Google Drive", "Google Drive öffnen"],
    "folderLink": ["Lien du dossier", "Folder link", "Enlace de carpeta", "Ordnerlink"],
    "pathMethod": ["Chemin rclone (avancé)", "rclone path (advanced)", "Ruta rclone (avanzado)", "rclone-Pfad (erweitert)"],
    "pasteLink": ["Collez ici l’adresse du dossier Google Drive", "Paste the Google Drive folder address", "Pega la dirección de la carpeta de Google Drive", "Adresse des Google-Drive-Ordners einfügen"],
    "linkInstructions": ["1. Ouvrez le dossier de destination dans Drive.\n2. Copiez son adresse dans la barre du navigateur.\n3. Collez le lien complet ci-dessous, pas le nom du dossier.", "1. Open the destination folder in Drive.\n2. Copy its address from the browser bar.\n3. Paste the full link below, not the folder name.", "1. Abre la carpeta de destino en Drive.\n2. Copia su dirección de la barra del navegador.\n3. Pega el enlace completo, no el nombre de la carpeta.", "1. Zielordner in Drive öffnen.\n2. Adresse aus der Browserleiste kopieren.\n3. Vollständigen Link einfügen, nicht den Ordnernamen."],
    "folderDetected": ["Identifiant du dossier détecté", "Detected folder ID", "ID de carpeta detectado", "Erkannte Ordner-ID"],
    "accountAdvanced": ["Changer de compte rclone (avancé)", "Change rclone account (advanced)", "Cambiar cuenta rclone (avanzado)", "rclone-Konto ändern (erweitert)"],
    "accountHelp": ["« gdrive » est le nom de votre connexion rclone, pas un dossier. Laissez-le tel quel pour votre compte habituel. Vérifiez que le navigateur ouvre le même compte Google.", "“gdrive” is your rclone connection name, not a folder. Keep it for your usual account. Make sure the browser opens the same Google account.", "«gdrive» es el nombre de la conexión rclone, no una carpeta. Déjalo para tu cuenta habitual. Comprueba que el navegador abre la misma cuenta Google.", "„gdrive“ ist der Name der rclone-Verbindung, kein Ordner. Für das übliche Konto unverändert lassen. Im Browser dasselbe Google-Konto wählen."],
    "pathHelp": ["Chemin relatif à la racine du compte rclone, par exemple Sync/Documents. Ne collez ni « gdrive: » ni une URL dans ce champ.", "Path relative to the rclone account root, e.g. Sync/Documents. Do not paste “gdrive:” or a URL here.", "Ruta relativa a la raíz de la cuenta rclone, p. ej. Sync/Documents. No pegues «gdrive:» ni una URL aquí.", "Pfad relativ zum rclone-Kontostamm, z. B. Sync/Documents. Weder „gdrive:“ noch eine URL hier einfügen."],
    "name": ["Nom", "Name", "Nombre", "Name"],
    "choose": ["Choisir…", "Choose…", "Elegir…", "Auswählen…"],
    "direction": ["Direction", "Direction", "Dirección", "Richtung"],
    "dir.bidirectional": ["⇄ Deux sens", "⇄ Two-way", "⇄ Dos sentidos", "⇄ Beide Richtungen"],
    "dir.push": ["↑ Mac vers Drive", "↑ Mac to Drive", "↑ Mac a Drive", "↑ Mac zu Drive"],
    "dir.pull": ["↓ Drive vers Mac", "↓ Drive to Mac", "↓ Drive a Mac", "↓ Drive zu Mac"],
    "directionNote": ["Unidirectionnel : copie et remplace, sans supprimer les fichiers supplémentaires. Bidirectionnel : réconcilie les deux côtés, suppressions incluses. Les versions remplacées sont conservées à part.", "One-way: copies and replaces, without deleting extra files. Two-way: reconciles both sides, including deletions. Replaced versions are preserved separately.", "Unidireccional: copia y reemplaza sin borrar archivos extra. Bidireccional: reconcilia ambos lados, incluidos los borrados. Las versiones reemplazadas se guardan aparte.", "Einseitig: kopiert und ersetzt, ohne zusätzliche Dateien zu löschen. Beidseitig: gleicht beide Seiten einschließlich Löschungen ab. Ersetzte Versionen bleiben separat erhalten."],
    "conflict": ["Conflits / première fusion", "Conflicts / initial merge", "Conflictos / primera fusión", "Konflikte / erste Zusammenführung"],
    "conflict.newest": ["Préférer le plus récent", "Prefer newest", "Preferir más reciente", "Neueste bevorzugen"],
    "conflict.local": ["Préférer le Mac", "Prefer Mac", "Preferir Mac", "Mac bevorzugen"],
    "conflict.remote": ["Préférer Drive", "Prefer Drive", "Preferir Drive", "Drive bevorzugen"],
    "ignores": ["Exclusions · un motif par ligne", "Exclusions · one pattern per line", "Exclusiones · un patrón por línea", "Ausnahmen · ein Muster pro Zeile"],
    "enabled": ["Paire activée", "Pair enabled", "Pareja activada", "Paar aktiviert"],
    "save": ["Enregistrer", "Save", "Guardar", "Speichern"],
    "edit": ["Modifier", "Edit", "Editar", "Bearbeiten"],
    "cancel": ["Annuler", "Cancel", "Cancelar", "Abbrechen"],
    "more": ["Actions de la paire", "Pair actions", "Acciones de pareja", "Paaraktionen"],
    "globalActions": ["Actions globales", "Global actions", "Acciones globales", "Globale Aktionen"],
    "remove": ["Retirer la paire", "Remove pair", "Retirar pareja", "Paar entfernen"],
    "removeNote": ["Aucun fichier Mac, Drive ou de récupération ne sera supprimé.", "No Mac, Drive or recovery files will be deleted.", "No se eliminará ningún archivo del Mac, Drive o recuperación.", "Keine Mac-, Drive- oder Wiederherstellungsdateien werden gelöscht."],
    "merge": ["Fusionner les deux côtés ?", "Merge both sides?", "¿Fusionar ambos lados?", "Beide Seiten zusammenführen?"],
    "mergeNote": ["La politique choisie départage les fichiers différents. Les versions remplacées sont conservées dans les dossiers de récupération. Ensuite, les suppressions seront propagées. Lancez d’abord une simulation pour examiner les opérations.", "The chosen policy resolves differing files. Replaced versions are preserved in recovery folders. Subsequent runs propagate deletions. Preview first to inspect operations.", "La política elegida resuelve los archivos diferentes. Las versiones reemplazadas se guardan en carpetas de recuperación. Las siguientes ejecuciones propagan borrados. Simula primero.", "Die gewählte Regel entscheidet bei unterschiedlichen Dateien. Ersetzte Versionen bleiben in Wiederherstellungsordnern erhalten. Spätere Läufe übertragen Löschungen. Zuerst Vorschau starten."],
    "needsResync": ["Nouvelle comparaison nécessaire", "New comparison needed", "Nueva comparación necesaria", "Neuer Vergleich erforderlich"],
    "startSync": ["Démarrer les transferts…", "Start transfers…", "Iniciar transferencias…", "Übertragungen starten…"],
    "retryPreview": ["Réessayer la simulation", "Retry preview", "Reintentar simulación", "Vorschau erneut versuchen"],
    "retryAfter": ["Réessayez après", "Try again after", "Reintenta después de", "Erneut versuchen nach"],
    "technicalDetails": ["Détails techniques", "Technical details", "Detalles técnicos", "Technische Details"],
    "howItWorks": ["Comment fonctionne la synchronisation ?", "How does synchronization work?", "¿Cómo funciona la sincronización?", "Wie funktioniert die Synchronisierung?"],
    "rateLimited": ["Accès Drive temporairement limité", "Drive access temporarily limited", "Acceso a Drive limitado temporalmente", "Drive-Zugriff vorübergehend begrenzt"],
    "failure.quota.title": ["Google Drive limite temporairement l’accès", "Google Drive temporarily limits access", "Google Drive limita el acceso temporalmente", "Google Drive begrenzt vorübergehend den Zugriff"],
    "failure.storage.title": ["Espace Google Drive insuffisant", "Insufficient Google Drive storage", "Espacio de Google Drive insuficiente", "Nicht genügend Google-Drive-Speicher"],
    "failure.storage.help": ["Le compte Google Drive manque d’espace pour recevoir les fichiers. Libérez de l’espace ou changez de destination, puis relancez.", "The Google Drive account lacks storage for the files. Free space or change destination, then retry.", "La cuenta de Google Drive no tiene espacio suficiente. Libera espacio o cambia el destino y reintenta.", "Dem Google-Drive-Konto fehlt Speicherplatz. Platz freigeben oder Ziel ändern und erneut versuchen."],
    "failure.quota.help": ["Google refuse momentanément la lecture des dossiers : trop de requêtes sur le service utilisé par la connexion rclone. Ce n’est pas un manque de place sur Drive. Attendez puis réessayez ; une fusion ne résout pas ce blocage.", "Google temporarily refuses folder reads: the service used by the rclone connection hit a request limit. This is not a lack of storage space. Wait, then retry; merging will not fix this block.", "Google rechaza temporalmente la lectura de carpetas por un límite de solicitudes de la conexión rclone. No falta espacio en Drive. Espera y reintenta; una fusión no resuelve este bloqueo.", "Google verweigert vorübergehend das Lesen von Ordnern wegen eines Anfragelimits der rclone-Verbindung. Es fehlt kein Speicherplatz. Warten und erneut versuchen; Zusammenführen löst diese Sperre nicht."],
    "failure.resync.title": ["La comparaison doit être reconstruite", "The comparison needs rebuilding", "Hay que reconstruir la comparación", "Vergleich muss neu erstellt werden"],
    "failure.resync.help": ["La comparaison précédente n’est plus disponible. Revenez dans Dossiers pour confirmer une nouvelle comparaison. Aucun transfert réel n’est lancé sans confirmation.", "The previous comparison is unavailable. Return to Folders to confirm a new comparison. Real transfers require confirmation.", "La comparación anterior no está disponible. Vuelve a Carpetas para confirmar una nueva. Las transferencias reales requieren confirmación.", "Der vorherige Vergleich ist nicht verfügbar. Unter Ordner einen neuen Vergleich bestätigen. Echte Übertragungen benötigen eine Bestätigung."],
    "failure.authentication.title": ["Connexion Google à réautoriser", "Google connection needs authorization", "Hay que autorizar de nuevo Google", "Google-Verbindung erneut autorisieren"],
    "failure.authentication.help": ["L’autorisation de la connexion rclone n’est plus valable. Réautorisez le compte avant de relancer ; vos fichiers ne sont pas déclarés synchronisés.", "The rclone authorization is no longer valid. Reauthorize the account before retrying; files are not marked synced.", "La autorización rclone ya no es válida. Autoriza de nuevo antes de reintentar; los archivos no se marcan como sincronizados.", "Die rclone-Autorisierung ist ungültig. Konto vor dem nächsten Versuch erneut autorisieren; Dateien gelten nicht als synchronisiert."],
    "failure.permission.title": ["Accès à certains fichiers refusé", "Access to some files denied", "Acceso a algunos archivos denegado", "Zugriff auf einige Dateien verweigert"],
    "failure.permission.help": ["Vérifiez les permissions du dossier sur le Mac et les droits du compte Google sur le dossier Drive, puis relancez.", "Check Mac folder permissions and Google account access to the Drive folder, then retry.", "Comprueba los permisos de la carpeta Mac y del usuario Google en Drive y reintenta.", "Mac-Ordnerberechtigungen und Google-Zugriffsrechte auf den Drive-Ordner prüfen, dann erneut versuchen."],
    "failure.notFound.title": ["Dossier introuvable", "Folder not found", "Carpeta no encontrada", "Ordner nicht gefunden"],
    "failure.notFound.help": ["Vérifiez le dossier Mac, le lien du dossier Drive et le compte utilisé. Corrigez le dossier dans ses réglages avant de relancer.", "Check the Mac folder, Drive folder link and account. Correct the folder settings before retrying.", "Comprueba la carpeta Mac, el enlace Drive y la cuenta. Corrige los ajustes antes de reintentar.", "Mac-Ordner, Drive-Link und Konto prüfen. Einstellungen vor dem erneuten Versuch korrigieren."],
    "failure.network.title": ["Connexion réseau interrompue", "Network connection interrupted", "Conexión de red interrumpida", "Netzwerkverbindung unterbrochen"],
    "failure.network.help": ["Le service n’a pas pu être joint. Vérifiez votre connexion puis réessayez. Rien n’est déclaré vérifié.", "The service could not be reached. Check your connection and retry. Nothing is marked verified.", "No se pudo contactar con el servicio. Comprueba la conexión y reintenta. Nada se marca como verificado.", "Der Dienst war nicht erreichbar. Verbindung prüfen und erneut versuchen. Nichts gilt als geprüft."],
    "failure.safety.title": ["Arrêt de sécurité", "Safety stop", "Parada de seguridad", "Sicherheitsstopp"],
    "failure.safety.help": ["Rclone a détecté des changements importants et a préféré s’arrêter. Consultez le rapport avant toute nouvelle synchronisation ; la sécurité n’est pas contournée automatiquement.", "Rclone detected major changes and stopped for safety. Review the report before another sync; safeguards are not bypassed automatically.", "Rclone detectó cambios importantes y se detuvo por seguridad. Revisa el informe; las protecciones no se omiten automáticamente.", "Rclone erkannte umfangreiche Änderungen und stoppte sicherheitshalber. Bericht prüfen; Schutzmaßnahmen werden nicht automatisch umgangen."],
    "failure.other.title": ["Exécution interrompue", "Run interrupted", "Ejecución interrumpida", "Ausführung unterbrochen"],
    "failure.other.help": ["Une erreur a empêché de terminer. Consultez les détails ou le rapport, puis relancez après correction. Rien n’est déclaré vérifié.", "An error prevented completion. Review details or the report, then retry after fixing it. Nothing is marked verified.", "Un error impidió terminar. Revisa los detalles o el informe y reintenta tras corregirlo. Nada se marca como verificado.", "Ein Fehler verhinderte den Abschluss. Details oder Bericht prüfen, Problem beheben und erneut versuchen. Nichts gilt als geprüft."],
    "verified": ["Vérifié", "Verified", "Verificado", "Geprüft"],
    "pending": ["À vérifier", "Pending check", "Pendiente de verificar", "Prüfung ausstehend"],
    "idle": ["Jamais vérifié", "Never verified", "Nunca verificado", "Nie geprüft"],
    "error": ["Échec · non vérifié", "Failed · not verified", "Error · no verificado", "Fehler · ungeprüft"],
    "unverified": ["Copié · non vérifié", "Copied · not verified", "Copiado · no verificado", "Kopiert · ungeprüft"],
    "cancelled": ["Arrêté · non vérifié", "Stopped · not verified", "Detenido · no verificado", "Gestoppt · ungeprüft"],
    "interrupted": ["Interrompu · à relancer", "Interrupted · retry needed", "Interrumpido · reintentar", "Unterbrochen · erneut starten"],
    "queued": ["En file d’attente", "Queued", "En cola", "Warteschlange"],
    "retryAt": ["Prochaine tentative :", "Next attempt:", "Próximo intento:", "Nächster Versuch:"],
    "historyEmpty": ["Chaque simulation et synchronisation laissera ici un rapport et une action de relance.", "Each preview and sync leaves a report and a retry action here.", "Cada simulación y sincronización deja aquí un informe y una acción de reintento.", "Jede Vorschau und Synchronisierung hinterlässt hier Bericht und Wiederholungsaktion."],
    "autoNote": ["Local : surveillance native + délai de 45 s. Drive : vérification toutes les heures et au réveil. Un seul rclone à la fois, arrêté entre les exécutions.", "Local: native watcher + 45 s debounce. Drive: hourly and after wake. One rclone at a time, stopped between runs.", "Local: vigilancia nativa + espera de 45 s. Drive: cada hora y al despertar. Un rclone a la vez, detenido entre ejecuciones.", "Lokal: nativer Watcher + 45 s Wartezeit. Drive: stündlich und nach Aufwachen. Ein rclone gleichzeitig, zwischen Läufen beendet."],
]

func syncText(_ key: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "app-language") ?? "fr"
    let index = ["fr": 0, "en": 1, "es": 2, "de": 3][lang] ?? 1
    return syncStrings[key]?[index] ?? key
}

func syncFileCount(_ count: Int) -> String { "\(count) \(syncText(count == 1 ? "file" : "files"))" }

enum SyncOperationKind: String {
    case push, pull, deleteLocal, deleteRemote

    var title: String {
        switch self {
        case .push: syncText("toPush")
        case .pull: syncText("toPull")
        case .deleteLocal: syncText("deleteOnMac")
        case .deleteRemote: syncText("deleteOnDrive")
        }
    }

    var symbol: String {
        switch self {
        case .push: "arrow.up"
        case .pull: "arrow.down"
        case .deleteLocal, .deleteRemote: "trash"
        }
    }

    func files(in plan: PreviewPlan) -> [(path: String, reason: String)] {
        switch self {
        case .push:
            return plan.pushNew.map { ($0, syncText("reason.pushNew")) }
                + plan.pushModified.map { ($0, syncText("reason.pushModified")) }
        case .pull:
            return plan.pullNew.map { ($0, syncText("reason.pullNew")) }
                + plan.pullModified.map { ($0, syncText("reason.pullModified")) }
        case .deleteLocal: return plan.deleteLocal.map { ($0, syncText("reason.deleteLocal")) }
        case .deleteRemote: return plan.deleteRemote.map { ($0, syncText("reason.deleteRemote")) }
        }
    }
}

private struct SelectedSyncOperation: Identifiable {
    let pairID: UUID
    let kind: SyncOperationKind
    var id: String { "\(pairID.uuidString)-\(kind.rawValue)" }
}

/// Large source/destination panels inspired by the archive endpoint cards.
/// Each side shows its own transfer and deletion counts from the latest preview.
struct SyncPairLocations: View {
    let pair: SyncPair
    var plan: PreviewPlan?
    var active = false
    var onMountDrive: () -> Void = {}
    var onOperation: (SyncOperationKind) -> Void = { _ in }
    private var isQAScreen: Bool { CommandLine.arguments.contains("--qa-screen") }
    var body: some View {
        HStack(spacing: 10) {
            localEndpoint(trailing: false).frame(maxWidth: .infinity)
            directionBridge(vertical: false).frame(width: 64)
            remoteEndpoint(trailing: true).frame(maxWidth: .infinity)
        }.frame(maxWidth: .infinity)
    }

    private func localEndpoint(trailing: Bool) -> some View {
        let uploads = (plan?.pushNew.count ?? 0) + (plan?.pushModified.count ?? 0)
        return endpoint(
            eyebrow: syncText("fromSide"), title: localFolderName,
            path: shortPath(pair.localPath), icon: finderIcon, tint: .blue, trailing: trailing,
            transferIcon: "arrow.up", transferCount: uploads, transferLabel: syncText("sendShort"),
            deletionCount: plan?.deleteLocal.count ?? 0, showOps: plan != nil,
            transferKind: .push, deletionKind: .deleteLocal,
            actionTitle: syncText("openFinderCard"), actionIcon: finderIcon,
            action: { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: pair.localPath) }
        )
    }

    private func remoteEndpoint(trailing: Bool) -> some View {
        let downloads = (plan?.pullNew.count ?? 0) + (plan?.pullModified.count ?? 0)
        return endpoint(
            eyebrow: syncText("toSide"), title: remoteFolderName, path: remotePath,
            icon: driveIcon, tint: .green, trailing: trailing,
            transferIcon: "arrow.down", transferCount: downloads, transferLabel: syncText("downloadShort"),
            deletionCount: plan?.deleteRemote.count ?? 0, showOps: plan != nil,
            transferKind: .pull, deletionKind: .deleteRemote,
            actionTitle: syncText(isQAScreen ? "qaDriveCard" : "openDriveCard"), actionIcon: driveIcon,
            actionDisabled: isQAScreen, action: openDrive,
            mountAction: isQAScreen ? nil : onMountDrive
        )
    }

    private var localFolderName: String {
        let name = URL(fileURLWithPath: pair.localPath).lastPathComponent
        return name.isEmpty || name == "/" ? pair.name : name
    }

    private var remoteFolderName: String {
        let name = (pair.drivePath as NSString).lastPathComponent
        return name.isEmpty ? syncText("driveTitle") : name
    }

    private var remotePath: String {
        pair.drivePath.isEmpty ? pair.destinationDescription : "\(pair.remote):\(pair.drivePath)"
    }

    private var finderIcon: NSImage {
        NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")
    }

    private var driveIcon: NSImage {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("web/logo-drive.svg"),
           let image = NSImage(contentsOf: url) { return image }
        return NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Google Drive")
            ?? NSImage(size: NSSize(width: 18, height: 18))
    }

    private func endpoint(eyebrow: String, title: String, path: String, icon: NSImage, tint: Color, trailing: Bool,
                          transferIcon: String, transferCount: Int, transferLabel: String,
                          deletionCount: Int, showOps: Bool, transferKind: SyncOperationKind, deletionKind: SyncOperationKind,
                          actionTitle: String, actionIcon: NSImage,
                          actionDisabled: Bool = false, action: @escaping () -> Void,
                          mountAction: (() -> Void)? = nil) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            Text(eyebrow).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
                .padding(.bottom, 8)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    if trailing { Spacer(minLength: 0) }
                    endpointTitle(title, icon: icon)
                    operationCounts(transferIcon: transferIcon, transferCount: transferCount,
                                    transferLabel: transferLabel, tint: tint, deletionCount: deletionCount, showOps: showOps,
                                    transferKind: transferKind, deletionKind: deletionKind)
                    if !trailing { Spacer(minLength: 0) }
                }
                VStack(alignment: .leading, spacing: 8) {
                    endpointTitle(title, icon: icon)
                    operationCounts(transferIcon: transferIcon, transferCount: transferCount,
                                    transferLabel: transferLabel, tint: tint, deletionCount: deletionCount, showOps: showOps,
                                    transferKind: transferKind, deletionKind: deletionKind)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 10)
            endpointPath(path)
            endpointActions(actionTitle: actionTitle, actionIcon: actionIcon, tint: tint,
                            disabled: actionDisabled, action: action, mountAction: mountAction)
                .padding(.top, 8)
        }
        .padding(.horizontal, 12).padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 108, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.045), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
    }

    private func endpointTitle(_ title: String, icon: NSImage) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: icon).resizable().scaledToFit()
                .frame(width: 22, height: 22).frame(width: 30, height: 30)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .accessibilityHidden(true)
            Text(title).font(.system(size: 23, weight: .black, design: .rounded))
                .tracking(-0.8).lineLimit(1).truncationMode(.middle).help(title)
        }
    }

    @ViewBuilder private func operationCounts(transferIcon: String, transferCount: Int,
                                               transferLabel: String, tint: Color, deletionCount: Int,
                                               showOps: Bool, transferKind: SyncOperationKind,
                                               deletionKind: SyncOperationKind) -> some View {
        HStack(spacing: 8) {
            Button { onOperation(transferKind) } label: {
                operationBadge(showOps ? transferCount : nil, title: transferLabel, symbol: transferIcon, tint: tint, coloredWhenZero: true)
            }.buttonStyle(.plain).help(syncText(showOps ? "plannedFiles" : "unknownFiles"))
            Button { onOperation(deletionKind) } label: {
                operationBadge(showOps ? deletionCount : nil, title: syncText("deleteShort"), symbol: "trash", tint: .red)
            }.buttonStyle(.plain).help(syncText(showOps ? "plannedFiles" : "unknownFiles"))
        }.fixedSize(horizontal: true, vertical: false)
    }

    private func endpointPath(_ path: String) -> some View {
        Text(path).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            .lineLimit(1).truncationMode(.middle).help(path).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func endpointActions(actionTitle: String, actionIcon: NSImage, tint: Color, disabled: Bool,
                                 action: @escaping () -> Void, mountAction: (() -> Void)?) -> some View {
        HStack(spacing: 8) {
            cardButton(actionTitle, icon: actionIcon, tint: tint, disabled: disabled,
                       help: disabled ? syncText("qaDriveHelp") : nil, action: action)
            if let mountAction { cardButton(syncText("mountDriveCard"), symbol: "arrow.down", action: mountAction) }
        }
    }

    private func operationBadge(_ count: Int?, title: String, symbol: String, tint: Color, coloredWhenZero: Bool = false) -> some View {
        let color = (count ?? 0) > 0 || coloredWhenZero ? tint : Color.secondary
        return HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
            Text(count.map(String.init) ?? "—").font(.system(size: 14, weight: .heavy, design: .rounded)).monospacedDigit()
            Text(title).font(.system(size: 9, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(color.opacity((count ?? 0) > 0 ? 0.11 : 0.07), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count.map(String.init) ?? syncText("unknownFiles")) \(title)")
    }

    private func cardButton(_ title: String, icon: NSImage, tint: Color, disabled: Bool = false,
                            help: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(nsImage: icon).resizable().scaledToFit().frame(width: 14, height: 14)
                Text(title).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(disabled ? Color.secondary : Color.white)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(disabled ? Color.primary.opacity(0.055) : tint, in: Capsule())
        }.buttonStyle(.plain).disabled(disabled).help(help ?? title)
    }

    private func cardButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 11, weight: .semibold))
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(Color.primary.opacity(0.72))
                .padding(.horizontal, 11).padding(.vertical, 7)
                .background(Color.primary.opacity(0.055), in: Capsule())
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func directionBridge(vertical: Bool) -> some View {
        let label: String = switch pair.direction {
        case .bidirectional: syncText("flowBoth")
        case .push: syncText("flowToDrive")
        case .pull: syncText("flowToMac")
        }
        if vertical {
            VStack(spacing: 6) {
                directionLine
                HStack(spacing: 6) {
                    if active { ProgressView().controlSize(.mini).accessibilityHidden(true) }
                    Text(label.uppercased()).font(.system(size: 9, weight: .heavy)).tracking(1.1).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity).padding(.vertical, 2)
        } else {
            VStack(spacing: 8) {
                directionLine
                    .overlay {
                        if active && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                            TransferFlowDot(reverse: pair.direction == .pull)
                        }
                    }
                Text(label.uppercased()).font(.system(size: 9, weight: .heavy)).tracking(0.2)
                    .lineLimit(1).minimumScaleFactor(0.65).foregroundStyle(.secondary)
            }
        }
    }

    private var directionLine: some View {
        HStack(spacing: 0) {
            if pair.direction != .push {
                Image(systemName: "arrowtriangle.left.fill").font(.system(size: 7)).foregroundStyle(Color.secondary.opacity(0.45))
            }
            Rectangle().fill(Color.primary.opacity(0.10)).frame(maxWidth: .infinity).frame(height: 1)
            if pair.direction != .pull {
                Image(systemName: "arrowtriangle.right.fill").font(.system(size: 7)).foregroundStyle(Color.secondary.opacity(0.45))
            }
        }
    }

    private func openDrive() {
        guard !CommandLine.arguments.contains("--qa-screen") else { return }
        let url = pair.driveFolderID.flatMap { URL(string: "https://drive.google.com/drive/folders/\($0)") }
            ?? URL(string: "https://drive.google.com/drive/my-drive")!
        NSWorkspace.shared.open(url)
    }
}

private struct TransferFlowDot: View {
    let reverse: Bool
    @State private var moving = false

    var body: some View {
        Circle().fill(Color.accentColor).frame(width: 7, height: 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(x: moving ? (reverse ? 0 : 48) : (reverse ? 48 : 0))
            .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: moving)
            .onAppear { moving = true }
            .accessibilityHidden(true)
    }
}

extension SyncEngine {
    func presentationState(for pair: SyncPair) -> String {
        if runningPairID == pair.id { return isDryRun ? "simulating" : runProgress?.phase == .verifying ? "verifying" : "running" }
        if archiveInProgress || waitingForOperationLock { return "archiveWaiting" }
        if !pair.enabled { return "pairPaused" }
        if pair.archiveReviewRequired { return "archiveReview" }
        if cooldownUntil(for: pair) != nil { return "rateLimited" }
        if isPaused { return "pausedAll" }
        if queue.contains(where: { $0.pairID == pair.id }) { return "queued" }
        return pair.lastOutcome
    }
}

struct SyncSectionView: View {
    @ObservedObject private var engine: SyncEngine
    @AppStorage("app-language") private var language = "fr"
    @State private var editing: SyncPair?
    @State private var merging: SyncPair?
    @State private var archiveCleanup: SyncPair?
    @State private var removing: SyncPair?
    @State private var tab = "pairs"
    @State private var selectedOperation: SelectedSyncOperation?
    @State private var pairError: String?
    private let onMountDrive: () -> Void
    private let showSampleOperation: Bool
    private var isQAScreen: Bool { CommandLine.arguments.contains("--qa-screen") }

    init(engine: SyncEngine = .shared, initialTab: String = "pairs", onMountDrive: @escaping () -> Void = {},
         showSampleOperation: Bool = false) {
        self.engine = engine
        self.onMountDrive = onMountDrive
        self.showSampleOperation = showSampleOperation
        _tab = State(initialValue: initialTab == "history" ? "history" : "pairs")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSectionHeader(title: syncText("title"), subtitle: syncText("subtitle"), icon: "arrow.triangle.2.circlepath")
                if isQAScreen { qaFixtureNotice }
                if let error = engine.storageError {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).textSelection(.enabled)
                }
                if engine.pairs.isEmpty {
                    Button { editing = SyncPair() } label: { Label(syncText("createPair"), systemImage: "plus") }
                        .buttonStyle(.borderedProminent).disabled(engine.busy || engine.storageError != nil)
                    Label(syncText("pairSetupHelp"), systemImage: "arrow.left.arrow.right")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Label(syncText("safe"), systemImage: "eye.circle")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    globalStatus
                }
                HStack {
                    if tab == "pairs" {
                        Text("\(syncText("linkedFolders")) · \(engine.pairs.count)")
                            .font(.headline).foregroundStyle(.secondary)
                        Button { editing = SyncPair() } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.plain).foregroundStyle(Color.accentColor)
                            .accessibilityLabel(syncText("createPair"))
                            .disabled(engine.busy || engine.storageError != nil)
                        Spacer()
                        Button { tab = "history" } label: {
                            Label(syncText("viewHistory"), systemImage: "clock.arrow.circlepath")
                        }.buttonStyle(.plain).foregroundStyle(Color.accentColor)
                    } else {
                        Button { tab = "pairs" } label: {
                            Label(syncText("folders"), systemImage: "chevron.left")
                        }.buttonStyle(.plain).foregroundStyle(Color.accentColor)
                        Spacer()
                    }
                }
                if engine.isPaused {
                    HStack {
                        Label(syncText("pauseNote"), systemImage: "pause.circle")
                        Spacer()
                        Button(syncText("resume")) { engine.resume() }
                    }.font(.caption).foregroundStyle(.secondary)
                }
                if tab == "pairs" { pairsView } else { history }
                DisclosureGroup(syncText("howItWorks")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(syncText("verificationNote"))
                        Text(syncText("autoNote"))
                    }.font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }.font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 28)
            .frame(maxWidth: 1800).frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .trailing) {
            if let selection = selectedOperation {
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        Color.black.opacity(0.22)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedOperation = nil }
                        operationDrawer(selection)
                            .frame(width: min(460, geometry.size.width * 0.88))
                            .frame(maxHeight: .infinity)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: .black.opacity(0.16), radius: 18, x: -5)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeOut(duration: 0.2), value: selection.id)
                .accessibilityAddTraits(.isModal)
            }
        }
        .sheet(item: $editing) { SyncPairForm(original: $0, engine: engine) }
        .onAppear {
            if showSampleOperation, let pair = engine.pairs.first {
                selectedOperation = SelectedSyncOperation(pairID: pair.id, kind: .push)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pkShowSyncHistory)) { _ in tab = "history" }
        .alert(syncText("error"), isPresented: Binding(get: { pairError != nil }, set: { if !$0 { pairError = nil } })) {
            Button("OK") { pairError = nil }
        } message: { Text(pairError ?? "") }
        .alert(syncText("realRun"), isPresented: Binding(get: { merging != nil }, set: { if !$0 { merging = nil } })) {
            Button(syncText("simulate")) { if let pair = merging { engine.syncPair(pair.id, dryRun: true, resync: true); tab = "history" } }
            Button(syncText("sync")) { if let pair = merging { engine.syncPair(pair.id, resync: pair.direction.usesBisync && pair.needsResync) } }
            Button(syncText("cancel"), role: .cancel) {}
        } message: { Text(syncText(merging?.direction.usesBisync == true ? "mergeNote" : "directionNote")) }
        .alert(syncText("archiveCleanupTitle"), isPresented: Binding(get: { archiveCleanup != nil }, set: { if !$0 { archiveCleanup = nil } })) {
            Button(syncText("refreshFiles")) { if let pair = archiveCleanup { refreshFiles(pair) } }
            if let pair = archiveCleanup, !(pair.direction.usesBisync && pair.needsResync) {
                Button(syncText("archiveCleanupConfirm"), role: .destructive) {
                    engine.syncPair(pair.id, archiveCleanupApproved: true)
                }
            }
            Button(syncText("cancel"), role: .cancel) {}
        } message: {
            if let pair = archiveCleanup {
                Text(syncText(pair.direction.usesBisync && pair.needsResync ? "archiveMissingBaseline" : pair.direction.usesBisync ? "archiveCleanupNote" : "archiveOneWayNote") + "\n\n" + pair.destinationDescription)
            }
        }
        .alert(syncText("remove"), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button(syncText("remove"), role: .destructive) { if let pair = removing { engine.deletePair(pair.id) } }
            Button(syncText("cancel"), role: .cancel) {}
        } message: { Text(syncText("removeNote")) }
    }

    private var globalStatus: some View {
        let enabled = engine.pairs.filter(\.enabled)
        let failed = engine.storageError != nil || enabled.contains { ["error", "unverified", "interrupted", "rateLimited", "needsResync", "archiveReview"].contains(engine.presentationState(for: $0)) }
        let previewOnly = enabled.contains { $0.previewOnly }
        let previewChanges = enabled.contains { (engine.previewRun(for: $0.id)?.plan?.totalOps ?? 0) > 0 }
        let verified = !enabled.isEmpty && !previewChanges && enabled.allSatisfy { engine.presentationState(for: $0) == "verified" }
        let title: String = engine.archiveInProgress || engine.waitingForOperationLock ? syncText("archiveWaiting")
            : enabled.contains(where: \.archiveReviewRequired) ? syncText("archiveReview")
            : engine.busy ? syncText(engine.isDryRun ? "status.simulating" : "status.running")
            : engine.isPaused ? syncText("status.paused")
            : failed ? syncText("status.action")
            : previewOnly ? syncText("status.previewOnly")
            : verified ? syncText("status.checked")
            : previewChanges || enabled.contains(where: { $0.lastOutcome == "pending" }) ? syncText("status.pending") : syncText("status.never")
        let symbol = engine.busy ? "arrow.triangle.2.circlepath" : failed ? "exclamationmark.circle.fill"
            : verified ? "checkmark.seal.fill" : "clock.arrow.circlepath"
        let color: Color = failed ? .orange : verified ? .green : .accentColor
        let lastVerified = enabled.compactMap(\.lastRun).min()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: symbol).font(.title3.weight(.semibold)).foregroundStyle(color)
                    .help(hint)
                Spacer(minLength: 12)
                if !enabled.isEmpty {
                    Button { engine.syncAll(dryRun: true) } label: {
                        Label(syncText("refreshAllFiles"), systemImage: "arrow.clockwise")
                    }.controlSize(.small)
                        .disabled(isQAScreen || engine.busy || engine.storageError != nil)
                    Button { engine.syncAll() } label: {
                        Label(syncText("syncAllNow"), systemImage: "arrow.triangle.2.circlepath")
                    }.buttonStyle(.borderedProminent).controlSize(.small)
                        .disabled(isQAScreen || engine.busy || engine.storageError != nil)
                    Menu {
                        Button { engine.refreshAllInventories() } label: { Label(syncText("refreshCounts"), systemImage: "chart.bar.doc.horizontal") }
                            .disabled(engine.inventoryBusy || engine.busy || engine.storageError != nil)
                        Button { engine.retryFailed() } label: { Label(syncText("retryAll"), systemImage: "arrow.clockwise.circle") }
                        Divider()
                        if engine.isPaused { Button { engine.resume() } label: { Label(syncText("resume"), systemImage: "play.circle") } }
                        else { Button { engine.pauseForHours(1) } label: { Label(syncText("pause"), systemImage: "pause.circle") } }
                    } label: { Image(systemName: "ellipsis.circle") }
                        .controlSize(.small)
                        .accessibilityLabel(syncText("globalActions"))
                        .disabled(isQAScreen)
                }
            }
            if engine.storageError != nil { Text(engine.storageError ?? "").font(.callout).foregroundStyle(.orange) }
            if engine.busy { runSummary }
            if let paused = engine.pausedUntil {
                Text(String(format: syncText("pausedUntilLabel"), paused.formatted(date: .omitted, time: .shortened)))
                    .font(.caption.weight(.medium)).foregroundStyle(.orange)
            } else if engine.automaticEnabled, let next = engine.nextAutomaticCheck {
                TimelineView(.periodic(from: .now, by: 10)) { _ in
                    Text(infoLine(next: next))
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
            } else if let lastVerified {
                Text("\(syncText("status.lastChecked")) · \(lastVerified.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            Label(syncText(engine.automaticEnabled ? "status.cadence" : "status.cadenceOff"), systemImage: engine.automaticEnabled ? "menubar.rectangle" : "clock.slash")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.19), lineWidth: 1))
    }

    /// One compact line: last verified check + next automatic check.
    private func infoLine(next: Date) -> String {
        var parts = [String]()
        if let lastVerified = engine.pairs.filter(\.enabled).compactMap(\.lastRun).min() {
            parts.append("\(syncText("status.lastChecked")) \(lastVerified.formatted(date: .omitted, time: .shortened))")
        }
        parts.append("\(syncText("status.nextCheck")) \(next.formatted(.relative(presentation: .named))) (\(next.formatted(date: .omitted, time: .shortened)))")
        return parts.joined(separator: " · ")
    }

    private var hint: String {
        let enabled = engine.pairs.filter(\.enabled)
        if engine.storageError != nil { return engine.storageError ?? "" }
        if enabled.contains(where: \.previewOnly) { return syncText("status.previewOnlyNote") }
        if enabled.allSatisfy({ engine.presentationState(for: $0) == "verified" }) { return syncText("status.checkedNote") }
        return syncText("status.previewChanges")
    }

    /// The live run inside the status block: name, phase, one metrics line, one done line.
    private var runSummary: some View {
        let progress = engine.runProgress ?? RunProgress()
        let pair = engine.pairs.first { $0.id == engine.runningPairID }
        let phase = {
            switch progress.phase {
            case .listing: return syncText("phase.listing")
            case .pull: return syncText("phase.pull")
            case .push: return syncText("phase.push")
            case .deleting: return syncText("phase.deleting")
            case .verifying: return syncText("phase.verifying")
            }
        }()
        let fraction: Double? = progress.bytesTotal > 0 ? min(1, max(0, Double(progress.bytesDone) / Double(progress.bytesTotal))) : nil
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                ProgressView().controlSize(.mini).accessibilityHidden(true)
                Text("\(pair?.name ?? "—") — \(phase)").font(.callout.weight(.semibold)).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 8)
                if let fraction { Text("\(Int(fraction * 100)) %").font(.callout.monospacedDigit()) }
                Button(syncText("stop")) { engine.stopRunning() }.controlSize(.mini)
            }
            if progress.transfersTotal > 0 {
                Text("\(String(format: syncText("filesProgress"), "\(progress.transfersDone)", "\(progress.transfersTotal)")) · \(SyncEngine.byteText(progress.bytesDone)) / \(SyncEngine.byteText(progress.bytesTotal))\(progress.speed > 0 ? " · \(SyncEngine.byteText(Int64(progress.speed)))/s" : "")\(progress.eta != nil ? " · \(syncText("remaining")) ~\(Self.durationText(progress.eta!))" : "")")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                ProgressView(value: fraction ?? 0).controlSize(.small)
            } else {
                Text(String(format: syncText("analyzing"), "\(progress.listed)"))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text("\(syncText("doneCount")) : \(String(format: syncText("pushCount"), "\(progress.pushDone)")) · \(String(format: syncText("pullCount"), "\(progress.pullDone)")) · \(String(format: syncText("deleteCount"), "\(progress.deleteDone)")) · \(syncText("elapsedShort")) \(Self.durationText(progress.elapsed))")
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func operationDrawer(_ selection: SelectedSyncOperation) -> some View {
        let run = engine.previewRun(for: selection.pairID)
        let plan = engine.operationPlan(for: selection.pairID)
        let files = plan.map { selection.kind.files(in: $0) } ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(syncText("plannedFiles")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Label(selection.kind.title, systemImage: selection.kind.symbol).font(.title3.weight(.bold))
                    if let pair = engine.pairs.first(where: { $0.id == selection.pairID }) {
                        Text(pair.name).font(.caption).foregroundStyle(.secondary)
                    }
                    if let run {
                        Text((run.finished ?? run.started).formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2).foregroundStyle(.secondary)
                    } else if let checked = engine.pairs.first(where: { $0.id == selection.pairID })?.lastRun, plan != nil {
                        Text("\(syncText("status.lastChecked")) · \(checked.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button { selectedOperation = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).font(.title3).foregroundStyle(.secondary)
                    .accessibilityLabel(syncText("closeDrawer"))
                    .keyboardShortcut(.cancelAction)
            }.padding(20)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if files.isEmpty {
                        Text(syncText(plan != nil ? "noPlannedFiles" : engine.busy && engine.isDryRun ? "comparingFiles" : "unknownFiles"))
                            .foregroundStyle(.secondary).padding(20)
                    }
                    ForEach(files.indices, id: \.self) { index in
                        let file = files[index]
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: Self.fileTypeSymbol(file.path).symbol)
                                    .foregroundStyle(Self.fileTypeSymbol(file.path).tint)
                                Text((file.path as NSString).lastPathComponent)
                                    .font(.callout.weight(.medium)).textSelection(.enabled)
                            }
                            Text(file.path).font(.caption.monospaced()).foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            Label(file.reason, systemImage: selection.kind.symbol)
                                .font(.caption).foregroundStyle(selection.kind == .deleteLocal || selection.kind == .deleteRemote ? .red : .secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 12)
                        Divider().padding(.leading, 20)
                    }
                    if run?.plan?.truncated == true {
                        Text(syncText("previewTruncated")).font(.caption).foregroundStyle(.orange).padding(20)
                    }
                }
            }
        }
        .accessibilityIdentifier("syncOperationDrawer")
    }

    private var qaFixtureNotice: some View {
        Label(syncText("qaFixtureNotice"), systemImage: "testtube.2")
            .font(.callout.weight(.medium)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.16), lineWidth: 1))
    }

    static func durationText(_ seconds: TimeInterval) -> String { SyncEngine.durationText(seconds) }

    /// Pairs sorted by what deserves attention: running, queued, warnings, then calm states.
    /// Stable otherwise: the user's creation order is preserved within a same rank.
    private var orderedPairs: [SyncPair] {
        func rank(_ pair: SyncPair) -> Int {
            let state = engine.presentationState(for: pair)
            if engine.runningPairID == pair.id { return 0 }
            if engine.queue.contains(where: { $0.pairID == pair.id }) { return 1 }
            if ["error", "unverified", "interrupted", "rateLimited", "needsResync", "archiveReview"].contains(state) { return 2 }
            if state == "pending" || state == "archiveWaiting" { return 3 }
            if pair.previewOnly { return 4 }
            return 5
        }
        return engine.pairs.enumerated()
            .sorted { a, b in rank(a.element) == rank(b.element) ? a.offset < b.offset : rank(a.element) < rank(b.element) }
            .map(\.element)
    }

    private var pairsView: some View {
        VStack(spacing: 12) {
            if engine.pairs.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "folder.badge.gearshape").font(.system(size: 36)).foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(syncText("empty")).font(.headline)
                    Text(syncText("emptyBody")).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(32)
            }
            ForEach(orderedPairs) { pair in pairCard(pair) }
        }
        .animation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .spring(duration: 0.3), value: orderedPairs.map(\.id))
    }
    private func pairCard(_ pair: SyncPair) -> some View {
        let presentation = engine.presentationState(for: pair)
        let state = presentation == "verified" && (engine.previewRun(for: pair.id)?.plan?.totalOps ?? 0) > 0 ? "pending" : presentation
        let running = engine.runningPairID == pair.id
        let attention = ["error", "unverified", "interrupted", "rateLimited", "needsResync", "archiveReview"].contains(state)
        let plan = engine.operationPlan(for: pair.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                    Text(pair.name.isEmpty ? URL(fileURLWithPath: pair.localPath).lastPathComponent : pair.name)
                        .font(.headline.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 8)
                if !running { actionsRow(pair) }
            }
            SyncPairLocations(pair: pair, plan: plan, active: running, onMountDrive: onMountDrive,
                              onOperation: {
                                  selectedOperation = SelectedSyncOperation(pairID: pair.id, kind: $0)
                                  if plan == nil { refreshFiles(pair) }
                              })
            if let preview = engine.previewRun(for: pair.id) {
                Text("\(syncText("previewOf")) \((preview.finished ?? preview.started).formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let plan {
                deletionWarning(plan)
                typeRow(plan)
            }
            if !running {
                if attention { warningStrip(pair, state: state) }
                else if engine.pairs.count > 1 { metaLine(pair) }
            }
        }.padding(.vertical, 8)
            .animation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeInOut(duration: 0.22), value: running)
            .contextMenu { pairContextMenu(pair) }
    }

    private func previewBadge(_ pair: SyncPair) -> some View {
        Label(syncText("previewOnly"), systemImage: "eye")
            .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .help(syncText("previewOnlyNote"))
    }

    /// Attention states get one explicit tinted strip instead of scattered caption lines.
    @ViewBuilder private func warningStrip(_ pair: SyncPair, state: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if state == "rateLimited" {
                Label(syncText("failure.quota.title"), systemImage: "hourglass").font(.callout.weight(.medium)).foregroundStyle(Color.orange)
            } else if state == "archiveReview" {
                Label(syncText("archiveReview"), systemImage: "archivebox").font(.callout.weight(.medium)).foregroundStyle(Color.orange)
            } else if state == "needsResync" {
                Label(syncText("needsResync"), systemImage: "arrow.triangle.2.circlepath").font(.callout.weight(.medium)).foregroundStyle(Color.orange)
            } else if let message = pair.lastMessage {
                Label(SyncDiagnostic.clean(message), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(Color.orange).lineLimit(3)
            } else {
                Label(syncText(state), systemImage: "exclamationmark.circle").font(.callout.weight(.medium)).foregroundStyle(Color.orange)
            }
            if let until = engine.cooldownUntil(for: pair) { retryTime(until) }
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
    }

    /// Calm states keep a single secondary line: last run, queue position, next attempt.
    @ViewBuilder private func metaLine(_ pair: SyncPair) -> some View {
        if pair.lastRun != nil || pair.nextRetryAt != nil || engine.queue.contains(where: { $0.pairID == pair.id }) {
            HStack(spacing: 14) {
                if let date = pair.lastRun {
                    Label("\(syncText("lastRunLabel")) · \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock.arrow.circlepath")
                }
                if engine.queue.contains(where: { $0.pairID == pair.id }) {
                    Label(syncText("queued"), systemImage: "clock")
                }
                if let date = pair.nextRetryAt {
                    Label("\(syncText("retryAt")) \(date.formatted(date: .omitted, time: .shortened))", systemImage: "timer")
                }
            }.font(.caption).foregroundStyle(.secondary)
        }
    }

    private func actionsRow(_ pair: SyncPair) -> some View {
        HStack(spacing: 8) {
            Button { refreshFiles(pair) } label: {
                Label(syncText("refreshFiles"), systemImage: "arrow.clockwise")
            }.buttonStyle(.plain).foregroundStyle(Color.accentColor)
            .disabled(isQAScreen || !pair.enabled || engine.cooldownUntil(for: pair) != nil)
            Button(syncText("syncNow")) {
                if pair.archiveReviewRequired { archiveCleanup = pair }
                else if pair.previewOnly || pair.needsResync && pair.direction.usesBisync { merging = pair }
                else { engine.syncPair(pair.id) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isQAScreen || !pair.enabled || engine.cooldownUntil(for: pair) != nil)
        }.controlSize(.regular)
        .disabled(isQAScreen || engine.busy || engine.archiveInProgress || engine.waitingForOperationLock || engine.storageError != nil)
    }

    private func refreshFiles(_ pair: SyncPair) {
        guard !isQAScreen, !engine.busy, engine.storageError == nil, pair.enabled,
              engine.cooldownUntil(for: pair) == nil else { return }
        engine.syncPair(pair.id, dryRun: true)
    }

    @ViewBuilder private func pairContextMenu(_ pair: SyncPair) -> some View {
        Button(syncText("simulate")) { engine.syncPair(pair.id, dryRun: true) }
            .disabled(isQAScreen || engine.busy || !pair.enabled || engine.storageError != nil || engine.cooldownUntil(for: pair) != nil)
        Button(syncText("sync")) {
            if pair.archiveReviewRequired { archiveCleanup = pair }
            else if pair.previewOnly || pair.needsResync && pair.direction.usesBisync { merging = pair }
            else { engine.syncPair(pair.id) }
        }.disabled(isQAScreen || engine.busy || !pair.enabled || engine.storageError != nil || engine.cooldownUntil(for: pair) != nil)
        Toggle(syncText("enabled"), isOn: enableBinding(pair)).disabled(isQAScreen || engine.busy || engine.storageError != nil)
        Button(syncText("edit")) { editing = pair }.disabled(isQAScreen || engine.busy || engine.storageError != nil)
        Divider()
        Button(syncText("remove"), role: .destructive) { removing = pair }.disabled(isQAScreen || engine.busy || engine.storageError != nil)
    }

    private func enableBinding(_ pair: SyncPair) -> Binding<Bool> {
        Binding(get: { pair.enabled }, set: { enabled in
            guard var updated = engine.pairs.first(where: { $0.id == pair.id }) else { return }
            updated.enabled = enabled
            if !engine.savePair(updated) { pairError = engine.storageError ?? engine.progressText }
        })
    }

    struct TypeCount: Identifiable {
        let symbol: String, tint: Color, count: Int
        var id: String { symbol }
    }

    /// Picto per file type, derived from the extensions of the planned operations.
    static func typeComposition(_ plan: PreviewPlan) -> [TypeCount] {
        let all = plan.pushNew + plan.pushModified + plan.pullNew + plan.pullModified + plan.deleteRemote + plan.deleteLocal
        var counts: [String: Int] = [:]
        for name in all { counts[fileTypeSymbol(name).symbol, default: 0] += 1 }
        return counts.map { key, count in
            let probe = all.first { fileTypeSymbol($0).symbol == key } ?? ""
            let meta = fileTypeSymbol(probe)
            return TypeCount(symbol: meta.symbol, tint: meta.tint, count: count)
        }.sorted { $0.count == $1.count ? $0.symbol < $1.symbol : $0.count > $1.count }
    }

    /// Same per-type pictos as the archive view: image, video, audio, pdf, archive, code, text.
    static func fileTypeSymbol(_ name: String) -> (symbol: String, tint: Color) {
        switch (name as NSString).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "svg", "tiff", "bmp", "raw", "ico": return ("photo", .blue)
        case "mp4", "mov", "mkv", "avi", "m4v", "webm": return ("film", .purple)
        case "mp3", "wav", "aac", "flac", "m4a", "aiff", "ogg": return ("music.note", .pink)
        case "pdf": return ("doc.richtext", .red)
        case "zip", "dmg", "gz", "rar", "7z", "pkg", "tar", "iso": return ("doc.zipper", .orange)
        case "swift", "go", "js", "ts", "html", "css", "py", "sh", "json", "yaml", "yml": return ("chevron.left.forwardslash.chevron.right", .teal)
        case "txt", "md", "csv", "log", "rtf", "doc", "docx", "pages", "xls", "xlsx", "ppt", "pptx", "key": return ("doc.plaintext", .secondary)
        default: return ("doc", .secondary)
        }
    }

    /// File-type pictos use soft capsules so they read as a deliberate summary, not loose glyphs.
    @ViewBuilder private func typeRow(_ plan: PreviewPlan) -> some View {
        let types = Self.typeComposition(plan)
        if !types.isEmpty || !plan.conflicts.isEmpty {
            HStack(spacing: 7) {
                ForEach(types.prefix(5)) { type in
                    HStack(spacing: 4) {
                        Image(systemName: type.symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(type.tint)
                        Text("\(type.count)").font(.caption2.weight(.semibold)).monospacedDigit()
                    }.padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.primary.opacity(0.04), in: Capsule())
                }
                if types.count > 5 {
                    Text("+\(types.count - 5)").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                }
                if !plan.conflicts.isEmpty {
                    Label("\(plan.conflicts.count) \(syncText("conflictsShort"))", systemImage: "bolt.fill")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.orange.opacity(0.09), in: Capsule())
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder private func deletionWarning(_ plan: PreviewPlan) -> some View {
        let deletions = plan.deleteRemote.count + plan.deleteLocal.count
        if deletions > 0 {
            Label(syncText("deleteVerdictNote"), systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(Color.orange).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }
    /// Real file/byte counts per side on one line, gap highlighted, honest ETA.
    @ViewBuilder private func inventoryRows(_ pair: SyncPair) -> some View {
        Divider().padding(.vertical, 2)
        let inventory = engine.inventories[pair.id]
        HStack {
            Label(syncText("inventory"), systemImage: "chart.bar.doc.horizontal").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            Button { engine.refreshInventory(pair.id) } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).font(.caption).foregroundStyle(Color.accentColor)
                .help(syncText("refreshCounts")).accessibilityLabel(syncText("refreshCounts"))
                .disabled(engine.inventoryBusy || engine.busy || engine.storageError != nil)
        }
        if let inventory, inventory.localFiles != nil || inventory.remoteFiles != nil {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text("\(syncText("localSide")) · \(syncFileCount(inventory.localFiles ?? 0)) · \(Self.byteText(inventory.localBytes ?? 0))")
                    Image(systemName: pair.direction.arrow == "⇄" ? "arrow.left.arrow.right" : pair.direction.arrow == "↑" ? "arrow.up" : "arrow.down")
                        .font(.caption2).foregroundStyle(.secondary).accessibilityHidden(true)
                    Text("\(syncText("remoteSide")) · \(inventory.remoteFiles.map { syncFileCount($0) } ?? "—") · \(Self.byteText(inventory.remoteBytes ?? 0))")
                    Spacer(minLength: 0)
                }.font(.system(.caption, design: .monospaced))
                if inventory.remoteDeferred == true, inventory.remoteFiles == nil {
                    Text(syncText("remoteDeferred")).font(.caption2).foregroundStyle(.secondary)
                }
                if inventory.gapFiles != nil {
                    if inventory.aligned {
                        Label(syncText("aligned"), systemImage: "checkmark.seal.fill").font(.caption.weight(.medium)).foregroundStyle(.green)
                    } else {
                        Label("\(syncText("gap")) : \(inventory.gapFiles!) \(syncText("files")) · \(Self.byteText(inventory.gapBytes ?? 0)) · \(syncText("estimateLabel")) \(Self.etaText(inventory.gapBytes ?? 0))",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.medium)).foregroundStyle(.orange)
                    }
                }
            }
        } else if engine.previewRun(for: pair.id)?.plan == nil {
            // No counts and no comparison to act on: one quiet action instead of a nagging warning.
            Button { engine.refreshInventory(pair.id) } label: { Label(syncText("refreshCounts"), systemImage: "arrow.clockwise") }
                .controlSize(.small).disabled(engine.inventoryBusy || engine.busy || engine.storageError != nil)
        }
    }
    static func byteText(_ bytes: Int64) -> String { SyncEngine.byteText(bytes) }
    /// Duration to reconcile the size gap at the reference throughput. Explicitly a rough figure:
    /// modified-on-both-sides files and per-file overhead are unknown without a preview.
    static func etaText(_ gapBytes: Int64) -> String { SyncEngine.etaText(gapBytes) }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(syncText("history")).font(.headline)
                Spacer()
                Button(syncText("openlog")) { NSWorkspace.shared.open(engine.disk.journal) }
                    .disabled(!FileManager.default.fileExists(atPath: engine.disk.journal.path))
            }
            if engine.runs.isEmpty { Text(syncText("historyEmpty")).foregroundStyle(.secondary).padding(.vertical, 20) }
            LazyVStack(spacing: 10) {
                ForEach(engine.runs) { run in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(run.pair.name).font(.headline)
                            if run.dryRun { Label(syncText("simulating"), systemImage: "eye").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            status(run.outcome)
                        }
                        Text(run.started.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(.secondary)
                        if let diagnostic = run.diagnostic {
                            Label(syncText(diagnostic.titleKey), systemImage: "exclamationmark.circle").font(.callout.weight(.medium))
                            Text(syncText(diagnostic.helpKey)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            DisclosureGroup(syncText("technicalDetails")) {
                                Text(SyncDiagnostic.clean(diagnostic.details)).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            }.font(.caption).foregroundStyle(.secondary)
                        } else if !run.message.isEmpty { Text(SyncDiagnostic.clean(run.message)).font(.caption).textSelection(.enabled) }
                        if let pair = engine.pairs.first(where: { $0.id == run.pair.id }), let until = engine.cooldownUntil(for: pair) { retryTime(until) }
                        HStack {
                            Button(syncText("report")) { if let url = engine.readableReportURL(for: run) { NSWorkspace.shared.open(url) } }
                            Button(syncText(run.dryRun ? "retryPreview" : "retry")) {
                                guard let pair = engine.pairs.first(where: { $0.id == run.pair.id }) else { return }
                                if !run.dryRun && (pair.previewOnly || pair.direction.usesBisync && pair.needsResync) { merging = pair }
                                else { engine.replay(run) }
                            }.disabled(engine.busy || !engine.pairs.contains(where: { $0.id == run.pair.id && $0.enabled && engine.cooldownUntil(for: $0) == nil }) || engine.storageError != nil)
                        }.controlSize(.small)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            DisclosureGroup(syncText("journal")) {
                ScrollView([.horizontal, .vertical]) {
                    Text(engine.journalLines.map(SyncDiagnostic.clean).joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced)).textSelection(.enabled).padding(12)
                }.frame(height: 220)
            }
        }
    }
    private func status(_ outcome: String) -> some View {
        let symbol = outcome == "rateLimited" ? "hourglass" : outcome == "pairPaused" || outcome == "pausedAll" ? "pause.circle" : outcome == "queued" ? "clock" : outcome == "verified" ? "checkmark.seal" : outcome == "preview" || outcome == "simulating" ? "eye" : outcome == "running" ? "arrow.triangle.2.circlepath" : "circle.dashed"
        return Label(syncText(outcome), systemImage: symbol).font(.caption.weight(.medium))
            .foregroundStyle(outcome == "verified" ? Color.green : ["error", "unverified", "interrupted", "rateLimited"].contains(outcome) ? Color.orange : Color.secondary)
    }
    private func retryTime(_ date: Date) -> some View {
        Label("\(syncText("retryAfter")) \(date.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
            .font(.caption).foregroundStyle(.secondary)
    }
}

extension Notification.Name {
    static let pkShowSyncHistory = Notification.Name("PKShowSyncHistory")
}

struct SyncPairForm: View {
    let original: SyncPair
    @ObservedObject var engine: SyncEngine
    @Environment(\.dismiss) private var dismiss
    @State private var pair: SyncPair
    @State private var ignores: String
    @State private var error: String?
    @State private var destinationMethod: String
    @State private var folderLink: String
    @State private var confirmingRemoval = false
    private var isQAScreen: Bool { CommandLine.arguments.contains("--qa-screen") }
    init(original: SyncPair, engine: SyncEngine) {
        self.original = original; self.engine = engine
        _pair = State(initialValue: original)
        _ignores = State(initialValue: original.ignores.joined(separator: "\n"))
        _destinationMethod = State(initialValue: original.driveFolderID != nil || original.localPath.isEmpty ? "link" : "path")
        _folderLink = State(initialValue: original.driveFolderID.map { "https://drive.google.com/drive/folders/\($0)" } ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(original.localPath.isEmpty ? syncText("createPair") : syncText("editPair")).font(.title2.bold())
            Text(syncText("pairFormIntro")).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Form {
                Section(syncText("local")) {
                    TextField(syncText("pairName"), text: $pair.name)
                    HStack {
                        TextField(syncText("local"), text: $pair.localPath)
                        Button(syncText("choose")) { choose() }
                    }
                }
                Section(syncText("driveDestination")) {
                    HStack {
                        LabeledContent(syncText("driveAccount"), value: pair.remote)
                        if isQAScreen {
                            Label(syncText("qaDriveCard"), systemImage: "lock.fill")
                                .foregroundStyle(.secondary).help(syncText("qaDriveHelp"))
                        } else {
                            Link(destination: browserDriveURL) { Label(syncText("openDrive"), systemImage: "arrow.up.right.square") }
                        }
                    }
                    Picker(syncText("driveDestination"), selection: $destinationMethod) {
                        Text(syncText("folderLink")).tag("link")
                        Text(syncText("pathMethod")).tag("path")
                    }.pickerStyle(.segmented).labelsHidden()
                    if destinationMethod == "link" {
                        Text(syncText("linkInstructions")).font(.caption).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(syncText("folderLink")).font(.caption).foregroundStyle(.secondary)
                            TextField("", text: $folderLink, prompt: Text("https://drive.google.com/drive/folders/…"))
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel(syncText("pasteLink"))
                        }
                        if let id = try? DriveFolderLink.folderID(from: folderLink) {
                            Text("\(syncText("folderDetected")) : \(id)")
                                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    } else {
                        TextField(syncText("drive"), text: $pair.drivePath).help("Sync/Documents")
                        Text(syncText("pathHelp")).font(.caption).foregroundStyle(.secondary)
                    }
                    DisclosureGroup(syncText("accountAdvanced")) {
                        TextField(syncText("remote"), text: Binding(get: { pair.remote }, set: { pair.remoteOverride = $0 }))
                        Text(syncText("accountHelp")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section(syncText("direction")) {
                    Picker(syncText("direction"), selection: $pair.direction) {
                        ForEach(SyncDirection.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                    Text(syncText("directionNote")).font(.caption).foregroundStyle(.secondary)
                    if pair.direction.usesBisync {
                        Picker(syncText("conflict"), selection: $pair.conflictPolicy) {
                            ForEach(SyncConflictPolicy.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    Toggle(syncText("enabled"), isOn: $pair.enabled)
                    Toggle(syncText("previewOnly"), isOn: $pair.previewOnly)
                    Text(syncText("previewOnlyNote")).font(.caption).foregroundStyle(.secondary)
                }
                Section(syncText("ignores")) {
                    TextEditor(text: $ignores).font(.system(.caption, design: .monospaced)).frame(height: 72)
                        .accessibilityLabel(syncText("ignores"))
                }
                if engine.pairs.contains(where: { $0.id == original.id }) {
                    Section {
                        Button(syncText("remove"), role: .destructive) { confirmingRemoval = true }
                            .disabled(isQAScreen || engine.busy)
                    }
                }
            }.formStyle(.grouped).scrollContentBackground(.hidden)
            if let error { Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Text(syncText("safe")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(syncText("cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(syncText("save")) { save() }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 580, height: 640)
        .alert(syncText("remove"), isPresented: $confirmingRemoval) {
            Button(syncText("remove"), role: .destructive) { engine.deletePair(original.id); dismiss() }
            Button(syncText("cancel"), role: .cancel) {}
        } message: { Text(syncText("removeNote")) }
    }
    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pair.localPath = url.path
        if pair.name.isEmpty { pair.name = url.lastPathComponent }
        if pair.drivePath.isEmpty { pair.drivePath = "Sync/\(url.lastPathComponent)" }
        // Explicit reselection permits changing the expected volume identity.
        pair.volumeUUID = nil
    }
    private func save() {
        if destinationMethod == "link" {
            do { pair.driveFolderID = try DriveFolderLink.folderID(from: folderLink); pair.drivePath = "" }
            catch { self.error = error.localizedDescription; return }
        } else { pair.driveFolderID = nil }
        pair.ignores = ignores.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let reason = engine.validationError(pair) { error = reason; return }
        guard engine.savePair(pair) else { error = engine.storageError ?? engine.progressText; return }
        dismiss()
    }
    private var browserDriveURL: URL {
        if let id = try? DriveFolderLink.folderID(from: folderLink) { return URL(string: "https://drive.google.com/drive/folders/\(id)")! }
        return URL(string: "https://drive.google.com/drive/my-drive")!
    }
}
