# Landing PKarchives — source et dossier déployable

`index.html` est la landing. Le dossier `media/` contient les trois fichiers nécessaires
à sa version normale. Pour publier cette version, envoyer `index.html` et `media/` ensemble.

```text
store/website/
├── index.html
└── media/
    ├── background.jpg
    ├── film-poster.jpg
    └── ultracrea2-promo.mp4
```

Pour fabriquer une variante réellement constituée d'un seul fichier HTML (images et vidéo
incluses), lancer `scripts/build-standalone.sh`. Le résultat fait environ 3,6 Mo et s'écrit
ici sous `index-standalone.html` ; il est généré localement et n'est pas commité.

Les maîtres du media-kit restent dans `store/media/`. Si un média de la landing change,
mettre à jour sa copie dans `media/` également.
