# Nova Dodge 🪐

Un jeu d'arcade rapide et original : votre vaisseau tourne en orbite autour
d'une étoile, sur l'un des deux anneaux (intérieur / extérieur). Touchez
l'écran pour changer d'anneau et esquiver les astéroïdes qui bloquent votre
route. Ramassez les cristaux verts pour des points bonus. Le jeu accélère
progressivement — combien de temps allez-vous tenir ?

Construit avec [Godot Engine 4.x](https://godotengine.org/) (GDScript),
choisi car c'est le moteur le plus direct pour exporter un jeu 2D simple
vers un `.aab` Android prêt pour le Play Store, sans licence ni coût.

## Contrôles

- **Menu** : touchez l'écran pour démarrer.
- **En jeu** : touchez l'écran pour basculer entre l'anneau intérieur et
  l'anneau extérieur.
- **Game over** : touchez l'écran pour rejouer.

(Sur ordinateur, dans l'éditeur Godot, un clic gauche ou n'importe quelle
touche du clavier simule le tap.)

## Structure du projet

```
nova-dodge/
├── project.godot     # Configuration du projet (résolution portrait 720x1280)
├── icon.svg           # Icône par défaut du projet
├── Main.tscn           # Scène unique : logique + UI
├── main.gd             # Toute la logique du jeu
├── PRIVACY.md          # Modèle de politique de confidentialité (requis par Play Store)
└── .gitignore
```

## Ouvrir le projet

1. Installez [Godot 4.3+](https://godotengine.org/download) (version
   "Standard", pas besoin de la version .NET).
2. Lancez Godot, cliquez sur **Importer**, sélectionnez le fichier
   `project.godot`.
3. Appuyez sur F5 (ou le bouton ▶) pour lancer le jeu et le tester.

## Exporter vers Android / Play Store

Ceci nécessite une action de votre part (compte Google, clé de signature) —
je ne peux pas publier une application en votre nom. Voici la marche à
suivre complète :

### 1. Préparer l'environnement d'export

1. Dans Godot : **Editor > Manage Export Templates...** → téléchargez et
   installez les templates d'export correspondant à votre version de Godot.
2. Installez le [SDK Android](https://developer.android.com/studio) (via
   Android Studio, plus simple) et notez le chemin du SDK.
3. Dans Godot : **Editor > Editor Settings > Export > Android**, renseignez
   le chemin vers `Android SDK`, `adb`, `jarsigner` et `debug.keystore` (un
   `debug.keystore` est généré automatiquement par Android Studio).

### 2. Ajouter un préréglage d'export Android

1. **Project > Export...** → **Add...** → **Android**.
2. Onglet **Options > Package** : définissez un **Unique Name** au format
   inversé de domaine, par exemple `com.votrenom.novadodge` — ce nom ne
   pourra **plus jamais** être changé une fois publié sur le Play Store.
3. Renseignez **Version > Code** (entier, incrémenté à chaque mise à jour)
   et **Version > Name** (ex: `1.0.0`).
4. Onglet **Icônes** : vous pouvez fournir des icônes adaptatives
   (foreground/background) ; sinon `icon.svg` sera utilisé par défaut.

### 3. Créer une clé de signature (release keystore)

Le `debug.keystore` **ne peut pas** être utilisé pour publier sur le Play
Store. Générez votre propre clé de release (à conserver précieusement, vous
en aurez besoin pour **toutes** les futures mises à jour) :

```bash
keytool -genkey -v -keystore nova-dodge-release.keystore \
  -alias nova_dodge -keyalg RSA -keysize 2048 -validity 10000
```

Renseignez ce fichier `.keystore` (et son alias/mot de passe) dans l'onglet
**Keystore > Release** du préréglage d'export Android dans Godot.

### 4. Exporter le fichier .aab

1. Dans **Project > Export**, sélectionnez votre préréglage Android.
2. Décochez **Export With Debug**.
3. Cliquez sur **Export Project...**, choisissez le format **.aab**
   (Android App Bundle — obligatoire pour le Play Store depuis 2021), et
   exportez.

### 5. Publier sur Google Play Console

1. Créez un compte sur la [Google Play
   Console](https://play.google.com/console/) (frais unique d'environ 25$).
2. Créez une nouvelle application, renseignez la fiche du store :
   - Titre, description courte et longue.
   - Icône 512×512, image de couverture ("feature graphic") 1024×500.
   - Au moins 2 captures d'écran (portrait, prises depuis le jeu tournant
     sur un appareil ou un émulateur).
3. Remplissez le **questionnaire de classification du contenu**.
4. Renseignez un lien public vers votre politique de confidentialité —
   adaptez et hébergez le fichier `PRIVACY.md` fourni (par exemple via une
   Gist GitHub publique ou une page GitHub Pages).
5. Uploadez le fichier `.aab` dans une piste de **test interne**, testez
   sur un vrai appareil, puis promouvez vers la production quand vous êtes
   satisfait.

## Idées d'amélioration futures

- Effets sonores et musique.
- Animations de particules à la collision et à la collecte des cristaux.
- Système de classement en ligne (nécessiterait un backend).
- Thèmes de vaisseau déblocables avec le score cumulé.
