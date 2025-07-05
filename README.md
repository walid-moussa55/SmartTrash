# SmartTrash – Système de Poubelle Intelligente

Ce projet propose une solution complète de gestion intelligente des déchets, composée de trois parties principales :  
- **[Électronique embarquée (ESP32)](https://github.com/walid-moussa55/SmartTrash/tree/main/smartTrash_arduino)**
- **[Serveur/API (FastAPI + MongoDB + Firebase RTDB)](https://github.com/walid-moussa55/SmartTrash/tree/main/smartTrash_API)**
- **[Application mobile (Flutter)](https://github.com/walid-moussa55/SmartTrash/tree/main/smartTrash_flutter/smart_trash)**

Il permet de mesurer et de surveiller en temps réel le niveau de remplissage, le poids, l’humidité, la température, la présence d’eau et de gaz dans la poubelle, avec affichage local et remontée des données vers une interface utilisateur.

---

## 1. Partie Électronique (ESP32)

### Fonctionnalités principales
- Mesure du niveau de remplissage (ultrason)
- Mesure du poids (HX711)
- Température et humidité (DHT11)
- Détection de gaz (MQ-2 ou similaire)
- Détection d’eau (capteur analogique)
- Ouverture automatique du couvercle (servo)
- Alerte sonore (buzzer)
- Affichage local (LCD I2C)
- Envoi périodique des données au serveur via WiFi

### Schéma de connexion (exemple)
| Capteur/Module      | Broche ESP32 |
|---------------------|-------------|
| TRIG_OBJ            | 4           |
| ECHO_OBJ            | 5           |
| TRIG_TRASH          | 19          |
| ECHO_TRASH          | 18          |
| DHT11               | 23          |
| Capteur d'eau       | 32          |
| Capteur de gaz      | 34 (A0)     |
| HX711_DT            | 26          |
| HX711_SCK           | 27          |
| Servo               | 25          |
| Buzzer              | 33          |
| LCD I2C             | SDA: 21, SCL: 22 |

### Dépendances Arduino
- WiFi
- HTTPClient
- Wire
- DHT sensor library
- LiquidCrystal_I2C
- ESP32Servo
- HX711

### Fichier principal :  
`smartTrash_arduino/sketch_smartTrash.ino`

---

## 2. Partie Serveur / API (FastAPI + MongoDB + Firebase RTDB)

### Fonctionnalités principales
- Réception des données envoyées par l’ESP32 (POST JSON)
- Stockage des données dans MongoDB (historique, statistiques)
- Synchronisation en temps réel avec Firebase Realtime Database (pour l’application Flutter)
- Fourniture d’une API REST pour l’application (consultation, statistiques, alertes)
- Authentification (optionnel)
- Gestion multi-poubelles (optionnel)

### Technologies utilisées
- **Backend :** Python [FastAPI](https://fastapi.tiangolo.com/)
- **Base de données :** [MongoDB](https://www.mongodb.com/)
- **Temps réel :** [Firebase Realtime Database](https://firebase.google.com/products/realtime-database)

### Exemple de point d’entrée API
```
POST /update/trash_1
Content-Type: application/json
{
  "bin_id": "trash_1",
  "gaz_level": 5,
  "humidity": 45.2,
  "temperature": 23.1,
  "location": {"latitude": 32.376553, "longitude": -6.320284},
  "name": "Bin 1 - Lobby",
  "trash_level": 80,
  "trash_type": "plastic",
  "weight": 2.5,
  "volume": 100,
  "water_level": 60
}
```

### Fichiers principaux :  
- `smartTrash_API/main.py` (FastAPI)
- `smartTrash_API/requirements.txt`
- Configuration MongoDB et Firebase dans le dossier `smartTrash_API/`

---

## 3. Partie Application Mobile (Flutter)

### Fonctionnalités principales
- Visualisation en temps réel des données de chaque poubelle (via Firebase RTDB)
- Cartographie des emplacements
- Alertes (poubelle pleine, fuite d’eau, gaz détecté…)
- Statistiques et historiques
- Authentification utilisateur (optionnel)

### Technologies utilisées
- [Flutter](https://flutter.dev/)
- [Firebase RTDB](https://firebase.google.com/products/realtime-database)
- Pour la cartographie :
  - [flutter_osm_plugin (OpenStreetMap)](https://pub.dev/packages/flutter_osm_plugin) **(open source, recommandé)**
  - ou [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)
- [Provider](https://pub.dev/packages/provider) ou [Bloc](https://bloclibrary.dev/) pour la gestion d’état

### Fichiers principaux :  
- `smartTrash_flutter/smart_trash/` (dossier de l’application Flutter)
- `smartTrash_flutter/smart_trash/lib/` (sources Dart)

---

## Installation et Lancement

### 1. Partie Électronique
- Programmer l’ESP32 avec le code Arduino
- Adapter le SSID/mot de passe WiFi et l’URL du serveur dans le code
- Brancher les capteurs selon le schéma

### 2. Partie Serveur
- Installer les dépendances Python :  
  ```bash
  cd server
  pip install -r requirements.txt
  ```
- Lancer le serveur :  
  ```bash
  uvicorn main:app --reload
  ```
- S’assurer que MongoDB et Firebase sont configurés et accessibles

### 3. Partie Application Flutter
- Installer Flutter : [Guide officiel](https://docs.flutter.dev/get-started/install)
- Installer les dépendances :  
  ```bash
  cd app
  flutter pub get
  ```
- Lancer l’application :  
  ```bash
  flutter run
  ```

---

## Schéma d’architecture

```
[ESP32 + Capteurs]  <---WiFi--->  [Serveur FastAPI]  <---MongoDB/Firebase--->  [Application Flutter]
```

> **Important :** L’ESP32 et le serveur API doivent être connectés au même réseau WiFi (même routeur) pour que la communication fonctionne correctement.

---

## Auteur

Projet réalisé par WAM Development

---

## Liens utiles

- [Documentation officielle ESP32 (Espressif)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/)
- [FastAPI](https://fastapi.tiangolo.com/)
- [MongoDB](https://www.mongodb.com/)
- [Firebase RTDB](https://firebase.google.com/products/realtime-database)
- [Flutter](https://flutter.dev/)
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)
- [Forum Arduino France](https://forum.arduino.cc/c/international/francais/33)
- [Exemples de requêtes HTTPClient Arduino](https://randomnerdtutorials.com/esp32-http-get-post-arduino/)
- [Dépôt du projet SmartTrash](https://github.com/walid-moussa55/SmartTrash/)

---

**SmartTrash** : Optimisez la gestion urbaine des déchets grâce à la donnée et à l’intelligence artificielle !

---
