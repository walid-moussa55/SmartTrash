# SmartTrash API

SmartTrash API est une plateforme de gestion intelligente des déchets, permettant la collecte, l’analyse et la prédiction des données issues de poubelles connectées. Elle intègre des fonctionnalités avancées telles que la prédiction de remplissage, la gestion des notifications, la génération de rapports et l’optimisation des tournées de collecte.

## Fonctionnalités principales

- **Collecte de données en temps réel** : Synchronisation avec Firebase RTDB pour récupérer et stocker les données des poubelles.
- **Stockage MongoDB** : Les données des poubelles sont persistées dans une base MongoDB pour l’analyse et l’historique.
- **Prédictions avancées** :
  - Prédiction du niveau de remplissage (`predictionLvl`)
  - Prédictions hebdomadaires (7 jours) pour la planification des ressources
  - Prédiction du type de déchet par image (DenseNet201) avec modèle ML
- **Notifications intelligentes** : Envoi de notifications via Firebase Cloud Messaging avec :
  - Alertes de remplissage des poubelles
  - Détection avancée des niveaux de gaz avec sévérité et recommandations
  - Notifications d'urgence pour les niveaux critiques
- **Optimisation des tournées** : Calcul d'itinéraires optimaux pour la collecte des déchets.
- **Génération de rapports** : Création de rapports PDF et Markdown sur l'état du parc de poubelles et les anomalies détectées.
- **API RESTful** : Exposition de multiples endpoints pour la gestion, l'analyse et la consultation des données.
- **Interface web** : Un dashboard HTML/JS pour visualiser et interagir avec les données.
- **Système de gamification** :
  - Calcul de bonus et scores basés sur le type de déchet
  - Coefficients de récompense pour chaque type (papier, plastique, verre, métal, etc.)
  - Système de tickets/loterie
- **Assistant Eco-Assistant IA** : Chatbot intelligent utilisant Mistral AI avec base de connaissances (RAG)
- **Gestion des dépôts de déchets** : Système de sessions pour suivre les dépôts avec intégration ESP32
- **Statistiques de population** : Analyses avancées incluant :
  - Utilisation des poubelles par région
  - Taux de remplissage par poubelle
  - Corrélation poids/type de déchet
  - Détection et commentaires sur les anomalies
- **Gestion des ressources** : Suivi avancé des données des poubelles en temps réel

## Structure du projet

- `run.py` : Point d’entrée principal de l’API FastAPI.
- `routers/` : Contient les routes pour la gestion des poubelles, la génération de rapports, les prédictions, le chatbot, les récompenses et les événements de dépôt.
  - `bins.py` : Routes d'optimisation et d'analyses des poubelles
  - `prediction.py` : Routes des prédictions (niveau, hebdomadaire, type de déchet)
  - `report.py` : Routes de génération de rapports
  - `chatbot.py` : Routes du chatbot Eco-Assistant IA
  - `rewards.py` : Routes de calcul de récompenses et scores
  - `deposit_event.py` : Routes de gestion des événements de dépôt
- `services/` : Services métiers (notifications, optimisation de tournées, etc.).
- `others/` : Modèles de données, accès base, statistiques, état des prédictions, etc.
- `predictions/` : Modules de prédiction (niveau, type de déchet).
- `statics/` : Fichiers statiques pour l'interface web (HTML, JS, CSS) et base de connaissances.
- `utils/` : Fonctions utilitaires et constantes.
- `reports/` : Génération de rapports, analyses avancées et commentaires d'anomalies.

## Principaux endpoints API

- `/` : Accueil de l’API.
- `/update/{bin_id}` : Met à jour les données d’une poubelle.
- `/read/{bin_id}` : Récupère les données d’une poubelle.
- `/prediction` : Obtient les prédictions de niveau de remplissage actuelles.
- `/prediction/weekly` : Obtient les prédictions de remplissage pour 7 jours avec planification des ressources.
- `/predict/trash_type` : Prédiction du type de déchet à partir d'une image (ML - DenseNet201).
- `/optimize` : Optimisation de la tournée de collecte.
- `/generate-report` : Génère un rapport PDF.
- `/bin-analytics` : Analyses avancées sur les poubelles.
- `/resource-management` : Données de gestion des ressources des poubelles.
- `/api/population-by-bin` : Statistiques d'utilisation par poubelle.
- `/api/chat` : Endpoint du chatbot Eco-Assistant IA avec capacités RAG.
- `/reward/deposit` : Calcul de récompenses et bonus pour les dépôts de déchets.
- `/reward/user/{user_id}` : Récupère le score utilisateur et l'état de récompense.
- `/deposit/session` : Enregistrement d'une session de dépôt (Flutter → API).
- `/deposit/close` : Fermeture d'une session de dépôt (ESP32 → API).

## Démarrage rapide

1. **Installer les dépendances** :
   ```sh
   pip install -r requirements.txt
   ```
2. **Configurer Firebase** :
   - Créez un projet sur [Firebase Console](https://console.firebase.google.com/).
   - Accédez à "Paramètres du projet" > "Comptes de service".
   - Cliquez sur "Générer une nouvelle clé privée" pour obtenir le fichier JSON.
   - Placez ce fichier sous le nom `firebase_key.json` dans le dossier `statics/`.
   - Définissez l’URL de la base de données dans le fichier des constantes (`utils/constants.py`).

3. **Configurer l'Eco-Assistant IA** :
   - Créez un compte sur [Mistral AI](https://console.mistral.ai/).
   - Générez une clé API et ajoutez-la dans le fichier `.env` : `MISTRAL_API_KEY=<votre_cle_api>`
   - Configurez optionnellement le modèle Mistral en définissant : `MISTRAL_MODEL=mistral-small-latest`
   - Assurez-vous que le fichier de base de connaissances existe : `statics/knowledge_base.txt`

4. **Lancer le serveur** :
   ```sh
   python run.py
   ```
   ou
   ```sh
   uvicorn run:app --reload
   ```

5. **Accéder à l'interface web** :
   - Ouvrir `statics/index.html` dans un navigateur.

## Technologies utilisées

- Python 3, FastAPI, Uvicorn
- MongoDB, Firebase RTDB & FCM, Mistral AI
- Pandas, threading, asyncio, PyMongo
- HTML/JS/CSS pour l'interface utilisateur
- PyPDF2 pour la génération de rapports
- Pydantic pour la validation des données

## Fonctionnalités avancées

### 1. Système de Gamification
Le système de récompenses encourage les utilisateurs à correctement trier les déchets :
- **Calcul de bonus** : Les bonus sont calculés en fonction du type de déchet avec des coefficients spécifiques.
- **Types de déchets supportés** : papier (1.0x), carton (1.0x), plastique (2.0x), verre (3.0x), métal (4.0x), organique (0.5x), aliments (0.5x).
- **Tickets/Loterie** : Les utilisateurs peuvent gagner des tickets en accumulant un score seuil.

### 2. Assistant Eco-Assistant IA
L'assistant utilise Mistral AI avec Retrieval-Augmented Generation (RAG) :
- Accède à une base de connaissances pour répondre aux questions sur le tri et l'environnement.
- Génère des recommandations personnalisées en fonction du contexte utilisateur.
- Endpoint : `POST /api/chat` pour les interactions conversationnelles.

### 3. Prédictions Avancées
- **Prédictions hebdomadaires** : Permet de prédire le niveau de remplissage pour 7 jours afin de planifier les tournées de collecte.
- **Planification des ressources** : Aide à allouer les ressources de collecte de manière optimale.
- **Prédiction du type de déchet** : Utilise un modèle DenseNet201 pour classifier le type de déchet à partir d'une image. Endpoint : `POST /predict/trash_type` avec un fichier image.

### 4. Détection des Niveaux de Gaz
- Monitore les niveaux de gaz dans les poubelles en temps réel.
- Envoie des notifications avec niveaux de sévérité et recommandations.
- Notifications d'urgence pour les niveaux critiques.

### 5. Gestion des Événements de Dépôt
- Système de sessions pour synchroniser Flutter (application mobile) et ESP32 (microcontrôleur).
- Suivi complet du cycle de vie d'un dépôt de déchet.
- Intégration directe avec le système de récompenses.

## Auteurs

- WAM Development

## Liens utiles

- [Documentation FastAPI](https://fastapi.tiangolo.com/fr/)
- [Documentation Firebase Admin Python](https://firebase.google.com/docs/admin/setup?hl=fr)
- [Documentation MongoDB Python (PyMongo)](https://pymongo.readthedocs.io/en/stable/)
- [Mistral AI Documentation](https://docs.mistral.ai/)
- [Uvicorn](https://www.uvicorn.org/)
- [Pandas](https://pandas.pydata.org/docs/)
- [Console Firebase](https://console.firebase.google.com/)
- [Documentation Python](https://docs.python.org/fr/3/)

---

**SmartTrash** : Optimisez la gestion urbaine des déchets grâce à la donnée et à l’intelligence artificielle !

---