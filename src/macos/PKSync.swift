import SwiftUI
import AppKit

// Same inline FR/EN/ES/DE convention as the existing PK settings shell.
private let syncStrings: [String: [String]] = [
    "title": ["Dossiers synchronisés", "Synced folders", "Carpetas sincronizadas", "Synchronisierte Ordner"],
    "subtitle": ["Prévoir. Transférer. Vérifier. Rien de vert sans contrôle.", "Preview. Transfer. Verify. No green status without a check.", "Simular. Transferir. Verificar. Ningún estado verde sin control.", "Vorschau. Übertragen. Prüfen. Kein grüner Status ohne Prüfung."],
    "add": ["Ajouter un dossier", "Add folder", "Añadir carpeta", "Ordner hinzufügen"],
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
    "localSide": ["Local", "Local", "Local", "Lokal"],
    "remoteSide": ["Distant", "Remote", "Remoto", "Entfernt"],
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

struct SyncSectionView: View {
    @ObservedObject private var engine: SyncEngine
    @AppStorage("app-language") private var language = "fr"
    @State private var editing: SyncPair?
    @State private var merging: SyncPair?
    @State private var removing: SyncPair?
    @State private var tab = "folders"

    init(engine: SyncEngine = .shared, initialTab: String = "folders") {
        self.engine = engine
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSectionHeader(title: syncText("title"), subtitle: syncText("subtitle"), icon: "arrow.triangle.2.circlepath")
                if let error = engine.storageError {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).textSelection(.enabled)
                }
                HStack {
                    Button { editing = SyncPair() } label: { Label(syncText("add"), systemImage: "plus") }
                        .buttonStyle(.borderedProminent).disabled(engine.busy || engine.storageError != nil)
                    Spacer()
                    Button { engine.syncAll(dryRun: true); tab = "history" } label: { Label(syncText("simulateAll"), systemImage: "eye") }
                        .disabled(engine.busy || !engine.pairs.contains(where: { $0.enabled && engine.cooldownUntil(for: $0) == nil }))
                    Menu {
                        Button(syncText("all")) { engine.syncAll() }.disabled(!engine.pairs.contains(where: { $0.enabled && engine.cooldownUntil(for: $0) == nil }))
                        Button(syncText("retryAll")) { engine.retryFailed() }
                        if engine.isPaused { Button(syncText("resume")) { engine.resume() } }
                        else { Button(syncText("pause")) { engine.pauseForHours(1) } }
                    } label: { Label(syncText("globalActions"), systemImage: "ellipsis") }
                }
                Label(syncText("safe"), systemImage: "eye.circle")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if engine.busy { progressBanner }
                Picker(syncText("title"), selection: $tab) {
                    Text("\(syncText("folders")) · \(engine.pairs.count)").tag("folders")
                    Text(syncText("status")).tag("status")
                    Text(syncText("history")).tag("history")
                }.pickerStyle(.segmented).labelsHidden()
                if engine.isPaused {
                    HStack {
                        Label(syncText("pauseNote"), systemImage: "pause.circle")
                        Spacer()
                        Button(syncText("resume")) { engine.resume() }
                    }.font(.caption).foregroundStyle(.secondary)
                }
                if tab == "folders" { folders } else if tab == "status" { statusDashboard } else { history }
                DisclosureGroup(syncText("howItWorks")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(syncText("verificationNote"))
                        Text(syncText("autoNote"))
                    }.font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }.font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 28)
            .frame(maxWidth: 850).frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editing) { SyncPairForm(original: $0, engine: engine) }
        .onReceive(NotificationCenter.default.publisher(for: .pkShowSyncHistory)) { _ in tab = "history" }
        .alert(syncText("realRun"), isPresented: Binding(get: { merging != nil }, set: { if !$0 { merging = nil } })) {
            Button(syncText("simulate")) { if let pair = merging { engine.syncPair(pair.id, dryRun: true, resync: true); tab = "history" } }
            Button(syncText("sync")) { if let pair = merging { engine.syncPair(pair.id, resync: pair.direction.usesBisync && pair.needsResync) } }
            Button(syncText("cancel"), role: .cancel) {}
        } message: { Text(syncText(merging?.direction.usesBisync == true ? "mergeNote" : "directionNote")) }
        .alert(syncText("remove"), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button(syncText("remove"), role: .destructive) { if let pair = removing { engine.deletePair(pair.id) } }
            Button(syncText("cancel"), role: .cancel) {}
        } message: { Text(syncText("removeNote")) }
    }

    /// Live execution feedback: rclone's planned operations, real progress, speed and ETA.
    private var progressBanner: some View {
        let progress = engine.runProgress ?? RunProgress()
        let pair = engine.pairs.first(where: { $0.id == engine.runningPairID })
        let phase: String = {
            switch progress.phase {
            case .listing: return engine.isDryRun ? syncText("phase.listing") : syncText("phase.listing")
            case .pull: return syncText("phase.pull")
            case .push: return syncText("phase.push")
            case .deleting: return syncText("phase.deleting")
            case .verifying: return syncText("phase.verifying")
            }
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ProgressView().controlSize(.small).padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(pair?.name ?? "—") — \(phase)").font(.headline)
                    if progress.transfersTotal > 0 {
                        Text("\(String(format: syncText("filesProgress"), "\(progress.transfersDone)", "\(progress.transfersTotal)")) · \(SyncEngine.byteText(progress.bytesDone)) / \(SyncEngine.byteText(progress.bytesTotal))\(progress.bytesTotal > 0 ? " · \(Int(Double(progress.bytesDone) * 100 / Double(progress.bytesTotal))) %" : "")")
                            .font(.caption.monospacedDigit())
                    } else {
                        Text(String(format: syncText("analyzing"), "\(progress.listed)"))
                            .font(.caption.monospacedDigit())
                    }
                    HStack(spacing: 14) {
                        if progress.speed > 0 { Label("\(SyncEngine.byteText(Int64(progress.speed)))/s", systemImage: "speedometer") }
                        if let eta = progress.eta { Label("\(syncText("remaining")) ~\(Self.durationText(eta))", systemImage: "clock") }
                        Label("\(syncText("elapsedShort")) \(Self.durationText(progress.elapsed))", systemImage: "timer")
                    }.font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 14) {
                        Text("\(syncText("planned")) :")
                        Text(String(format: syncText("pushCount"), "\(progress.plannedPushes)"))
                        Text(String(format: syncText("pullCount"), "\(progress.plannedPulls)"))
                        Text(String(format: syncText("deleteCount"), "\(progress.plannedDeletes)"))
                    }.font(.caption.monospacedDigit())
                    HStack(spacing: 14) {
                        Text("\(syncText("doneCount")) :")
                        Text(String(format: syncText("pushCount"), "\(progress.pushDone)"))
                        Text(String(format: syncText("pullCount"), "\(progress.pullDone)"))
                        Text(String(format: syncText("deleteCount"), "\(progress.deleteDone)"))
                    }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
                Button(syncText("stop")) { engine.stopRunning() }
                    .controlSize(.small).accessibilityLabel(syncText("stopRun"))
            }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.25), lineWidth: 1))
    }
    static func durationText(_ seconds: TimeInterval) -> String { SyncEngine.durationText(seconds) }

    private var folders: some View {
        VStack(spacing: 12) {
            if engine.pairs.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "folder.badge.gearshape").font(.system(size: 36)).foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(syncText("empty")).font(.headline)
                    Text(syncText("emptyBody")).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(32)
            }
            ForEach(engine.pairs) { pair in pairCard(pair) }
        }
    }
    private func pairCard(_ pair: SyncPair) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "folder.fill").foregroundStyle(Color.accentColor).font(.title2).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pair.name).font(.headline)
                    if pair.previewOnly { Label(syncText("previewOnly"), systemImage: "eye").font(.caption).foregroundStyle(.secondary) }
                    Text("\(shortPath(pair.localPath))  \(pair.direction.arrow)  \(pair.destinationDescription)")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer(minLength: 8)
                status(!pair.enabled ? "pairPaused" : engine.runningPairID == pair.id && engine.isDryRun ? "simulating" : pair.lastOutcome)
            }
            if engine.runningPairID == pair.id {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ProgressView().controlSize(.small).accessibilityLabel(syncText(engine.isDryRun ? "simulating" : "running"))
                        Text(engine.progressText).font(.caption).lineLimit(2)
                        Spacer()
                        Button(syncText("stop")) { engine.stopRunning() }
                    }
                    if let progress = engine.runProgress, progress.transfersTotal > 0 {
                        Text("\(String(format: syncText("filesProgress"), "\(progress.transfersDone)", "\(progress.transfersTotal)")) · \(SyncEngine.byteText(progress.bytesDone)) / \(SyncEngine.byteText(progress.bytesTotal))\(progress.eta.map { " · \(syncText("remaining")) ~\(Self.durationText($0))" } ?? "")")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack {
                    Button { engine.syncPair(pair.id, dryRun: true); tab = "history" } label: { Label(syncText("simulate"), systemImage: "eye") }
                        .disabled(!pair.enabled || engine.cooldownUntil(for: pair) != nil)
                    Button(syncText(pair.previewOnly || pair.needsResync && pair.direction.usesBisync ? "startSync" : "sync")) {
                        if pair.previewOnly || pair.needsResync && pair.direction.usesBisync { merging = pair }
                        else { engine.syncPair(pair.id) }
                    }
                    .disabled(!pair.enabled || engine.cooldownUntil(for: pair) != nil)
                    Menu {
                        Button(syncText("edit")) { editing = pair }
                        if pair.direction.usesBisync { Button(syncText("needsResync")) { merging = pair } }
                        Divider()
                        Button(syncText("remove"), role: .destructive) { removing = pair }
                    } label: { Image(systemName: "ellipsis.circle") }
                        .accessibilityLabel(syncText("more"))
                    Spacer()
                }.disabled(engine.busy || engine.storageError != nil)
            }
            if let message = pair.lastMessage, pair.lastOutcome != "verified" {
                Text(SyncDiagnostic.clean(message)).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if let until = engine.cooldownUntil(for: pair) {
                Label(syncText("failure.quota.title"), systemImage: "hourglass").font(.caption).foregroundStyle(.secondary)
                retryTime(until)
            }
            if let date = pair.lastRun {
                Text("\(syncText("verified")) : \(date.formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundStyle(.secondary)
            }
            if let date = pair.nextRetryAt {
                Text("\(syncText("retryAt")) \(date.formatted(date: .omitted, time: .standard))").font(.caption).foregroundStyle(.secondary)
            }
            if engine.queue.contains(where: { $0.pairID == pair.id }) { Label(syncText("queued"), systemImage: "clock").font(.caption) }
        }.padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    /// Dedicated per-pair status dashboard: current state, last run, verification and next planned action.
    private var statusDashboard: some View {
        VStack(spacing: 12) {
            if !engine.pairs.isEmpty { queueHeader }
            if engine.pairs.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "waveform.path.ecg.rectangle").font(.system(size: 36)).foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(syncText("empty")).font(.headline)
                    Text(syncText("emptyBody")).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(32)
            }
            ForEach(engine.pairs) { statusCard($0) }
        }
    }
    private var queueHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(syncText("queueTitle"), systemImage: "list.number").font(.headline)
                Spacer()
                if engine.inventoryBusy { HStack(spacing: 6) { ProgressView().controlSize(.small); Text(syncText("counting")) }.font(.caption).foregroundStyle(.secondary) }
                Button { engine.refreshAllInventories() } label: { Label(syncText("refreshCounts"), systemImage: "arrow.clockwise") }
                    .controlSize(.small)
                    .disabled(engine.inventoryBusy || engine.busy || engine.pairs.isEmpty || engine.storageError != nil)
            }
            if engine.busy, let id = engine.runningPairID, let pair = engine.pairs.first(where: { $0.id == id }) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("\(pair.name) — \(engine.progressText)").font(.caption).lineLimit(2)
                }
            }
            let queued = engine.queue.compactMap { job in engine.pairs.first(where: { $0.id == job.pairID }) }
            if engine.busy || !queued.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(queued.enumerated()), id: \.offset) { index, pair in
                        HStack(spacing: 8) {
                            Text("\(index + 1).").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 20, alignment: .trailing)
                            Text(pair.name).font(.caption)
                            if let job = engine.queue.first(where: { $0.pairID == pair.id }) {
                                Text(job.dryRun ? syncText("simulating") : syncText("sync")).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text(engine.isPaused ? syncText("pausedAll") : syncText("queueEmpty"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
    private func statusCard(_ pair: SyncPair) -> some View {
        let lastRun = engine.runs.first { $0.pair.id == pair.id }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: engine.runningPairID == pair.id ? "arrow.triangle.2.circlepath" : pair.previewOnly ? "eye" : "folder.fill")
                    .foregroundStyle(Color.accentColor).font(.title3).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pair.name).font(.headline)
                    Text("\(shortPath(pair.localPath))  \(pair.direction.arrow)  \(pair.destinationDescription)")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer(minLength: 8)
                status(currentStateKey(pair))
            }
            VStack(alignment: .leading, spacing: 7) {
                infoRow(syncText("mode"), "\(pair.previewOnly ? syncText("previewOnly") : syncText("realTransfers")) · \(pair.direction.label)")
                if engine.runningPairID == pair.id {
                    infoRow(syncText("state"), "\(syncText(engine.isDryRun ? "simulating" : "running")) — \(engine.progressText)")
                } else {
                    infoRow(syncText("state"), stateText(pair))
                }
                if let run = lastRun {
                    infoRow(syncText("lastRunLabel"), "\(run.started.formatted(date: .abbreviated, time: .standard)) · \(syncText(run.outcome))\(run.dryRun ? " · \(syncText("simulating"))" : "")")
                }
                infoRow(syncText("verified"), pair.lastRun.map { $0.formatted(date: .abbreviated, time: .standard) } ?? syncText("idle"))
                if let date = pair.nextRetryAt {
                    infoRow(syncText("retryAt"), date.formatted(date: .omitted, time: .standard))
                }
                if let until = engine.cooldownUntil(for: pair) {
                    infoRow(syncText("retryAfter"), until.formatted(date: .omitted, time: .shortened))
                }
                inventoryRows(pair)
            }
            if engine.runningPairID == pair.id {
                HStack {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel(syncText(engine.isDryRun ? "simulating" : "running"))
                    Spacer()
                    Button(syncText("stop")) { engine.stopRunning() }
                }
            } else {
                HStack {
                    Button { engine.syncPair(pair.id, dryRun: true); tab = "history" } label: { Label(syncText("simulate"), systemImage: "eye") }
                        .disabled(!pair.enabled || engine.cooldownUntil(for: pair) != nil)
                    Button(syncText(pair.previewOnly || pair.needsResync && pair.direction.usesBisync ? "startSync" : "sync")) {
                        if pair.previewOnly || pair.needsResync && pair.direction.usesBisync { merging = pair }
                        else { engine.syncPair(pair.id) }
                    }
                    .disabled(!pair.enabled || engine.cooldownUntil(for: pair) != nil)
                    Spacer()
                    Button { editing = pair } label: { Label(syncText("edit"), systemImage: "slider.horizontal.3") }
                        .accessibilityLabel(syncText("edit"))
                }.controlSize(.small).disabled(engine.busy || engine.storageError != nil)
            }
        }.padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
    /// Real file/byte counts per side (rclone size, same exclusions), gap highlighted, honest ETA.
    @ViewBuilder private func inventoryRows(_ pair: SyncPair) -> some View {
        let inventory = engine.inventories[pair.id]
        Divider().padding(.vertical, 2)
        HStack(alignment: .firstTextBaseline) {
            Text(syncText("inventory")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            Button { engine.refreshInventory(pair.id) } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).font(.caption).foregroundStyle(Color.accentColor)
                .help(syncText("refreshCounts")).accessibilityLabel(syncText("refreshCounts"))
                .disabled(engine.inventoryBusy || engine.busy || engine.storageError != nil)
        }
        HStack(spacing: 24) {
            inventorySide(syncText("localSide"), files: inventory?.localFiles, bytes: inventory?.localBytes, at: inventory?.localAt)
            Image(systemName: pair.direction.arrow == "⇄" ? "arrow.left.arrow.right" : pair.direction.arrow == "↑" ? "arrow.up" : "arrow.down")
                .font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
            inventorySide(syncText("remoteSide"), files: inventory?.remoteFiles, bytes: inventory?.remoteBytes, at: inventory?.remoteAt,
                          deferred: inventory?.remoteDeferred == true)
        }
        if let inventory, inventory.gapFiles != nil {
            if inventory.aligned {
                Label(syncText("aligned"), systemImage: "checkmark.seal.fill").font(.callout.weight(.medium)).foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Label("\(syncText("gap")) : \(inventory.gapFiles!) \(syncText("files")) · \(Self.byteText(inventory.gapBytes ?? 0))",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.weight(.medium)).foregroundStyle(.orange)
                    Label("\(syncText("estimateLabel")) : \(Self.etaText(inventory.gapBytes ?? 0))",
                          systemImage: "clock.badge.checkmark")
                        .font(.callout).foregroundStyle(.secondary)
                    Text(syncText("gapNote")).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            Label(syncText("gapMissing"), systemImage: "questionmark.circle").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func inventorySide(_ label: String, files: Int?, bytes: Int64?, at: Date?, deferred: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            if let files {
                Text("\(files) \(syncText("files")) · \(Self.byteText(bytes ?? 0))").font(.system(.caption, design: .monospaced))
                if let at { Text("\(syncText("countedAt")) \(at.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary) }
            } else if deferred {
                Text(syncText("remoteDeferred")).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("—").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    static func byteText(_ bytes: Int64) -> String { SyncEngine.byteText(bytes) }
    /// Duration to reconcile the size gap at the reference throughput. Explicitly a rough figure:
    /// modified-on-both-sides files and per-file overhead are unknown without a preview.
    static func etaText(_ gapBytes: Int64) -> String { SyncEngine.etaText(gapBytes) }

    private func currentStateKey(_ pair: SyncPair) -> String {
        if engine.runningPairID == pair.id { return engine.isDryRun ? "simulating" : "running" }
        if engine.queue.contains(where: { $0.pairID == pair.id }) { return "queued" }
        if !pair.enabled { return "pairPaused" }
        if engine.cooldownUntil(for: pair) != nil { return "rateLimited" }
        if engine.isPaused { return "pausedAll" }
        return pair.lastOutcome
    }
    private func stateText(_ pair: SyncPair) -> String { syncText(currentStateKey(pair)) }
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
            Text(value).font(.caption).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }

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
    init(original: SyncPair, engine: SyncEngine) {
        self.original = original; self.engine = engine
        _pair = State(initialValue: original)
        _ignores = State(initialValue: original.ignores.joined(separator: "\n"))
        _destinationMethod = State(initialValue: original.driveFolderID != nil || original.localPath.isEmpty ? "link" : "path")
        _folderLink = State(initialValue: original.driveFolderID.map { "https://drive.google.com/drive/folders/\($0)" } ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(syncText("title")).font(.title2.bold())
            Form {
                Section(syncText("local")) {
                    TextField(syncText("name"), text: $pair.name)
                    HStack {
                        TextField(syncText("local"), text: $pair.localPath)
                        Button(syncText("choose")) { choose() }
                    }
                }
                Section(syncText("driveDestination")) {
                    HStack {
                        LabeledContent(syncText("driveAccount"), value: pair.remote)
                        Link(destination: browserDriveURL) { Label(syncText("openDrive"), systemImage: "arrow.up.right.square") }
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
            }.formStyle(.grouped).scrollContentBackground(.hidden)
            if let error { Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Text(syncText("safe")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(syncText("cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(syncText("save")) { save() }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 580, height: 640)
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
