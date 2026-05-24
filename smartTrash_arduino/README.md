# SmartTrash Arduino

Ce projet contrôle une poubelle intelligente à l'aide d'une architecture double ESP32 (principal + caméra), de capteurs et d'un écran LCD. Le système détecte le type de déchet via une caméra et IA, mesure le niveau de remplissage, le poids, l'humidité, la température, le niveau d'eau et le gaz, puis envoie ces données à un serveur via WiFi.

## Architecture

Le système utilise une architecture distribuée avec **deux ESP32** communiquant via ESP-NOW :

- **ESP32 Principal** : Gère tous les capteurs, l'affichage LCD, la servo, le buzzer et l'orchestration
- **ESP32-CAM** : Caméra pour la classification d'images (détection du type de déchet via ML)

## Matériel utilisé

### ESP32 Principal
- ESP32 (carte de développement)
- 2 x Capteur ultrason HC-SR04 (détection d'objet et niveau de poubelle)
- Capteur DHT11 (température et humidité)
- Capteur de gaz (MQ-2 ou similaire)
- Capteur d'eau analogique
- Module HX711 + cellule de charge (poids)
- Servo-moteur (ouverture conditionnelle du couvercle)
- Buzzer
- Écran LCD I2C 16x2

### ESP32-CAM
- ESP32-CAM (avec caméra OV2640)
- LED Flash (pour meilleures photos)
- Connexion WiFi pour API ML

## Fonctionnalités

- **Classification IA des déchets** : 5 captures avec vote majoritaire (plastic, metal, paper, organic, glass, cardboard)
- **Servo intelligent** : Ouverture du couvercle UNIQUEMENT si le type détecté correspond à la poubelle
- **Mesure du niveau de remplissage** : Capteur ultrason avec calcul en pourcentage
- **Mesure du poids** : Load cell avec HX711, poids avant et après dépôt
- **Détection d'humidité et température** : Capteur DHT11
- **Détection de gaz** : MQ-2 pour alertes
- **Alerte buzzer eau** : Son continu si niveau d'eau > 50%
- **Affichage LCD en temps réel** : Statut poubelle, connexions WiFi/API
- **Envoi périodique des données** : Toutes les 10 secondes au serveur via HTTP POST
- **Suivi des dépôts** : API pour enregistrer les événements de fermeture (type détecté, poids, points)
- **Interface web** : Flux caméra en direct avec résultats de classification

## Connexions matérielles

### ESP32 Principal (sketch_smartTrash_esp32_principal.ino)

| Capteur/Module      | Broche ESP32 |
|---------------------|-------------|
| TRIG_OBJ (capteur objet)  | 4     |
| ECHO_OBJ (capteur objet)  | 5     |
| TRIG_TRASH (niveau poubelle) | 19 |
| ECHO_TRASH (niveau poubelle) | 18 |
| DHT11               | 23          |
| Capteur d'eau       | 32          |
| Capteur de gaz      | 34 (A0)     |
| HX711_DT            | 26          |
| HX711_SCK           | 27          |
| Servo               | 25          |
| Buzzer              | 33          |
| LCD I2C             | SDA: 21, SCL: 22 |

### ESP32-CAM (sketch_smartTrash_esp32_cam.ino)

L'ESP32-CAM utilise la configuration caméra OV2640 standard :

| Élément             | Broche/Interface |
|---------------------|-------------|
| Caméra OV2640       | Interface JTAG standard ESP32-CAM |
| LED Flash           | GPIO 4      |
| Récepteur ESP-NOW   | (communication sans fil, pas de GPIO) |

## Configuration WiFi

> **Important :** L'ESP32 principal et le serveur API doivent être connectés au même réseau WiFi (même routeur) pour que la communication fonctionne correctement. L'ESP32-CAM communique aussi via WiFi pour accéder à l'API ML.

Modifiez les lignes suivantes dans les sketches pour adapter le SSID et le mot de passe WiFi :

**ESP32 Principal :**
```cpp
#define WIFI_SSID     "[SSID]"
#define WIFI_PASSWORD "[PASSWORD]"
```

**ESP32-CAM :**
```cpp
const char* ssid     = "[SSID]";
const char* password = "[PASSWORD]";
```

## Configuration ESP-NOW

Les deux ESP32 communiquent via **ESP-NOW** (protocole sans fil propriétaire Espressif, très rapide et peu consommateur).

### 1. Obtenir les adresses MAC

Chargez ce code test sur chaque ESP32 pour obtenir son adresse MAC :

```cpp
void setup() {
  Serial.begin(115200);
  Serial.println(WiFi.macAddress()); // Affiche: XX:XX:XX:XX:XX:XX
}
```

### 2. Configurer les MAC dans les sketches

**Dans sketch_smartTrash_esp32_principal.ino :**
```cpp
uint8_t camMAC[] = {0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX}; // MAC du CAM
```

**Dans sketch_smartTrash_esp32_cam.ino :**
```cpp
uint8_t receiverMAC[] = {0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX}; // MAC du principal (0xFF = broadcast)
```

### 3. Format des messages

**Message Principal → CAM (trigger) :**
```cpp
typedef struct {
  char command[10]; // "SCAN"
} TriggerMessage;
```

**Message CAM → Principal (résultat) :**
```cpp
typedef struct {
  char trash_type[20]; // "plastic", "metal", "paper", etc.
} TrashMessage;
```

## Configuration des serveurs API

### API Principal (données capteurs)

Modifiez l'URL du serveur pour pointer vers votre API :

**ESP32 Principal :**
```cpp
const char* serverName = "http://[API_IP_ADDRESS]:8000/update/trash_1";
```

### API ML (classification des déchets)

L'ESP32-CAM envoie les images à l'API ML pour détection de type :

**ESP32-CAM :**
```cpp
const char* apiUrl = "http://[API_IP_ADDRESS]:8090/predict/trash_type";
```

### API Dépôt (suivi des événements)

Après validation du type de déchet, le principal envoie un événement de fermeture :

**ESP32 Principal :**
```cpp
const char* depositCloseUrl = "http://[API_IP_ADDRESS]:8000/deposit/close";
```

#### Format du payload (dépôt) :
```json
{
  "bin_id": "trash_1",
  "weight_after": 2.350,
  "arduino_detected_type": "plastic",
  "deposit_event": true
}
```

### Configuration de la poubelle

Modifiez le type et l'ID de la poubelle pour correspondre à votre instance :

```cpp
const String BIN_TYPE = "paper";    // Type accepté: "plastic", "metal", "paper", etc.
const String BIN_ID   = "trash_1";  // Doit correspondre à l'ID Firebase
```

## Utilisation

### 1. Préparation des sketches

#### ESP32 Principal
- Chargez [sketch_smartTrash_esp32_principal.ino](sketch_smartTrash_esp32_principal.ino)
- Configurez WiFi, MAC du CAM et URLs des APIs

#### ESP32-CAM
- Chargez [sketch_smartTrash_esp32_cam.ino](sketch_smartTrash_esp32_cam.ino)
- Configurez WiFi et MAC du principal (ou broadcast 0xFF)
- Configurez l'URL de l'API ML

### 2. Branchement matériel
- Connectez tous les capteurs au principal selon le tableau de connexions
- Connectez la caméra à l'ESP32-CAM
- Branchez le LED flash et les connexions de communication

### 3. Montage
1. Ouvrez le moniteur série à **115200 bauds** sur les deux ESP32 pour voir les logs
2. Au démarrage, le principal affichera son MAC et IP
3. Les deux ESP32 établissent la connexion WiFi
4. Le système affichera "NaqiAI Pret!" sur l'écran LCD

### 4. Fonctionnement
1. **Détection d'objet** : Quand un objet est détecté par le capteur ultrason (< 15 cm), le principal envoie "SCAN" au CAM
2. **Classification** : Le CAM prend 5 photos et les envoie à l'API ML
3. **Vote majoritaire** : Le CAM calcule la classe la plus votée et renvoie le résultat
4. **Décision servo** :
   - ✅ **Type correct** : Servo ouvre le couvercle (4s), bip succes (2x)
   - ❌ **Type incorrect** : Servo reste fermé, bip alerte (800ms)
5. **Suivi** : Poids avant/après est envoyé à l'API pour le système de points
6. **Données capteurs** : Envoi à l'API toutes les 10 secondes

## Système de classification IA

### Cycle de détection

1. **Capture (5x)** : Le CAM prend 5 photos avec flash LED
2. **Envoi API** : Chaque image est envoyée à l'API de classification ML
3. **Vote majoritaire** : Les résultats de classe sont comptabilisés
4. **Résultat gagnant** : La classe avec le plus de votes est sélectionnée

### Classes reconnues

```
"plastic"   → Matière plastique
"metal"     → Métal
"paper"     → Papier
"organic"   → Matière organique (compost)
"glass"     → Verre
"cardboard" → Carton
"unknown"   → Type inconnu
```

### Délai de timeout

Si le CAM ne répond pas dans les **8 secondes**, le système affiche "CAM timeout" sur l'écran LCD et attend une nouvelle détection.

## Logique de servo et gamification

### Comportement conditionnel

- **Dépôt valide** (type correct) : 
  - Servo ouvre le couvercle pendant 4 secondes
  - Bip de succès (2 bips)
  - Poids mesuré AVANT et APRÈS pour calculer les points gagnés

- **Dépôt invalide** (type incorrect) : 
  - Servo reste fermé
  - Bip d'alerte (800ms continu)
  - Dépôt enregistré avec points négatifs pour la gamification

## Dépendances Arduino

Installez les bibliothèques suivantes via le gestionnaire de bibliothèques Arduino :

**Communes aux deux ESP32 :**
- `WiFi`
- `HTTPClient`
- `esp_now.h` (ESP-NOW - déjà dans l'IDE Arduino)
- `Arduino.h`

**ESP32 Principal uniquement :**
- `Wire` (I2C)
- `DHT sensor library by Adafruit`
- `LiquidCrystal_I2C by Frank de Brabander`
- `ESP32Servo by John Burton`
- `HX711 by Bogdan Necula`

**ESP32-CAM uniquement :**
- `esp_camera.h` (déjà dans l'IDE Arduino)
- `WebServer.h` (déjà dans l'IDE Arduino)

## Interface Web (ESP32-CAM)

L'ESP32-CAM expose un serveur web accessible sur `http://[CAM_IP]:80/` :

- **`/`** : Page principale avec flux caméra, classe détectée et couleur associée
- **`/live.jpg`** : Image JPEG brute de la dernière capture
- **Auto-refresh** : Page HTML se rafraîchit toutes les 3 secondes

### Couleurs par classe

| Classe    | Couleur (hex) |
|-----------|-----------|
| plastic   | #3498db (bleu) |
| metal     | #95a5a6 (gris) |
| paper     | #f39c12 (orange) |
| organic   | #27ae60 (vert) |
| glass     | #1abc9c (cyan) |
| cardboard | #e67e22 (orange foncé) |
| unknown   | #8e44ad (violet) |

## Exemple de trame JSON envoyée

```json
{
  "bin_id": "trash_1",
  "gaz_level": 5,
  "humidity": 45.2,
  "temperature": 23.1,
  "location": {"latitude": 32.8811, "longitude": -6.9063},
  "name": "Bin 1 - Lobby",
  "trash_level": 80,
  "trash_type": "plastic",
  "weight": 2.5,
  "volume": 100,
  "water_level": 60
}
```

## Dépannage

### Problèmes courants

| Problème | Cause probable | Solution |
|----------|--------|----------|
| ESP-NOW : Message non reçu | MAC incorrect ou ESP-NOW non initialisé | Vérifiez les adresses MAC avec `WiFi.macAddress()`, redémarrez les deux ESP32 |
| "CAM timeout" sur LCD | CAM ne répond pas dans les 8s | Vérifiez que le CAM est allumé, vérifiez les adresses MAC, vérifiez le WiFi |
| Servo ne s'ouvre pas | Type détecté ≠ BIN_TYPE | Vérifiez la valeur de `BIN_TYPE` dans le principal, testez la classification avec des images claires |
| Pas de données capteurs | DHT ou HX711 non détectés | Vérifiez les branchements, testez chaque capteur individuellement |
| LCD vide | Adresse I2C incorrecte | Lancez un scan I2C pour trouver l'adresse (généralement 0x27) |
| API non répondante | Adresse IP ou port incorrect | Vérifiez `serverName`, `depositCloseUrl`, `apiUrl` et testez les endpoints avec curl |
| Servo trembleuse | Alimention insuffisante | Utilisez une alimentation externe pour le servo (5V, 1A minimum) |

### Débogage

#### 1. Moniteur Série
- **Principal** : Affiche les mesures des capteurs, statuts ESP-NOW, résultats API
- **CAM** : Affiche les captures, les appels API ML, le vote majoritaire

#### 2. Logs utiles à vérifier
```
Principal:
  "WiFi OK — IP: 192.168.x.x"
  "MAC: XX:XX:XX:XX:XX:XX"
  "ESP-NOW OK"
  "Objet detecte a X.X cm"
  "Reponse CAM: [type] (en Xms)"

CAM:
  "Camera init OK"
  "ESP-NOW: SCAN recu"
  "Capture 1/5..."
  "Votes: plastic=4 metal=1 → WINNER: plastic (4/5)"
```

#### 3. Test des connexions
- Testez chaque capteur individuellement
- Testez ESP-NOW avec un code minimal (envoi/réception de texte)
- Testez l'API ML en envoyant une image avec curl
- Testez la connectivité WiFi en pingant le serveur API

## Liens utiles

- [Documentation officielle ESP32 (Espressif)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/)
- [Bibliothèque Arduino HX711](https://github.com/bogde/HX711)
- [Bibliothèque Arduino DHT sensor](https://github.com/adafruit/DHT-sensor-library)
- [Bibliothèque LiquidCrystal_I2C](https://github.com/johnrickman/LiquidCrystal_I2C)
- [Bibliothèque ESP32Servo](https://github.com/jkb-git/ESP32Servo)
- [Exemples de requêtes HTTPClient Arduino](https://randomnerdtutorials.com/esp32-http-get-post-arduino/)

## Auteur

Projet réalisé par WAM Development.
