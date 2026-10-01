# website/PKarchives — landing vivante et bundle de déploiement

Ce dossier est **la seule copie** de la landing : on l'édite ici, et il se déploie
tel quel sur le FTP (le nom du dossier = le nom du projet).

```text
PKarchives/
├── index.html                ← LA landing (source unique)
├── README.md                 ← ce fichier
└── media/
    ├── background.jpg        ← fond du hero (copie déployable)
    └── ultracrea2-promo.mp4  ← film de présentation (copie déployable)
```

- Suivi par git, aucun ignore, aucun script de génération : ce qui est commité ici
  est ce qui est uploadé.
- Tout le reste (police, favicon, icônes, captures de galerie, tasses Ko-fi) est
  inline en base64 dans `index.html`.
- Les **maîtres** du media-kit (bannière, cards OG, captures, GIF, film) restent
  dans `store/media/` ; si un média de la landing change, mettre à jour la copie
  locale dans `media/` en même temps.
- Les statuts de release et le check Homebrew interrogent l'API GitHub en direct.
- Convention (skill `premium-promo-media`) : `website/<NomDuProjet>/` à la racine
  du dépôt, un dossier par projet.
