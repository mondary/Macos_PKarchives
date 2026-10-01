# store/website — bundle de déploiement FTP

Contenu autonome prêt à uploader tel quel sur un hébergement (structure conservée) :

```text
website/
├── index.html                ← copie de store/index.html
└── media/
    ├── background.jpg        ← fond du hero
    └── ultracrea2-promo.mp4  ← film de présentation
```

- Tout le reste (police, favicon, icônes, captures de galerie, tasses Ko-fi) est
  inline en base64 dans `index.html` — aucun autre fichier requis.
- Les statuts de release et le check Homebrew interrogent l'API GitHub en direct.
- **Maintenance** : ce dossier est un instantané. Après toute modification de
  `store/index.html`, re-copier le fichier ici (et `media/` si un média change)
  avant de re-déployer.
