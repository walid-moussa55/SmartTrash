# NaqiAI

NaqiAI est une application Flutter complète de gestion intelligente des déchets, conçue pour la visualisation en temps réel, l'analyse des données et l'optimisation de la collecte urbaine des déchets. Elle intègre des fonctionnalités avancées incluant le suivi en direct, l'analyse des données, la génération de rapports, les notifications push, les recommandations alimentées par l'IA, l'optimisation des routes et les prédictions de déchets.

---

## Fonctionnalités Clés

### 1. **Tableau de Bord Dynamique**
- **Aperçu** des niveaux de remplissage des bacs, des lectures de gaz, de la température, de l'humidité, et bien plus.
- **Graphiques interactifs** (Syncfusion, fl_chart) pour visualiser les tendances, les corrélations et les distributions.
- **Indicateurs clés** : nombre de bacs pleins, camions requis, employés nécessaires, etc.

### 2. **Analyse Avancée**
- **Analyse de la population** : corrélation entre l'utilisation des bacs et la population par zone.
- **Analyse environnementale** : suivi des niveaux de gaz, température, humidité et alertes environnementales.
- **Analyse des motifs** : rapports Markdown dynamiques générés côté serveur (NLP, tendances, etc.).
- **Recommandations sur les anomalies** : suggestions d'actions automatiques lors de la détection d'anomalies (IA).

### 3. **Assistant Écologique IA**
- **Assistant IA conversationnel** pour les requêtes de gestion des déchets et les conseils environnementaux.
- **Support de l'entrée vocale** via la conversion parole-texte pour une interaction sans mains.
- Fournit des conseils intelligents, répond aux questions et interprète les résultats des données.

### 4. **Prédiction de Déchets**
- **Prédiction du niveau de remplissage des bacs** : prévoit quand les bacs atteindront leur capacité en fonction des données historiques.
- **Prédiction du type de déchets** : identifie la catégorie de déchets pour un tri et un routage plus intelligents.
- **Recherche intelligente de bacs** : permet de rechercher et de filtrer les bacs en fonction de l'état prédit.

### 5. **Optimisation des Routes**
- **Routes de collecte optimisées** générées automatiquement selon les niveaux de remplissage des bacs et la localisation.
- **Carte interactive des routes** pour visualiser et naviguer les routes de collecte planifiées.
- Intègre OpenStreetMap (`flutter_osm_plugin`) pour le rendu des cartes en direct.
- Utilise la localisation GPS (`geolocator`) pour activer le suivi de position en temps réel.

### 6. **Génération et Visualisation de Rapports**
- **Génération de rapports PDF à la demande**, téléchargeables sur mobile et web.
- **Visionneuse PDF intégrée** pour consulter les rapports directement dans l'application (mobile/desktop).

### 7. **Notifications Push**
- **Notifications push** via Firebase Cloud Messaging pour les alertes critiques (bacs pleins, niveaux de gaz élevés, etc.).
- **Support des notifications locales** via `flutter_local_notifications`.

### 8. **Gestion des Utilisateurs**
- **Authentification** (Firebase Auth) avec écrans de connexion et d'inscription.
- **Gestion des rôles** (admin/utilisateur) pour le contrôle d'accès aux fonctionnalités avancées.
- **Écran des paramètres de profil** pour gérer les informations du compte utilisateur.

### 9. **Thème et Personnalisation**
- **Support du mode sombre/clair** avec un fournisseur de thème dynamique.
- **Intégration de Google Fonts** pour une typographie moderne et cohérente.
- Préférences utilisateur sauvegardées via SharedPreferences.

### 10. **Gamification** *(Nouveau)*
- **Système de points et de récompenses** pour encourager les utilisateurs à participer à la gestion des déchets.
- **Tableau de bord de gamification** affichant le score utilisateur, les badges et les accomplissements.
- **Suivi des performances** avec `user_score_service` pour les statistiques de gamification.

### 11. **Scan de Code QR** *(Nouveau)*
- **Scanner QR intégré** pour identifier rapidement les bacs via codes QR.
- **Intégration mobile_scanner** pour la capture et la détection de codes QR.
- Permet l'interaction directe et sans friction avec les bacs intelligents.

### 12. **Paramètres de l'Application**
- **Configuration dynamique de l'URL du serveur** via l'interface de l'application.
- **Persistance des préférences utilisateur** (SharedPreferences).

---

## Architecture Technique

- **Flutter** (multiplateformes : Web, Android, iOS, Desktop)
- **Serveur Principal** : API REST (ex: FastAPI, Flask) pour l'agrégation et l'analyse des données
- **Firebase** : Auth, Base de Données en Temps Réel, Cloud Messaging
- **Syncfusion** & **fl_chart** : visualisation avancée des données
- **OpenStreetMap** (`flutter_osm_plugin`) : rendu de cartes interactives
- **Geolocator** : positionnement en temps réel basé sur GPS
- **Speech-to-Text** (`speech_to_text`) : entrée vocale pour l'Assistant Écologique
- **Mobile Scanner** (`mobile_scanner`) : scanner de codes QR intégré
- **Gestion des permissions** : stockage, notifications, localisation, microphone, etc.

---

## Structure des Écrans Principaux

| Fichier | Description |
|---|---|
| `main.dart` | Point d'entrée de l'application, initialisation du thème et Firebase |
| `home_screen.dart` | Hub de navigation principal |
| `login_screen.dart` | Connexion utilisateur |
| `signup_screen.dart` | Inscription utilisateur |
| `waste_dashboard.dart` | Tableau de bord avec graphiques et KPIs |
| `analyse_population_tab.dart` | Analyse démographique et corrélations |
| `anomaly_recommendation_screen.dart` | Recommandations basées sur l'IA pour les anomalies |
| `patterns_analysis_viewer_screen.dart` | Visualiseur d'analyse dynamique Markdown |
| `eco_assistant_screen.dart` | Assistant IA Écologique conversationnel (voix + texte) |
| `prediction_screen.dart` | Prédictions du niveau de remplissage des bacs |
| `type_prediction_screen.dart` | Prédiction du type de déchets |
| `map_screen.dart` | Carte interactive OSM des bacs |
| `optimized_route_screen.dart` | Affichage des routes de collecte optimisées |
| `route_map_screen.dart` | Carte de navigation des routes |
| `final_rapport_generation_screen.dart` | Génération et visualisation des rapports PDF |
| `profile_settings_screen.dart` | Gestion du profil utilisateur |
| `gamification_screen.dart` | Système de récompenses et tableau de bord de gamification *(Nouveau)* |
| `qr_scan_screen.dart` | Scanner de codes QR pour identifier les bacs *(Nouveau)* |
| `app_settings.dart` | Paramètres de l'application et configuration de l'URL du serveur |
| `theme_provider.dart` | Fournisseur de thème sombre/clair |

---

## Installation et Configuration

1. **Cloner le dépôt**

2. **Configurer Firebase**

   Pour connecter NaqiAI à Firebase :

   1. **Créer un projet Firebase**  
      Allez à [https://console.firebase.google.com/](https://console.firebase.google.com/), créez un projet et suivez l'assistant de configuration.

   2. **Ajouter une application à votre projet**  
      - Pour web : ajoutez une application web et récupérez la configuration (`apiKey`, `authDomain`, etc.).
      - Pour Android/iOS : ajoutez les applications correspondantes et téléchargez les fichiers de configuration :
        - `google-services.json` (Android)
        - `GoogleService-Info.plist` (iOS)

   3. **Placer les fichiers de configuration dans le projet Flutter**  
      - **Web** : Placez la configuration dans `web/firebase-config.js`.
      - **Mobile** :
        - `google-services.json` → `android/app/`
        - `GoogleService-Info.plist` → `ios/Runner/`

   4. **Activer les services Firebase requis**  
      - Authentification (Email/Mot de passe, etc.)
      - Base de Données en Temps Réel ou Firestore
      - Cloud Messaging (pour les notifications push)

   5. **Vérifier l'intégration**  
      Lancez l'application — si elle est configurée correctement, Firebase se connectera automatiquement.

   > **Conseil** :  
   > Des fichiers de configuration exemple sont déjà fournis (`firebase_options_web.dart`, `firebase-config.js`).  
   > Remplacez-les par les clés et identifiants de votre propre projet Firebase.

3. **Configurer l'URL du serveur principal** dans l'écran des paramètres de l'application.

4. **Installer les dépendances**
   ```sh
   flutter pub get
   ```

5. **Exécuter l'application**
   ```sh
   flutter run -d chrome      # Web
   flutter run -d android     # Android
   flutter run -d ios         # iOS
   ```

---

## Remarques

- L'application nécessite un serveur API REST compatible pour fonctionner pleinement.
- Les notifications push nécessitent une configuration de Firebase Cloud Messaging.
- Les rapports PDF sont générés côté serveur et récupérés via l'API.
- L'entrée vocale (Assistant Écologique) nécessite la permission de microphone sur l'appareil.
- Les fonctionnalités de carte et de route nécessitent les permissions de localisation et une connexion Internet pour le chargement des tuiles.

---

## Auteurs

- [WAM Development](https://github.com/walid-moussa55)

---

## Liens Utiles

- [Documentation Flutter](https://docs.flutter.dev/)
- [Widgets Syncfusion Flutter](https://github.com/syncfusion/flutter-widgets)
- [Documentation des Graphiques Syncfusion](https://help.syncfusion.com/flutter/chart/overview)
- [Documentation Firebase pour Flutter](https://firebase.flutter.dev/docs/overview)
- [Documentation FastAPI](https://fastapi.tiangolo.com/)
- [Documentation Flask](https://flask.palletsprojects.com/)
- [flutter_osm_plugin](https://pub.dev/packages/flutter_osm_plugin)
- [speech_to_text](https://pub.dev/packages/speech_to_text)
- [mobile_scanner](https://pub.dev/packages/mobile_scanner)

---

**NaqiAI** — Optimisez la gestion urbaine des déchets grâce aux données et à l'intelligence artificielle !

---
