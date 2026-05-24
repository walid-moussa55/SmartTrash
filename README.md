# SmartTrash – Système Intelligent de Gestion des Déchets

Une solution complète et connectée de gestion intelligente des déchets ménagers et industriels, structurée en quatre sous-systèmes principaux :

- **[Électronique Embarquée (2× ESP32)](./smartTrash_arduino)** : Capture et analyse sensorielle distribuée via ESP-NOW.
- **[Serveur Principal / API (FastAPI + MongoDB + Firebase)](./smartTrash_API)** : Traitement, prédiction de remplissage, RAG Chatbot, routage intelligent et système de gamification.
- **[API Dédiée Classification Déchets (FastAPI + PyTorch GPU)](./smartTrash_Type_API)** *(Nouveau)* : API de Deep Learning hautement optimisée pour la prédiction instantanée de la matière du déchet.
- **[Application Mobile (Flutter)](./smartTrash_flutter/smart_trash)** : Interface utilisateur fluide comprenant la cartographie temps réel, le scanner intelligent de dépôt et le centre de récompenses.

Le système monitore en temps réel le taux de remplissage, le poids, la température, l'humidité, la présence d'eau et la concentration de gaz nocifs. Il intègre un écran d'affichage physique local, une synchronisation automatique dans le cloud, une classification des déchets basée sur l'intelligence artificielle et un portail mobile interactif.

> **🔄 Note d'Évolution :** Cette version intègre une refonte majeure de l'architecture originale de SmartTrash. La version historique est archivée dans la branche [`v1-legacy`](https://github.com/walid-moussa55/SmartTrash/tree/v1-legacy) à des fins de consultation.

---

## 1. Électronique Embarquée (2× ESP32)

La couche matérielle utilise désormais deux modules **ESP32** collaborant en temps réel via le protocole sans fil **ESP-NOW** :

### ESP32 Principal (`sketch_smartTrash_esp32_principal.ino`)

**Fonctionnalités :**
- **Mesure de remplissage** : Capteur à ultrasons pour évaluer la hauteur disponible.
- **Mesure précise de poids** : Balance intégrée via un module HX711 et une cellule de charge.
- **Paramètres environnementaux** : Mesures de température et taux d'humidité ambiants (DHT11).
- **Sécurité incendie et gaz** : Détection précoce de fumée et de gaz toxiques (MQ-2).
- **Alerte d'inondation** : Capteur de niveau d'eau déclenchant une alarme sonore continue sur le buzzer en cas d'infiltration.
- **Contrôle intelligent du couvercle** : Le servo-moteur d'ouverture s'active uniquement si la matière identifiée par l'IA correspond à la catégorie assignée au bac (`BIN_TYPE`).
- **Affichage physique** : Écran LCD I2C 16×2 indiquant le statut, le poids actuel, le pourcentage de remplissage et les icônes de connectivité WiFi/API.
- **Télémesure** : Envoi régulier (toutes les 10 secondes) des données vers le serveur API par requêtes HTTP POST.
- **Notification de dépôt** : Transmet automatiquement un événement complet de fermeture de couvercle (`POST /deposit/close`) incluant le poids après dépôt pour créditer l'utilisateur.

### ESP32-CAM AI Thinker (`sketch_smartTrash_esp32_cam.ino`)

**Fonctionnalités :**
- **Déclenchement intelligent** : Activé par l'ESP32 Principal dès qu'une présence est détectée devant le bac.
- **Capture rafale et vote** : Prend 5 clichés JPEG consécutifs pour fiabiliser l'analyse.
- **Interrogation IA** : Envoie les clichés à l'API de classification d'images (`/predict/trash_type`).
- **Algorithme de vote majoritaire** : Traite les réponses reçues (`plastic`, `paper`, `metal`, `organic`, `glass`, `cardboard`, etc.) pour identifier la classe prédominante.
- **Transmission ESP-NOW** : Envoie instantanément le résultat final validé à l'ESP32 Principal pour autorisation d'ouverture.
- **Dashboard Web Embarqué** : Serveur web local (port 80) diffusant le flux vidéo de la caméra en temps réel, affichant l'historique des détections et les couleurs dynamiques associées à chaque matière.

### Câblage des Broches – ESP32 Principal

| Capteur / Module | Broche ESP32 |
|------------------|--------------|
| TRIG_OBJ (Présence) | 4 |
| ECHO_OBJ (Présence) | 5 |
| TRIG_TRASH (Niveau) | 19 |
| ECHO_TRASH (Niveau) | 18 |
| DHT11 | 23 |
| Capteur d'eau | 32 |
| Capteur de gaz | 34 (A0) |
| HX711_DT | 26 |
| HX711_SCK | 27 |
| Servo-moteur | 25 |
| Buzzer | 33 |
| Écran LCD I2C | SDA: 21, SCL: 22 |

---

## 2. Serveur Principal & API (FastAPI + MongoDB + Firebase)

Le serveur centralise l'intelligence métier, la persistance des données, la gestion des alertes et les calculs d'itinéraires.

### Fonctionnalités Clés

- **Synchronisation Temps Réel** : Écouteur (listener) Firebase RTDB qui répercute automatiquement chaque mise à jour de capteur dans MongoDB pour l'historisation.
- **Prédictions Prévisionnelles** : Modèles prévisionnels à court terme et à 7 jours du niveau de remplissage, couplés à un outil automatique d'évaluation logistique (estimation des camions requis, du nombre d'agents de collecte et de la consommation de carburant).
- **RAG Eco-Assistant Chatbot** : Endpoint `POST /api/chat` exploitant le modèle Mistral AI (`mistral-small-latest`) enrichi par une base documentaire (RAG) sur la gestion des déchets pour répondre précisément aux questions des utilisateurs.
- **Gestion des Alertes de Gaz** :
  - **Niveau 1** (Faible) : Recommandation de ventilation.
  - **Niveau 2** (Modéré) : Alerte de sécurité (recommandation de couper les sources et éviter les flammes).
  - **Niveau 3** (Élevé) : Notification de ventilation mécanique forcée obligatoire.
  - **Urgence Critique** : Évacuation immédiate notifiée par Firebase Cloud Messaging (FCM).
- **Optimisation de la Collecte** : Algorithme de calcul d'itinéraire optimal (basé sur Dijkstra et la distance géodésique via `geopy`) pour collecter uniquement les bacs pleins sous contraintes de poids et de capacité du camion.
- **Génération de Rapports** : Production de rapports analytiques au format PDF (ReportLab) et analyses comportementales en Markdown avec détection d'anomalies assistée par IA.
- **Gamification et Système de Récompense** *(Nouveau)* :
  - **Gestion de Session (`POST /deposit/session`)** : Enregistre temporairement une intention de dépôt initiée par l'application mobile (utilisateur, type de déchet prévu, poids initial).
  - **Traitement de Dépôt (`POST /deposit/close`)** : Calcul instantané des points en fonction du poids net déposé et des coefficients de recyclage (Verre: ×3, Métal: ×4, Plastique: ×2, Papier/Carton: ×1, Organique: ×0.5).
  - **Système Anti-Triche** : Corrèle l'intention de dépôt avec les mesures finales rapportées par l'ESP32 (poids réel et détection de type par la caméra locale). En cas d'incohérence flagrante, applique un malus de score.
  - **Reset & Célébration** : Une fois le seuil (ex: 100 points) dépassé, l'utilisateur gagne un ticket de récompense, son score est remis à zéro et il reçoit une notification push FCM.
- **Auto-Découverte du Réseau** : Le serveur publie dynamiquement son adresse IP locale sur Firebase au démarrage, permettant à l'application mobile et aux ESP32 de s'y connecter de manière transparente.

### Endpoints de l'API Principale

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `POST` | `/update/{bin_id}` | Met à jour les mesures de capteurs d'un bac |
| `GET` | `/read/{bin_id}` | Lit les données actuelles d'un bac |
| `GET` | `/prediction` | Récupère les prévisions de remplissage d'un ou de tous les bacs |
| `GET` | `/prediction/weekly` | Prévisions de remplissage à 7 jours + planification logistique |
| `POST` | `/predict/trash_type` | Prédiction de la matière (méthode de secours embarquée) |
| `POST` | `/optimize` | Calcule le parcours optimal de collecte |
| `GET` | `/bin-analytics` | Fournit les statistiques historiques des bacs |
| `GET` | `/resource-management` | État actuel des bacs pour la gestion logistique |
| `POST` | `/generate-report` | Génère et télécharge le rapport d'activité au format PDF |
| `GET` | `/anomaly-recommendations` | Recommandations d'anomalies générées par IA |
| `GET` | `/get-patterns-analysis-markdown` | Analyse d'utilisation comportementale sous format Markdown |
| `POST` | `/api/chat` | Chatbot écoresponsable (Mistral AI + RAG) |
| `POST` | `/deposit/session` | *(Nouveau)* Déclare et pré-enregistre une session utilisateur avant dépôt |
| `POST` | `/deposit/close` | *(Nouveau)* Valide le dépôt final, applique l'anti-triche et distribue les points |
| `GET` | `/deposit/sessions` | *(Nouveau)* Liste pour débogage toutes les sessions de dépôt en attente |
| `POST` | `/reward/deposit` | *(Nouveau)* Traite un dépôt ponctuel avec attente active (polling) du changement de poids |
| `GET` | `/reward/score/{user_id}` | *(Nouveau)* Récupère le score, le seuil et l'historique récent d'un utilisateur |

---

## 3. API Dédiée Classification Déchets (`smartTrash_Type_API`) *(Nouveau)*

Pour alléger le serveur principal et offrir des performances d'analyse en temps réel, un microservice de vision par ordinateur autonome a été développé.

### Caractéristiques Principales
- **Modèle de Deep Learning** : Architecture DenseNet201 fine-tunée sur 10 classes de déchets : `battery`, `organic`, `cardboard`, `clothes`, `glass`, `metal`, `paper`, `plastic`, `shoes`, `trash` / `autre`.
- **Accélération Matérielle (CUDA)** : Détecte et utilise automatiquement les GPU NVIDIA configurés avec PyTorch.
- **Inférence en Demi-Précision (FP16)** : Réduit par deux la consommation mémoire et accélère le temps d'inférence sur le matériel compatible.
- **Compilation de Modèle (`torch.compile`)** : Optimise le graphe de calcul pour des performances d'exécution accrues (PyTorch 2.0+).
- **Mode d'Inférence Dédié** : Invocations encapsulées dans `torch.inference_mode` pour supprimer le tracking des gradients et minimiser l'usage du processeur.
- **Échauffement (Warm-up)** : Réalise une pré-inférence factice au démarrage de l'API pour instancier les tenseurs en mémoire GPU, évitant ainsi tout décalage temporel lors de la première requête utilisateur.
- **Monitoring Matériel Intégré** : Expose un endpoint `/status` listant l'utilisation actuelle des ressources GPU, la mémoire cache réservée/allouée et l'activation des optimisations logicielles.

### Endpoints de l'API de Classification

- `GET /` : Informations d'accueil et statut GPU basique.
- `GET /status` : Rapport d'optimisation et d'utilisation mémoire de la carte graphique.
- `POST /predict/trash_type` : Reçoit un fichier image par formulaire (multipart/form-data) et renvoie le label prédit avec son score de confiance et le temps d'inférence en millisecondes.

---

## 4. Application Mobile (Flutter)

Une application mobile multiplateforme conçue pour les citoyens (pour recycler et gagner des points) et pour les agents de collecte (pour optimiser leur travail).

### Fonctionnalités Clés

- **Télémétrie en Direct** : Suivi visuel instantané de l'état des bacs les plus proches.
- **Cartographie Interactive** : Intégration d'OpenStreetMap (`flutter_osm_plugin`) affichant la géolocalisation des bacs et les itinéraires de ramassage.
- **Dépôt Assisté par IA & QR Code** *(Nouveau)* :
  - L'utilisateur scanne le QR code apposé sur la poubelle pour l'identifier.
  - Il prend une photo de son déchet qui est analysée en direct par l'IA.
  - L'application vérifie la cohérence du tri, crée la session sur l'API et ordonne l'ouverture du couvercle.
- **Portail de Gamification** *(Nouveau)* :
  - Suivi en temps réel de son score de recyclage et de la jauge menant au prochain ticket.
  - Historique détaillé des 20 derniers dépôts (poids enregistré, matière, bonus accordé).
  - Gestionnaire de tickets de récompense gagnés.
- **Assistant Éco-Citoyen** : Chatbot intelligent intégré basé sur Mistral AI pour éduquer sur les consignes de tri locales.
- **Optimisation d'Itinéraires** : Module de navigation exclusif pour les agents de collecte, traçant le chemin le plus court calculé par le serveur.
- **Visualiseur d'Analyses et Rapports** : Accès direct aux analyses de patterns et génération de rapports d'anomalies au format PDF.

---

## Technologies Utilisées

| Secteur | Technologies Clés |
|---------|-------------------|
| **Électronique** | ESP32, ESP32-CAM, C++ (Arduino IDE), ESP-NOW, HTTPClient, Wire, LiquidCrystal_I2C, ESP32Servo, HX711 |
| **Backend & APIs** | Python 3, FastAPI, Uvicorn, Pydantic, aiofiles |
| **Intelligence Artificielle** | PyTorch, TorchVision, DenseNet201, Mistral AI API, RAG, scikit-learn |
| **Bases de Données** | MongoDB (PyMongo), Firebase Realtime Database & Cloud Messaging |
| **Application Mobile** | Flutter (Dart), OpenStreetMap (flutter_osm_plugin), Provider State Management, Mobile Scanner, Image Picker |

---

## Installation & Configuration

### 1. Préparation Matérielle (Électronique)
1. Téléversez `sketch_smartTrash_esp32_principal.ino` sur l'**ESP32 Principal**.
2. Téléversez `sketch_smartTrash_esp32_cam.ino` sur l'**ESP32-CAM** (définir le type de carte sur *AI Thinker ESP32-CAM*).
3. Connectez les capteurs et actionneurs en suivant la table des broches.
4. Renseignez les identifiants de votre réseau WiFi et les adresses IP de vos serveurs API dans les fichiers `.ino`.
5. Renseignez l'adresse MAC de chaque carte dans le sketch opposé pour activer la communication ESP-NOW.

### 2. Démarrage de l'API Dédiée Classification Déchets
```bash
cd smartTrash_Type_API
pip install -r requirements.txt
python run.py
```
*Note : Placez le fichier de poids du modèle `densenet201_garbage.pth` dans le dossier `weights_pth/` avant le lancement.*

### 3. Démarrage du Serveur Principal
```bash
cd smartTrash_API
pip install -r requirements.txt
python run.py
```
- Créez un fichier `.env` à la racine contenant votre clé `MISTRAL_API_KEY`.
- Déposez votre fichier `firebase_key.json` dans le dossier `statics/`.
- Configurez vos adresses de connexion MongoDB et Firebase dans `utils/constants.py`.

### 4. Lancement de l'Application Flutter
```bash
cd smartTrash_flutter/smart_trash
flutter pub get
flutter run
```

---

## Schéma d'Architecture Système

```
[ESP32-CAM]  ---(ESP-NOW)--->  [ESP32 Principal]  ---(WiFi/HTTP)--->  [Serveur Principal FastAPI]
                                                                        |                 |
                                                                        |                 +--> [MongoDB]
                                                                        v                 +--> [Firebase RTDB / FCM]
                                                                [API Dédiée ML]                    |
                                                             (DenseNet201 CUDA)                    v
                                                                                          [App Mobile Flutter]
```

---

## Auteurs et Crédits

Ce projet a été développé par l'équipe **OverflowAI** :
- **[WAM Development](https://github.com/walid-moussa55)**
- **[Mimoun Ouhda](https://github.com/mimounouhd)**
- **[Yassine Boujnan](https://github.com/boujnan03)**
- **[Othman Jabiri](https://github.com/Othman-Jabiri)**
- **[Bouchra Manoussi](https://github.com/BouchraManoussi)**

---

## Liens Utiles

- [Documentation Officielle ESP32 (Espressif)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/)
- [Protocole de Communication ESP-NOW](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/network/esp_now.html)
- [Framework FastAPI](https://fastapi.tiangolo.com/)
- [Base de données MongoDB](https://www.mongodb.com/)
- [Firebase Realtime Database](https://firebase.google.com/products/realtime-database)
- [Portail Développeur Mistral AI](https://docs.mistral.ai/)
- [Framework PyTorch](https://pytorch.org/)
- [Kit de développement Flutter](https://flutter.dev/)

---

**SmartTrash** — Rendre la gestion urbaine des déchets intelligente, écologique et interactive !
