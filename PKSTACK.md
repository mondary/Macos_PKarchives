# PKSTACK — Skills investies dans PKarchives

Cartographie des skills du hub Agent (`~/Documents/GitHub/-agent`) utilisées sur ce dépôt,
et de ce qu'elles y ont produit. Convention : `pk-commits`. Mettre à jour ce fichier
quand une nouvelle skill intervient sur le projet.

| Skill | Rôle ici | Livrables dans ce dépôt |
|---|---|---|
| `premium-promo-media` | Landing produit + kit média | `store/website/index.html` (landing Ultra Crea 3, source et dossier FTP déployable) ; `store/media/` (bannière 1544×500, cards OG, captures, GIF d'interface, film promo) ; pipeline de génération archivé dans `store/archive/media-kit/` |
| `pk-app-release` | Release macOS complète | Release GitHub `v2026.10.12` (DMG + installateur `.pkg` Apple Silicon, liens directs versionnés) ; `.github/workflows/release.yml` ; `.github/scripts/release.sh` |
| `pkhomebrew` | Cask Homebrew du tap | `Casks/pkarchives.rb` du dépôt `mondary/homebrew-tap` (URL versionnée + SHA-256 du DMG publié) ; commandes `brew` de la landing et des README |
| `pk-commits` | Convention commits & versioning | Préfixes `ADD`/`FIX`/`REFACTO`/`MAJ` ; CalVer `YYYY.MM.PATCH` avec `CHANGELOG.md` comme source de vérité ; checklist Ko-fi (READMEs + landing + app) et exigence landing bilingue |
| `fixing-accessibility` | Corrections accessibilité | `aria-label` des boutons et contrôles icône seule ; sémantique du menu 📦 (`role="menu"`, `aria-expanded`, fermeture au clic extérieur) ; navigation clavier et focus visibles ; contrastes |
| `sparkle-github-updates` | Mises à jour automatiques | `Sparkle.framework` embarqué par `scripts/build.sh` ; `SUPublicEDKey`/`SUFeedURL` dans l'app ; appcast neutralisé dans `appcast.xml` en attente d'une vraie signature |

## Outils annexes (hors hub, sans skill dédiée)

- **Design Mode** (extension + MCP `design-mode`) : retouches visuelles faites en direct dans le
  navigateur puis relayées dans la landing (largeur FAQ, libellés de boutons, espacements).
- **Playwright + Chrome headless** : vérifications automatisées du rendu (1440/809/390 px,
  débordements, animation du hero, liens de téléchargement).

## En attente

- Landing bilingue FR/EN avec détection `navigator.language` + bascule manuelle
  (`premium-promo-media` § bilingue) — non implémentée à ce jour.
- Signature EdDSA Sparkle : aucune mise à jour n'est annoncée tant que le secret
  `SPARKLE_PRIVATE_KEY` n'est pas configuré (`sparkle-github-updates`).
