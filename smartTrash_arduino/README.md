# SmartTrash Arduino — NaqiAI

This project controls a smart waste bin using **two ESP32 boards** working together: a main ESP32 that handles all sensors and bin logic, and an **ESP32-CAM** that captures images and uses an AI API to classify the type of waste. The two boards communicate wirelessly via **ESP-NOW**.

---

## Architecture Overview

```
┌─────────────────────────────┐        ESP-NOW         ┌──────────────────────────────┐
│   ESP32 Principal           │◄────────────────────── │   ESP32-CAM (AI Thinker)     │
│                             │    trash_type result   │                              │
│  • Ultrasonic sensors       │                        │  • Camera capture (JPEG)     │
│  • DHT11 (temp/humidity)    │                        │  • Sends image to AI API     │
│  • Gas sensor               │                        │  • Web dashboard (port 80)   │
│  • Water level sensor       │                        │  • 5-second capture loop     │
│  • Load cell (weight)       │                        └──────────────────────────────┘
│  • Servo motor (lid)        │
│  • Buzzer                   │
│  • LCD I2C 16x2             │
│  • HTTP POST → API server   │
└─────────────────────────────┘
```

---

## Hardware Components

### ESP32 Principal (`sketch_smartTrash_esp32_principal.ino`)

| Component               | Description                                      |
|-------------------------|--------------------------------------------------|
| ESP32                   | Main microcontroller                             |
| HC-SR04 × 2             | Ultrasonic sensors (object detection + fill level) |
| DHT11                   | Temperature and humidity sensor                  |
| Gas sensor (MQ-2)       | Gas/smoke detection                              |
| Water level sensor      | Water detection with buzzer alert                |
| HX711 + load cell       | Weight measurement                               |
| Servo motor             | Automatic lid opening/closing                    |
| Buzzer                  | Audio alerts                                     |
| LCD I2C 16×2            | Real-time display                                |

### ESP32-CAM AI Thinker (`sketch_smartTrash_esp32_cam.ino`)

| Component                    | Description                                           |
|------------------------------|-------------------------------------------------------|
| ESP32-CAM (AI Thinker)       | Camera module with integrated ESP32                   |
| OV2640 camera                | Captures JPEG images every 5 seconds                  |
| ESP32-CAM USB adapter board  | Plugged into the CAM — used for powering and flashing |

---

## Pin Mapping

### ESP32 Principal

| Sensor / Module     | ESP32 Pin            |
|---------------------|----------------------|
| TRIG_OBJ            | 4                    |
| ECHO_OBJ            | 5                    |
| TRIG_TRASH          | 19                   |
| ECHO_TRASH          | 18                   |
| DHT11               | 23                   |
| Water sensor        | 32                   |
| Gas sensor          | 34 (A0)              |
| HX711_DT            | 26                   |
| HX711_SCK           | 27                   |
| Servo               | 25                   |
| Buzzer              | 33                   |
| LCD I2C             | SDA: 21, SCL: 22     |

### ESP32-CAM (AI Thinker)

| Signal              | GPIO Pin |
|---------------------|----------|
| PWDN                | 32       |
| XCLK                | 0        |
| SIOD (SDA)          | 26       |
| SIOC (SCL)          | 27       |
| Y9–Y2 (data)        | 35, 34, 39, 36, 21, 19, 18, 5 |
| VSYNC               | 25       |
| HREF                | 23       |
| PCLK                | 22       |

---

## Features

### ESP32 Principal
- Measures bin fill level (ultrasonic sensor)
- Measures waste weight (load cell + HX711)
- Reads temperature and humidity (DHT11)
- Detects gas/smoke levels
- Detects water level — triggers buzzer alert if too high
- **Intelligent lid control**: opens only if the waste type (received from the CAM via ESP-NOW) matches the bin's accepted type (`BIN_TYPE`)
- Displays status on the LCD with WiFi and server connection icons
- Sends all sensor data to the API server via HTTP POST every 10 seconds

### ESP32-CAM
- Captures a JPEG image every 5 seconds
- Sends the image to the AI API (`/predict/trash_type`) as a multipart HTTP POST
- Receives the `predicted_class` (e.g. `plastic`, `paper`, `metal`, `organic`, `glass`, `cardboard`)
- Forwards the result to the ESP32 Principal via **ESP-NOW**
- Hosts a **web dashboard** on port 80 showing:
  - Live last captured image
  - Last detected waste class (color-coded)
  - History of last 5 captures
  - Total capture count and image sizes

---

## WiFi Configuration

> **Important:** Both ESP32 boards and the API server must be on the **same WiFi network** for communication to work.

In each sketch, update the WiFi credentials:

```cpp
// ESP32 Principal
#define WIFI_SSID     "YOUR_SSID"
#define WIFI_PASSWORD "YOUR_PASSWORD"

// ESP32-CAM
const char* ssid     = "YOUR_SSID";
const char* password = "YOUR_PASSWORD";
```

---

## ESP-NOW Configuration

The ESP32-CAM sends the detected waste type directly to the ESP32 Principal over **ESP-NOW** (no router involved for this link).

Update the ESP32 Principal's MAC address in `sketch_smartTrash_esp32_cam.ino`:

```cpp
uint8_t receiverMAC[] = {0xBC, 0xDD, 0xC2, 0xCE, 0x09, 0x18}; // Replace with your ESP32 Principal MAC
```

To find your ESP32 Principal's MAC address, print `WiFi.macAddress()` on its serial monitor.

---

## API Server Configuration

Update the server URL in each sketch:

```cpp
// ESP32 Principal — sensor data
const char* serverName = "http://API_SERVER_IPADDRESS:8000/update/trash_1";

// ESP32-CAM — waste classification
const char* apiUrl = "http://API_SERVER_IPADDRESS:8000/predict/trash_type";
```

---

## Bin Type Configuration

Each bin only accepts one type of waste. Set the accepted type in `sketch_smartTrash_esp32_principal.ino`:

```cpp
// Options: "paper", "plastic", "metal", "glass", "organic", "cardboard"
const String BIN_TYPE = "paper";
```

When the CAM detects a waste item:
- ✅ **Correct type** → Lid opens for 4 seconds, short success beep
- ❌ **Wrong type** → Lid stays closed, long alert beep, LCD shows accepted type

---

## Usage

1. Flash `sketch_smartTrash_esp32_principal.ino` onto the **ESP32 Principal**.
2. Flash `sketch_smartTrash_esp32_cam.ino` onto the **ESP32-CAM** (select *AI Thinker ESP32-CAM* board).
3. Connect all sensors according to the pin tables above.
4. Power both boards and open the Serial Monitor at **115200 baud** to see logs.
5. Access the **CAM dashboard** at `http://<ESP32-CAM-IP>/` from any browser on the same network.
6. Sensor data is sent to the API server every **10 seconds**.

---

## Arduino Library Dependencies

Install the following libraries via the Arduino Library Manager:

**ESP32 Principal:**
- `WiFi` (built-in)
- `HTTPClient` (built-in)
- `Wire` (built-in)
- `DHT sensor library` — Adafruit
- `LiquidCrystal_I2C`
- `ESP32Servo`
- `HX711`
- `esp_now` (built-in with ESP32 board package)

**ESP32-CAM:**
- `WiFi` (built-in)
- `HTTPClient` (built-in)
- `WebServer` (built-in)
- `esp_camera` (built-in with ESP32 board package)
- `esp_now` (built-in with ESP32 board package)

---

## Example JSON Payload (sent to API)

```json
{
  "bin_id": "trash_1",
  "gaz_level": 5,
  "humidity": 45.2,
  "temperature": 23.1,
  "location": { "latitude": 32.376553, "longitude": -6.320284 },
  "name": "Bin 1 - Lobby",
  "trash_level": 80,
  "trash_type": "plastic",
  "weight": 2.5,
  "volume": 100,
  "water_level": 60
}
```

> `trash_type` is now dynamically set from the waste classification result received from the ESP32-CAM.

---

## Useful Links

- [ESP32 Official Documentation (Espressif)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/)
- [HX711 Arduino Library](https://github.com/bogde/HX711)
- [DHT Sensor Library (Adafruit)](https://github.com/adafruit/DHT-sensor-library)
- [LiquidCrystal_I2C Library](https://github.com/johnrickman/LiquidCrystal_I2C)
- [ESP32Servo Library](https://github.com/jkb-git/ESP32Servo)
- [ESP32 HTTPClient Examples](https://randomnerdtutorials.com/esp32-http-get-post-arduino/)
- [ESP32-CAM Getting Started](https://randomnerdtutorials.com/esp32-cam-video-streaming-web-server-camera-home-assistant/)
- [ESP-NOW Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/network/esp_now.html)

---

## Author

Project developed by [**WAM Development**](https://github.com/walid-moussa55).
