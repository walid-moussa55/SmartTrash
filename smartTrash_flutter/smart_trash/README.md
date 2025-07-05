# SmartTrash

SmartTrash est une application Flutter complète de gestion intelligente des déchets, destinée à la visualisation, l’analyse et l’optimisation de la collecte des déchets urbains. Elle intègre des fonctionnalités avancées de suivi en temps réel, d’analyse de données, de génération de rapports, de notifications et de recommandations basées sur l’IA.

---

## Fonctionnalités principales

### 1. **Tableau de bord dynamique**
- **Vue d’ensemble** des niveaux de remplissage des poubelles, du gaz, de la température, de l’humidité, etc.
- **Graphiques interactifs** (Syncfusion, fl_chart) pour visualiser les tendances, corrélations et répartitions.
- **Indicateurs clés** : nombre de poubelles pleines, camions nécessaires, employés requis, etc.

### 2. **Analyse avancée**
- **Analyse de la population** : corrélation entre l’utilisation des poubelles et la population par zone.
- **Analyse environnementale** : suivi des niveaux de gaz, température, humidité, et alertes environnementales.
- **Analyse des patterns** : affichage de rapports Markdown dynamiques générés côté serveur (NLP, tendances, etc.).
- **Recommandations d’anomalies** : suggestions automatiques d’actions en cas de détection d’anomalies (IA).

### 3. **Génération et visualisation de rapports**
- **Génération de rapports PDF** à la demande, téléchargeables sur mobile et web.
- **Visualisation intégrée** des rapports PDF (mobile/desktop).

### 4. **Notifications**
- **Notifications push** via Firebase Cloud Messaging pour les alertes importantes (poubelles pleines, gaz élevé, etc.).

### 5. **Gestion des utilisateurs**
- **Authentification** (Firebase Auth).
- **Gestion des rôles** (admin/utilisateur) pour l’accès aux fonctionnalités avancées.

### 6. **Paramétrage**
- **Configuration dynamique** de l’URL du serveur backend via l’interface.
- **Sauvegarde des préférences** utilisateur (SharedPreferences).

---

## Architecture technique

- **Flutter** (multi-plateforme : Web, Android, iOS, Desktop)
- **Backend** : API REST (ex : FastAPI, Flask) pour l’agrégation et l’analyse des données
- **Firebase** : Auth, Realtime Database, Cloud Messaging
- **Syncfusion** & **fl_chart** : visualisation avancée des données
- **Gestion des permissions** : accès au stockage, notifications, etc.

---

## Structure des écrans principaux

- `home_screen.dart` : Accueil, navigation principale
- `waste_dashboard.dart` : Tableau de bord et visualisations
- `final_rapport_generation_screen.dart` : Génération et affichage des rapports PDF
- `analyse_population_tab.dart` : Analyse de la population et corrélations
- `anomaly_recommendation_screen.dart` : Recommandations IA en cas d’anomalies
- `patterns_analysis_viewer_screen.dart` : Affichage dynamique des analyses Markdown
- `app_settings.dart` : Gestion des paramètres et de l’URL serveur

---

## Installation & Lancement

1. **Cloner le dépôt**
2. **Configurer Firebase**

   Pour connecter SmartTrash à Firebase :

   1. **Créer un projet Firebase**  
      Rendez-vous sur [https://console.firebase.google.com/](https://console.firebase.google.com/), créez un projet et suivez les instructions.

   2. **Ajouter une application à votre projet**  
      - Pour le web : ajoutez une application web et récupérez la configuration (`apiKey`, `authDomain`, etc.).
      - Pour Android/iOS : ajoutez les applications correspondantes et suivez les instructions pour les fichiers `google-services.json` (Android) ou `GoogleService-Info.plist` (iOS).

   3. **Configurer les fichiers dans le projet Flutter**  
      - **Web** :  
        - Placez la configuration dans `web/firebase-config.js`.
      - **Mobile** :  
        - Placez `google-services.json` dans `android/app/` et/ou `GoogleService-Info.plist` dans `ios/Runner/`.

   4. **Activer les services nécessaires**  
      - Activez l’authentification (Email/Password, etc.) dans la console Firebase.
      - Activez la base de données en temps réel ou Firestore selon vos besoins.
      - Activez Cloud Messaging pour les notifications push.

   5. **Vérifier l’intégration**  
      - Lancez l’application. Si tout est bien configuré, la connexion à Firebase s’effectuera automatiquement.

   > **Astuce** :  
   > Les fichiers d’exemple de configuration sont déjà présents (`firebase_options_web.dart`, `firebase-config.js`).  
   > Adaptez-les avec vos propres clés et identifiants de projet Firebase.

3. **Configurer l’URL du serveur** dans les paramètres de l’application
4. **Installer les dépendances**
   ```sh
   flutter pub get
   ```
5. **Lancer l’application**
   ```sh
   flutter run -d chrome   # ou android/ios
   ```

---

## Remarques

- L’application nécessite un backend compatible (API REST) pour fonctionner pleinement.
- Les notifications push nécessitent une configuration Firebase Cloud Messaging.
- Les rapports PDF sont générés côté serveur et récupérés via l’API.

---

## Auteurs

- WAM development

---

## Liens utiles

- [Documentation Flutter](https://docs.flutter.dev/)
- [Dépôt officiel Syncfusion Flutter](https://github.com/syncfusion/flutter-widgets)
- [Documentation Syncfusion Charts](https://help.syncfusion.com/flutter/chart/overview)
- [Documentation Firebase pour Flutter](https://firebase.flutter.dev/docs/overview)
- [Documentation FastAPI](https://fastapi.tiangolo.com/)
- [Documentation Flask](https://flask.palletsprojects.com/)

---

**SmartTrash** : Optimisez la gestion urbaine des déchets grâce à la donnée et à l’intelligence artificielle !

---
