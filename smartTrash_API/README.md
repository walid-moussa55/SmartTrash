# SmartTrash API

SmartTrash API est une plateforme de gestion intelligente des déchets, permettant la collecte, l’analyse et la prédiction des données issues de poubelles connectées. Elle intègre des fonctionnalités avancées telles que la prédiction de remplissage, la gestion des notifications, la génération de rapports et l’optimisation des tournées de collecte.

## Fonctionnalités principales

- **Collecte de données en temps réel** : Synchronisation avec Firebase RTDB pour récupérer et stocker les données des poubelles.
- **Stockage MongoDB** : Les données des poubelles sont persistées dans une base MongoDB pour l’analyse et l’historique.
- **Prédictions avancées** :
  - Prédiction du niveau de remplissage (`predictionLvl`)
  - Prédiction température/humidité (`predictionTH`)
- **Notifications intelligentes** : Envoi de notifications via Firebase Cloud Messaging lorsque certains seuils sont atteints.
- **Optimisation des tournées** : Calcul d’itinéraires optimaux pour la collecte des déchets.
- **Génération de rapports** : Création de rapports PDF et Markdown sur l’état du parc de poubelles et les anomalies détectées.
- **API RESTful** : Exposition de multiples endpoints pour la gestion, l’analyse et la consultation des données.
- **Interface web** : Un dashboard HTML/JS pour visualiser et interagir avec les données.

## Structure du projet

- `run.py` : Point d’entrée principal de l’API FastAPI.
- `routers/` : Contient les routes pour la gestion des poubelles, la génération de rapports et les prédictions.
- `services/` : Services métiers (notifications, etc.).
- `others/` : Modèles de données, accès base, statistiques, etc.
- `predictions/` : Modules de prédiction (niveau, température/humidité).
- `statics/` : Fichiers statiques pour l’interface web (HTML, JS, CSS).
- `utils/` : Fonctions utilitaires et constantes.
- `reports/` : Génération de rapports et analyses avancées.

## Principaux endpoints API

- `/` : Accueil de l’API.
- `/update/{bin_id}` : Met à jour les données d’une poubelle.
- `/read/{bin_id}` : Récupère les données d’une poubelle.
- `/prediction/ht` : Prédictions température/humidité.
- `/optimize` : Optimisation de la tournée de collecte.
- `/generate-report` : Génère un rapport PDF.
- `/bin-analytics` : Analyses avancées sur les poubelles.
- `/api/population-by-bin` : Statistiques d’utilisation par poubelle.

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

3. **Lancer le serveur** :
   ```sh
   python run.py
   ```
   ou
   ```sh
   uvicorn run:app --reload
   ```

4. **Accéder à l’interface web** :
   - Ouvrir `statics/index.html` dans un navigateur.

## Technologies utilisées

- Python 3, FastAPI, Uvicorn
- MongoDB, Firebase RTDB & FCM
- Pandas, threading, asyncio
- HTML/JS/CSS pour l’interface utilisateur

## Auteurs

- WAM Development

## Liens utiles

- [Documentation FastAPI](https://fastapi.tiangolo.com/fr/)
- [Documentation Firebase Admin Python](https://firebase.google.com/docs/admin/setup?hl=fr)
- [Documentation MongoDB Python (PyMongo)](https://pymongo.readthedocs.io/en/stable/)
- [Uvicorn](https://www.uvicorn.org/)
- [Pandas](https://pandas.pydata.org/docs/)
- [Console Firebase](https://console.firebase.google.com/)
- [Documentation Python](https://docs.python.org/fr/3/)

---

**SmartTrash** : Optimisez la gestion urbaine des déchets grâce à la donnée et à l’intelligence artificielle !

---