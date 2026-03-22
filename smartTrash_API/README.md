# SmartTrash API

SmartTrash API is an intelligent waste management platform that collects, analyzes, and predicts data from connected smart trash bins. It integrates advanced features such as fill-level prediction, notification management, report generation, route optimization, AI-powered chatbot assistance, and image-based waste classification.

## Key Features

- **Real-time Data Collection**: Synchronization with Firebase Realtime Database (RTDB) to retrieve and store bin data automatically.
- **MongoDB Storage**: Bin data is persisted in a MongoDB database for historical analysis and reporting.
- **Advanced Predictions**: Fill-level prediction (`predictionLvl`) — next-step and 7-day weekly forecasts.
- **Weekly Resource Planning**: The `/prediction/weekly` endpoint forecasts fill levels for every bin over the next 7 days and automatically calculates the number of collection trucks, workers, and fuel liters needed per day.
- **Trash Type Classification**: A `POST /predict/trash_type` endpoint accepts an image file and uses a **DenseNet201** deep learning model (PyTorch) to classify waste into 10 categories: `battery`, `organic`, `cardboard`, `clothes`, `glass`, `metal`, `paper`, `plastic`, `shoes`, `trash`.
- **Smart Notifications**: Push notifications via Firebase Cloud Messaging (FCM) when fill-level thresholds are reached.
- **Multi-level Gas Alerts**: The notification service monitors gas sensor readings and sends tiered FCM alerts:
  - **Level 1** (low concentration): ventilation advised.
  - **Level 2** (moderate): cut gas source, avoid flames.
  - **Level 3** (high): forced ventilation required.
  - **Critical / Emergency** (maximum danger): immediate evacuation alert sent to a dedicated `_emergency` FCM topic.
- **Route Optimization**: Calculates the optimal collection itinerary from a given container location and a list of bins.
- **Report Generation**: Creates PDF reports and Markdown pattern-usage analyses from historical bin data, including anomaly detection with AI-generated recommendations.
- **Eco-Assistant Chatbot (RAG)**: A `/api/chat` endpoint powered by **Mistral AI** (`mistral-small-latest` by default). The chatbot is augmented with a local knowledge base (`knowledge_base.txt`) injected into the system prompt for context-aware answers about waste management.
- **RESTful API**: Multiple endpoints for management, analytics, and data retrieval.
- **Server URL Auto-registration**: On startup, the API automatically detects its local IP address and writes the server URL to Firebase RTDB under `app_settings/rotageServerUrl` so mobile apps can discover the server dynamically.

## Project Structure

```
smartTrash_API/
├── run.py                       # FastAPI entry point, startup logic, background loops
├── requirements.txt
├── .env                         # Environment variables (MISTRAL_API_KEY, etc.)
├── routers/
│   ├── bins.py                  # Bin analytics, route optimization, population stats
│   ├── chatbot.py               # Eco-Assistant chatbot (Mistral AI + RAG)
│   ├── prediction.py            # Fill-level, weekly, and trash-type predictions
│   └── report.py                # PDF/Markdown report generation, anomaly recommendations
├── services/
│   ├── notification_service.py  # FCM alerts: fill-level & multi-level gas alerts
│   └── rotage.py                # Waste collection route optimization logic
├── others/
│   ├── models.py                # Pydantic data models (TrashData, GasLevelBin, etc.)
│   ├── database.py              # MongoDB connection and queries
│   ├── population_stats.py      # Usage statistics helpers
│   └── prediction_state.py      # Shared in-memory prediction state
├── predictions/
│   ├── predictionLvl.py         # Fill-level prediction (next step + 7-day)
│   ├── predictionTH.py          # Temperature/humidity prediction
│   └── prediction_type.py       # DenseNet201 image classifier
├── reports/
│   ├── rapprot_generator.py     # PDF report generator
│   ├── paterns_usage.py         # Markdown pattern/usage analysis
│   └── anomalie_comment.py      # AI anomaly comment generator
├── utils/
│   ├── constants.py             # App-wide constants and thresholds
│   └── helper.py                # Utility functions (IP detection, type conversion)
├── statics/                     # Web dashboard (HTML/JS/CSS) & firebase_key.json
├── weights_pth/                 # Pre-trained model weights (DenseNet201)
└── generated_files/             # Output directory for generated reports
```

## API Endpoints

### Core
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | API welcome message |
| `POST` | `/update/{bin_id}` | Update a bin's data |
| `GET` | `/read/{bin_id}` | Read a bin's current data |

### Predictions
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/prediction` | Get current fill-level prediction (all bins or a specific bin) |
| `GET` | `/prediction/weekly` | 7-day fill-level forecast + daily resource planning (trucks, workers, fuel) |
| `POST` | `/predict/trash_type` | Classify waste type from an image (DenseNet201, 10 categories) |

### Bins & Analytics
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/optimize` | Optimize waste collection route |
| `GET` | `/bin-analytics` | Full historical bin analytics |
| `GET` | `/resource-management` | Current bin state for resource management |
| `GET` | `/api/population-by-bin` | Number of users per bin |
| `GET` | `/api/usage-by-region` | Bin usage counts grouped by region |
| `GET` | `/api/trash-weight-correlation` | Trash level vs. weight correlation data |
| `GET` | `/api/fill-rate-by-bin` | Average fill rate (% per hour) per bin |

### Reports
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/generate-report` | Generate and download a PDF report |
| `GET` | `/generated-report.pdf` | Serve the last generated PDF report |
| `GET` | `/anomaly-recommendations` | AI-generated anomaly recommendations |
| `GET` | `/get-patterns-analysis-markdown` | Markdown pattern/usage analysis report |

### Chatbot
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/chat` | Eco-Assistant chatbot (Mistral AI + RAG knowledge base) |

## Quick Start

### 1. Install Dependencies
```sh
pip install -r requirements.txt
```

### 2. Configure Firebase
- Create a project on [Firebase Console](https://console.firebase.google.com/).
- Go to **Project Settings → Service Accounts**.
- Click **Generate new private key** to download the JSON file.
- Place this file as `firebase_key.json` inside the `statics/` folder.
- Set your database URL in `utils/constants.py`.

### 3. Configure Environment Variables
Create a `.env` file at the project root:
```env
MISTRAL_API_KEY=your_mistral_api_key_here
MISTRAL_MODEL=mistral-small-latest   # optional, this is the default
```

### 4. Set Up the Chatbot Knowledge Base
Place a `knowledge_base.txt` file in the `static/` directory. This text will be automatically injected into the chatbot's system prompt to enable RAG (Retrieval-Augmented Generation) for context-aware waste management answers.

### 5. Start the Server
```sh
python run.py
```
or
```sh
uvicorn run:app --reload
```

### 6. Access the Web Dashboard
Open `statics/index.html` in a browser, or navigate to `http://localhost:8000`.

## Background Services (Auto-started on Startup)

| Service | Interval | Description |
|---------|----------|-------------|
| Firebase RTDB Listener | Real-time | Syncs bin data changes to MongoDB |
| Level Prediction Loop | `LEVEL_PREDICTION_INTERVAL` | Periodically updates fill-level predictions for all bins |
| Notification Loop | `NOTIFICATION_INTERVAL` | Checks thresholds and sends FCM alerts |
| Server URL Registration | Once at startup | Writes the server's local IP to Firebase RTDB |

## Technologies Used

| Category | Technologies |
|----------|-------------|
| Backend | Python 3, FastAPI, Uvicorn |
| Database | MongoDB (PyMongo), Firebase RTDB & FCM |
| AI / ML | PyTorch, TorchVision, DenseNet201, scikit-learn, Mistral AI API |
| Data | Pandas, NumPy |
| Async | `asyncio`, `threading`, `httpx` |
| Reports | ReportLab (PDF), Jinja2 |
| Utilities | `python-dotenv`, `Pillow`, `joblib` |
| Frontend | HTML / JS / CSS |

## Authors

- [WAM Development](https://github.com/walid-moussa55)

## Useful Links

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Firebase Admin Python SDK](https://firebase.google.com/docs/admin/setup)
- [PyMongo Documentation](https://pymongo.readthedocs.io/en/stable/)
- [Uvicorn](https://www.uvicorn.org/)
- [Mistral AI Documentation](https://docs.mistral.ai/)
- [PyTorch Documentation](https://pytorch.org/docs/)
- [Pandas Documentation](https://pandas.pydata.org/docs/)
- [Firebase Console](https://console.firebase.google.com/)

---

**SmartTrash** — Optimize urban waste management through data intelligence and AI!

---