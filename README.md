# SmartTrash – Intelligent Waste Management System

A complete smart waste management solution composed of three main parts:

- **[Embedded Electronics (2× ESP32)](https://github.com/walid-moussa55/SmartTrash/tree/main/smartTrash_arduino)**
- **[Server / API (FastAPI + MongoDB + Firebase RTDB)](https://github.com/walid-moussa55/SmartTrash/tree/main/smartTrash_API)**
- **[Mobile Application (Flutter)](https://github.com/walid-moussa55/SmartTrash/tree/main/smartTrash_flutter/smart_trash)**

The system monitors fill level, weight, humidity, temperature, water presence, and gas concentration in real time, with local display, cloud sync, AI-based waste classification, and a mobile user interface.

> **🔄 Evolution Notice:** This is a major redesign and innovation built on top of the original SmartTrash project. The legacy version is preserved in the [`v1-legacy` branch](https://github.com/walid-moussa55/SmartTrash/tree/v1-legacy) for reference.

---

## 1. Electronics (2× ESP32)

The hardware layer now uses **two ESP32 boards** working together via **ESP-NOW**:

### ESP32 Principal (`sketch_smartTrash_esp32_principal.ino`)

**Features:**
- Fill level measurement (ultrasonic sensor)
- Weight measurement (HX711 + load cell)
- Temperature & humidity (DHT11)
- Gas / smoke detection (MQ-2)
- Water level detection with buzzer alert
- **Intelligent lid control**: opens only when the detected waste type (received from the CAM via ESP-NOW) matches the bin's accepted type (`BIN_TYPE`)
- Local status display (LCD I2C 16×2) with WiFi and server connection icons
- Sends all sensor data to the API server via HTTP POST every 10 seconds

### ESP32-CAM AI Thinker (`sketch_smartTrash_esp32_cam.ino`) *(new)*

**Features:**
- Captures a JPEG image every 5 seconds
- Sends the image to the AI API (`/predict/trash_type`) for waste classification
- Receives the predicted waste class (`plastic`, `paper`, `metal`, `organic`, `glass`, `cardboard`, …)
- Forwards the result to the ESP32 Principal via **ESP-NOW**
- Hosts a **web dashboard** (port 80) showing live image, detected class, and capture history

### Pin Mapping – ESP32 Principal

| Sensor / Module | ESP32 Pin |
|-----------------|-----------|
| TRIG_OBJ        | 4         |
| ECHO_OBJ        | 5         |
| TRIG_TRASH      | 19        |
| ECHO_TRASH      | 18        |
| DHT11           | 23        |
| Water sensor    | 32        |
| Gas sensor      | 34 (A0)   |
| HX711_DT        | 26        |
| HX711_SCK       | 27        |
| Servo           | 25        |
| Buzzer          | 33        |
| LCD I2C         | SDA: 21, SCL: 22 |

### Arduino Library Dependencies

**ESP32 Principal:** `WiFi`, `HTTPClient`, `Wire`, `DHT sensor library` (Adafruit), `LiquidCrystal_I2C`, `ESP32Servo`, `HX711`, `esp_now`

**ESP32-CAM:** `WiFi`, `HTTPClient`, `WebServer`, `esp_camera`, `esp_now`

### Main Files
- `smartTrash_arduino/sketch_smartTrash_esp32_principal.ino`
- `smartTrash_arduino/sketch_smartTrash_esp32_cam.ino` *(new)*

---

## 2. Server / API (FastAPI + MongoDB + Firebase)

### Key Features

- **Real-time data collection**: Firebase RTDB listener syncs bin data to MongoDB automatically
- **Fill-level prediction**: next-step and 7-day weekly forecasts with daily resource planning (trucks, workers, fuel)
- **Trash type classification** *(new)*: `POST /predict/trash_type` — DenseNet201 deep learning model (PyTorch) classifying waste into 10 categories: `battery`, `organic`, `cardboard`, `clothes`, `glass`, `metal`, `paper`, `plastic`, `shoes`, `trash`
- **Smart push notifications**: Firebase Cloud Messaging (FCM) alerts on fill-level thresholds
- **Multi-level gas alerts** *(new)*:
  - **Level 1** (low): ventilation advised
  - **Level 2** (moderate): cut gas source, avoid flames
  - **Level 3** (high): forced ventilation required
  - **Critical / Emergency**: immediate evacuation alert via dedicated FCM topic
- **Route optimization**: optimal waste collection itinerary from a depot to a list of bins
- **Report generation** *(new)*: PDF reports and Markdown pattern-usage analyses with AI anomaly recommendations
- **Eco-Assistant Chatbot** *(new)*: `POST /api/chat` — Mistral AI (`mistral-small-latest`) with RAG knowledge base for context-aware waste management answers
- **Population & usage analytics**: users per bin, usage by region, fill-rate per bin, weight correlation
- **Server URL auto-registration**: the API writes its local IP to Firebase RTDB on startup so mobile apps discover the server dynamically

### Technologies

| Category | Technologies |
|----------|-------------|
| Backend  | Python 3, FastAPI, Uvicorn |
| Database | MongoDB (PyMongo), Firebase RTDB & FCM |
| AI / ML  | PyTorch, TorchVision, DenseNet201, scikit-learn, Mistral AI API |
| Data     | Pandas, NumPy |
| Reports  | ReportLab (PDF), Jinja2 |
| Async    | `asyncio`, `threading`, `httpx` |
| Frontend | HTML / JS / CSS (web dashboard) |

### API Endpoints (summary)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/update/{bin_id}` | Update a bin's sensor data |
| `GET`  | `/read/{bin_id}` | Read a bin's current data |
| `GET`  | `/prediction` | Fill-level prediction (all bins or specific bin) |
| `GET`  | `/prediction/weekly` | 7-day forecast + daily resource planning |
| `POST` | `/predict/trash_type` | Waste image classification (DenseNet201) |
| `POST` | `/optimize` | Optimize waste collection route |
| `GET`  | `/bin-analytics` | Full historical bin analytics |
| `GET`  | `/resource-management` | Current bin state for resource management |
| `POST` | `/generate-report` | Generate and download a PDF report |
| `GET`  | `/anomaly-recommendations` | AI-generated anomaly recommendations |
| `GET`  | `/get-patterns-analysis-markdown` | Markdown pattern/usage analysis |
| `POST` | `/api/chat` | Eco-Assistant chatbot (Mistral AI + RAG) |

### Main Files
- `smartTrash_API/run.py` – FastAPI entry point & background loops
- `smartTrash_API/requirements.txt`
- `smartTrash_API/routers/` – Route handlers (bins, chatbot, prediction, report)
- `smartTrash_API/services/` – Notification & route optimization services
- `smartTrash_API/predictions/` – ML models (fill-level, temperature/humidity, waste type)
- `smartTrash_API/reports/` – PDF & Markdown report generators
- `smartTrash_API/statics/` – Web dashboard & `firebase_key.json`
- `smartTrash_API/weights_pth/` – Pre-trained DenseNet201 model weights

---

## 3. Mobile Application (Flutter)

### Key Features

- Real-time visualization of each bin's data (via Firebase RTDB)
- Interactive map with bin locations (OpenStreetMap)
- Multi-level alerts: full bin, water leak, gas detected
- Fill-level & type predictions displayed in-app
- **Optimized collection route screen** *(new)*
- **Waste dashboard with population analytics** *(new)*
- **Pattern analysis viewer** *(new)*
- **Eco-Assistant chatbot screen** *(new)*
- **Final report generation screen** *(new)*
- **Anomaly recommendations screen** *(new)*
- User authentication (login / sign-up)
- Profile & app settings (theme, notifications)

### Technologies

- [Flutter](https://flutter.dev/) + Dart
- [Firebase RTDB](https://firebase.google.com/products/realtime-database) & FCM
- [flutter_osm_plugin](https://pub.dev/packages/flutter_osm_plugin) (OpenStreetMap)
- Provider for state management

### Main Files
- `smartTrash_flutter/smart_trash/` – Flutter application root
- `smartTrash_flutter/smart_trash/lib/` – Dart source files

---

## Installation & Setup

### 1. Electronics
1. Flash `sketch_smartTrash_esp32_principal.ino` onto the **ESP32 Principal**.
2. Flash `sketch_smartTrash_esp32_cam.ino` onto the **ESP32-CAM** (select *AI Thinker ESP32-CAM* board).
3. Connect all sensors according to the pin table above.
4. Update WiFi credentials and API server URL in both sketches.
5. Update the ESP32 Principal MAC address in the CAM sketch for ESP-NOW.

### 2. Server
```bash
cd smartTrash_API
pip install -r requirements.txt
python run.py
```
- Place `firebase_key.json` inside `statics/`.
- Create a `.env` file with your `MISTRAL_API_KEY`.
- Ensure MongoDB and Firebase are configured in `utils/constants.py`.

### 3. Flutter App
```bash
cd smartTrash_flutter/smart_trash
flutter pub get
flutter run
```
Install Flutter: [Official Guide](https://docs.flutter.dev/get-started/install)

---

## Architecture Overview

```
[ESP32-CAM]  ---ESP-NOW--->  [ESP32 Principal]  ---WiFi/HTTP--->  [FastAPI Server]
                                                                   |           |
                                                              MongoDB     Firebase RTDB/FCM
                                                                              |
                                                                   [Flutter Mobile App]
```

> **Important:** Both ESP32 boards and the API server must be on the **same WiFi network** for communication to work correctly.

---


---
## Authors

Project developed by **OverflowAI**:
- [WAM Development](https://github.com/walid-moussa55)
- [Momoun Ouhda](https://github.com/mimounouhd)
- [Yassine Boujnan](https://github.com/boujnan03)
- [Othman Jabiri](https://github.com/Othman-Jabiri)
- [Bouchra Manoussi](https://github.com/BOUCHRAMANOUSSI)
---

## Useful Links

- [ESP32 Documentation (Espressif)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/)
- [ESP-NOW Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/network/esp_now.html)
- [FastAPI](https://fastapi.tiangolo.com/)
- [MongoDB](https://www.mongodb.com/)
- [Firebase RTDB](https://firebase.google.com/products/realtime-database)
- [Mistral AI Documentation](https://docs.mistral.ai/)
- [PyTorch Documentation](https://pytorch.org/docs/)
- [Flutter](https://flutter.dev/)
- [flutter_osm_plugin](https://pub.dev/packages/flutter_osm_plugin)
- [SmartTrash Repository](https://github.com/walid-moussa55/SmartTrash/)

---

**SmartTrash** — Optimize urban waste management through data intelligence and AI!
