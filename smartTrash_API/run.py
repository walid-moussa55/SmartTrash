from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import pandas as pd
import uvicorn
import firebase_admin
from firebase_admin import credentials, db, messaging
import threading
from predictions.predictionLvl import next_level
import asyncio
from others.database import MongoDB
# --- Import necessary modules ---
from services.notification_service import NotificationService
from others.models import TrashData
# --- Constants ---
from utils.constants import (
    FCM_TOPIC,
    FIREBASE_URL,
    HT_PREDICTION_INTERVAL,
    NOTIFICATION_INTERVAL,
    LEVEL_PREDICTION_INTERVAL,
)
from predictions.predictionTH import HTPredictor
from others.prediction_state import (
    last_level_prediction,
    level_prediction_timestamp,
    last_ht_prediction,
    ht_prediction_timestamp,
)

from utils.helper import get_local_ip, to_python_type
# --- Import prediction endpoints router ---
from routers.prediction import router as prediction_router
from routers.report import router as report_router
from routers.bins import router as bins_router

# --- Firebase Setup ---
def initialize_firebase():
    cred = credentials.Certificate("statics/firebase_key.json")
    app = firebase_admin.initialize_app(cred, {
        "databaseURL": FIREBASE_URL
    })
    
    # Create topics if they don't exist
    topics = [FCM_TOPIC, f"{FCM_TOPIC}_gas", f"{FCM_TOPIC}_emergency"]
    for topic in topics:
        try:
            messaging.subscribe_to_topic([], topic)
        except Exception as e:
            print(f"Topic {topic} already exists or error: {e}")
    
    return app

# --- FastAPI App ---
app = FastAPI()

# Initialize MongoDB after FastAPI app initialization
try:
    db_mongo = MongoDB()
except Exception as e:
    print(f"Failed to initialize MongoDB: {e}")
    print("Starting API without MongoDB functionality")
    db_mongo = None

notification_service = NotificationService(db_mongo=db_mongo)

# After db_mongo and analytics initialization
ht_predictor = HTPredictor()

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- API Routes ---
@app.get("/")
async def read_root():
    return {"message": "Welcome to the Waste Collection Optimization API"}


@app.post("/update/{bin_id}")
async def update_trash_bin(bin_id: str, data: TrashData):
    try:
        ref = db.reference(f"trash_bins/{bin_id}")
        ref.set(data.dict())
        return {"status": "success", "bin_id": bin_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/read/{bin_id}")
async def read_trash_bin(bin_id: str):
    try:
        ref = db.reference(f"trash_bins/{bin_id}")
        data = ref.get()
        if not data:
            raise HTTPException(status_code=404, detail="Bin not found")
        return {"bin_id": bin_id, "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def handle_data_change(event):
        print(f"RTDB Data Change Detected: Type={event.event_type}, Path={event.path}")
        
        if event.data is None:
            return

        try:
            all_bins_data = event.data if event.path == '/' else {
                event.path.strip('/'): db.reference(f"trash_bins/{event.path.strip('/')}").get()
            }

            for bin_id, bin_value in all_bins_data.items():
                if not isinstance(bin_value, dict):
                    continue

                try:
                    bin_value['bin_id'] = bin_id  # Ensure bin_id is set
                    bin_data = TrashData(**bin_value)
                    # Store in MongoDB
                    db_mongo.store_bin_data(bin_id, bin_value)
                except Exception as e:
                    print(f"Error processing bin '{bin_id}': {e}")

        except Exception as e:
            print(f"Error in handle_data_change: {e}")

# --- Firebase Listener ---
def start_rtdb_listener():
    try:
        ref = db.reference('trash_bins')
        print(f"Listening to Firebase RTDB path: {ref.path}")
        ref.listen(handle_data_change)
    except Exception as e:
        print(f"Error starting RTDB listener: {e}")

@app.on_event("startup")
async def startup_event():
    print("FastAPI startup event: Initializing Firebase and RTDB listener...")
    try:
        initialize_firebase()
        listener_thread = threading.Thread(target=start_rtdb_listener, daemon=True)
        listener_thread.start()
        print("Firebase RTDB listener thread started.")

        # Send server IP to Firebase RTDB
        local_ip = get_local_ip()
        server_url = f"http://{local_ip}:8000"
        try:
            ref = db.reference('app_settings/rotageServerUrl')
            ref.set(server_url)
            print(f"Server URL '{server_url}' sent to Firebase RTDB.")
        except Exception as e:
            print(f"Failed to update server URL in Firebase: {e}")

        # Start prediction loop in background
        asyncio.create_task(level_prediction_loop())
        print("Prediction loop started.")
        asyncio.create_task(ht_prediction_loop())
        print("HT prediction loop started.")
        asyncio.create_task(scheduled_notification_loop())
        print("Scheduled notification loop started.")

    except Exception as e:
        print(f"Failed to initialize Firebase or start RTDB listener: {e}")

async def level_prediction_loop():
    global last_level_prediction, level_prediction_timestamp
    while True:
        try:
            ref = db.reference('trash_bins')
            bins_data = ref.get()
            
            if bins_data:
                now = datetime.now().isoformat()
                for bin_id, bin_data in bins_data.items():
                    try:
                        current_level = bin_data['trash_level']
                        
                        # Make prediction for this bin
                        predicted_value = next_level(current_level)
                                                
                        # Store prediction for this bin
                        last_level_prediction[bin_id] = {
                            'predicted_level': float(predicted_value),
                            'current_level': float(current_level),
                            'bin_name': bin_data.get('name', 'Unknown'),
                            'timestamp': now
                        }
                        level_prediction_timestamp[bin_id] = datetime.now()                        
                    except Exception as e:
                        print(f"Error predicting for bin {bin_id}: {e}")
                        continue
                print(f"Level predictions updated at {now}")
            else:
                print("No bins data found in Firebase RTDB.")   
            await asyncio.sleep(LEVEL_PREDICTION_INTERVAL)
        except Exception as e:
            print(f"Error in level_prediction loop: {e}")
            await asyncio.sleep(60)  # Wait a minute before retrying

async def ht_prediction_loop():
    global last_ht_prediction, ht_prediction_timestamp
    while True:
        try:
            # Get current state for all bins from MongoDB
            bins = list(db_mongo.bins_current.find({}, {'_id': 0, 'bin_id': 1, 'temperature': 1, 'humidity': 1}))
            now = pd.Timestamp.now()
            current_state = {
                b['bin_id']: {
                    "time": now,
                    "temp": b.get('temperature', 25.0),
                    "rhum": b.get('humidity', 60.0)
                }
                for b in bins
            }
            predictions = ht_predictor.predict(current_state)
            last_ht_prediction = predictions
            ht_prediction_timestamp = {bin_id: now.isoformat() for bin_id in predictions}
            print(f"HT predictions updated at {now}")
            await asyncio.sleep(HT_PREDICTION_INTERVAL)
        except Exception as e:
            print(f"Error in ht_prediction_loop: {e}")
            await asyncio.sleep(60)

async def scheduled_notification_loop():
    while True:
        try:
            # Get all current bins from MongoDB
            bins = list(db_mongo.bins_current.find({}, {'_id': 0}))
            for bin_data in bins:
                try:
                    # Convert dict to TrashData model
                    bin_obj = TrashData(**bin_data)
                    bin_id = bin_obj.bin_id
                    # This will send notification if threshold is met
                    notification_service._process_bin_data(bin_id, bin_obj)
                except Exception as e:
                    print(f"Error processing bin for scheduled notification: {e}")
            print(f"Scheduled notifications checked at {datetime.now()}")
            await asyncio.sleep(NOTIFICATION_INTERVAL)
        except Exception as e:
            print(f"Error in scheduled_notification_loop: {e}")
            await asyncio.sleep(60)

# --- Include prediction endpoints router ---
app.include_router(prediction_router)

# --- Prediction endpoints ---
@app.get("/prediction/ht")
async def get_ht_prediction(bin_id: Optional[str] = None):
    if not last_ht_prediction:
        raise HTTPException(status_code=404, detail="No HT prediction available yet")
    result = last_ht_prediction
    if bin_id:
        if bin_id not in last_ht_prediction:
            raise HTTPException(status_code=404, detail=f"No HT prediction for bin {bin_id}")
        result = {bin_id: last_ht_prediction[bin_id]}
    return to_python_type(result)


# --- Include report generation endpoints ---
app.include_router(report_router)

# --- Include bins management endpoints ---
app.include_router(bins_router)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

