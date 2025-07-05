# SmartTrash Arduino

Ce projet contrôle une poubelle intelligente à l'aide d'un ESP32, de capteurs et d'un écran LCD. Il mesure le niveau de remplissage, le poids, l'humidité, la température, le niveau d'eau et le gaz, puis envoie ces données à un serveur via WiFi.

## Matériel utilisé

- ESP32
- 2 x Capteur ultrason HC-SR04 (détection d'objet et niveau de poubelle)
- Capteur DHT11 (température et humidité)
- Capteur de gaz (MQ-2 ou similaire)
- Capteur d'eau
- Module HX711 + cellule de charge (poids)
- Servo-moteur (ouverture du couvercle)
- Buzzer
- Écran LCD I2C 16x2

## Fonctionnalités

- Mesure du niveau de remplissage de la poubelle
- Mesure du poids des déchets
- Détection d'humidité et de température
- Détection de gaz
- Détection du niveau d'eau (alerte buzzer si trop élevé)
- Ouverture automatique du couvercle si un objet est détecté
- Affichage des informations sur l'écran LCD
- Envoi périodique des données au serveur via HTTP POST

## Connexions matérielles

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

## Configuration WiFi

> **Important :** L’ESP32 et le serveur API doivent être connectés au même réseau WiFi (même routeur) pour que la communication fonctionne correctement.

Modifiez les lignes suivantes dans le code pour adapter le SSID et le mot de passe WiFi :

```cpp
#define WIFI_SSID ""
#define WIFI_PASSWORD ""
```

## Configuration du serveur

Modifiez l'URL du serveur pour pointer vers votre API :

```cpp
const char* serverName = "http://API_SERVER_IPADDRESS:8000/update/trash_1";
```

## Utilisation

1. Chargez le code [sketch_smartTrash.ino](smartTrash_arduino/sketch_smartTrash.ino) sur votre ESP32.
2. Branchez tous les capteurs/modules selon le tableau ci-dessus.
3. Ouvrez le moniteur série à 115200 bauds pour voir les logs.
4. Les données seront envoyées automatiquement au serveur toutes les 10 secondes.

## Dépendances Arduino

Installez les bibliothèques suivantes via le gestionnaire de bibliothèques Arduino :

- WiFi
- HTTPClient
- Wire
- DHT sensor library
- LiquidCrystal_I2C
- ESP32Servo
- HX711

## Exemple de trame JSON envoyée

```json
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

## Liens utiles

- [Documentation officielle ESP32 (Espressif)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/)
- [Bibliothèque Arduino HX711](https://github.com/bogde/HX711)
- [Bibliothèque Arduino DHT sensor](https://github.com/adafruit/DHT-sensor-library)
- [Bibliothèque LiquidCrystal_I2C](https://github.com/johnrickman/LiquidCrystal_I2C)
- [Bibliothèque ESP32Servo](https://github.com/jkb-git/ESP32Servo)
- [Exemples de requêtes HTTPClient Arduino](https://randomnerdtutorials.com/esp32-http-get-post-arduino/)

## Auteur

Projet réalisé par WAM Development.
