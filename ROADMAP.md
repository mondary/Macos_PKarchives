# PKarchives Roadmap

## Objectif

Faire de PKarchives un archivage visible, prévisible et réversible, sans
décommissionner la v1 avant validation de la v2.

## Phase 1 — v2 interface visuelle

- [x] Créer une application v2 à côté de la v1.
- [x] Ajouter une interface 2D animée avec source Bureau et destination Google Drive.
- [x] Afficher les fichiers sous forme de cartes avec aperçu ou icône de repli.
- [x] Afficher un extrait lisible pour les fichiers texte et une miniature pour les images.
- [x] Animer le déplacement d'une carte vers Drive après upload confirmé.
- [x] Afficher la suppression de la copie locale par un fantôme et des particules.
- [x] Afficher la progression réelle de l'upload.
- [x] Conserver la configuration partagée avec la CLI.
- [x] Utiliser un journal d'événements append-only pour éviter les courses de polling.
- [x] Ne pas imposer de rendu 3D : privilégier une interface sobre et lisible.
- [ ] Tester la v2 sur de vrais fichiers représentatifs et plusieurs tailles de Bureau.

## Phase 2 — compteur live du menu bar

- [ ] Afficher dans l'icône du menu bar le nombre d'éléments potentiellement archivables.
- [ ] Calculer ce nombre avec exactement les mêmes règles que `archive.sh` : exclure `.DS_Store`, le point de montage `DesktopArchive`, les éléments tagués `Bureau`, et respecter le mode `fichiers` ou `fichiers + dossiers`.
- [ ] Rafraîchir le compteur périodiquement, avec une première valeur au lancement.
- [ ] Utiliser un intervalle par défaut de 5 minutes, avec un refresh immédiat après une archive, un changement de configuration ou une action menu bar.
- [ ] Prévoir une action de refresh manuel depuis le menu bar.
- [ ] Afficher un état explicite quand le scan est en cours ou indisponible.
- [ ] Ne pas compter les éléments déjà ignorés par le moteur d'archivage.

## Phase 3 — validation et remplacement

- [ ] Comparer v1 et v2 sur upload réussi, échec réseau, annulation et suppression.
- [ ] Vérifier que l'historique reste compatible avec la CLI et la v1.
- [ ] Vérifier le comportement avec fichiers, dossiers, noms accentués et gros fichiers.
- [ ] Valider les performances du scan et des vignettes sur un Bureau chargé.
- [ ] Choisir la v2 comme interface par défaut après validation.
- [ ] Garder une procédure de retour temporaire vers la v1.
- [ ] Décommissionner la v1 seulement après une version stable et un test utilisateur concluant.

## Décisions à prendre

- Fréquence exacte du scan périodique : 1, 5 ou 15 minutes après mesure du coût.
- Affichage du compteur : nombre brut, badge sur l'icône, ou entrée détaillée dans le menu.
- Mode affiché par défaut : fichiers seuls ou dernier mode utilisé.

## Mode Synchronisation — Dev 2026.10.46

- [x] Paires natives macOS, directions ⇄/↑/↓ et exclusions.
- [x] Deux onglets principaux Archivage/Synchronisation, navigation directe et panneau de barre des menus au clic/droit/survol.
- [x] Version installée complète visible dans le panneau de l’icône, y compris le suffixe Dev.
- [x] Archivage en premier et par défaut au démarrage ; Synchronisation en second, indépendante de l’onglet affiché.
- [x] Simulation par paire/globale, sans modification des fichiers ni des listings actifs.
- [x] Première fusion explicite, conflits et copies de récupération séparées.
- [x] Contrôle après transfert ; aucun état vérifié sans taille et empreinte disponibles.
- [x] Journal lisible, rapports durables et historique relançable.
- [x] Activité avec causes lisibles, détails techniques repliés et quota API distinct d’un besoin de reconstruction bisync ; attente de 15 min par connexion.
- [x] Section Synchronisation dans les Réglages (pause globale, mode par défaut des nouvelles paires, réglages par paire) et segment Statut dédié par paire dans l’onglet Synchronisation.
- [x] Suivi live par exécution : phase, fichiers et volume, vitesse, temps restant, push/pull/suppressions prévus et réalisés.
- [x] Inventaire par paire dans Statut : comptages locaux/distants (rclone size, mêmes exclusions), écart mis en évidence, estimation de durée annoncée comme approximation, file d’attente visible.
- [x] Reprises temporisées, queue séquentielle, annulation et garde-fous de persistance/interruption.
- [x] FSEvents, délai local de 45 s, contrôle distant horaire/au réveil.
- [x] Build Dev locale et tests d’intégration sur remotes locaux isolés.
- [x] Petite paire réelle Google Drive : simulation, première fusion, réconciliation bidirectionnelle et contrôle à 0 différence (27/10, dossier de test purgé).
- [ ] Validation restante : gros dossiers, OAuth expiré, coupure réseau et quota sous charge, sans utiliser les archives personnelles.
- [ ] Mesures RAM/CPU représentatives et QA interactive complète des réglages.
- [ ] Validation utilisateur avant publication Stable et mise à jour des supports publics.
