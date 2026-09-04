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
