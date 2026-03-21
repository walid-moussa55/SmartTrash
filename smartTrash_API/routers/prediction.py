import os
import tempfile
from fastapi import APIRouter, HTTPException, Request
from typing import Optional
from utils.helper import to_python_type

# Import prediction state from the new module
from others.prediction_state import last_level_prediction
from predictions.prediction_type import TypePredictionmodel
from predictions.predictionLvl import predict_weekly

router = APIRouter()

@router.get("/prediction")
async def get_prediction(bin_id: Optional[str] = None):
    if last_level_prediction is None:
        raise HTTPException(status_code=404, detail="No prediction available yet")
    
    if bin_id:
        if bin_id not in last_level_prediction:
            raise HTTPException(status_code=404, detail=f"No prediction found for bin ID {bin_id}")
        return last_level_prediction[bin_id]
    
    return last_level_prediction

@router.get("/prediction/weekly")
async def get_weekly_prediction():
    """Return 7-day fill level predictions for all bins with resource planning."""
    if not last_level_prediction:
        raise HTTPException(status_code=404, detail="No prediction data available yet")

    from datetime import datetime, timedelta
    day_names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche']
    today = datetime.now()
    today_weekday = today.weekday()

    weekly = {}
    for day_offset in range(7):
        day_index = (today_weekday + day_offset) % 7
        day_date = today + timedelta(days=day_offset)
        day_key = day_names[day_index]
        day_bins = []

        for bin_id, pred_data in last_level_prediction.items():
            current_level = pred_data.get('current_level', 0)
            try:
                levels_7days = predict_weekly(current_level)
                predicted_level = levels_7days[day_offset] if day_offset < len(levels_7days) else current_level
            except Exception:
                predicted_level = current_level

            day_bins.append({
                'bin_id': bin_id,
                'bin_name': pred_data.get('bin_name', 'Unknown'),
                'predicted_level': round(float(predicted_level), 1),
            })

        full_bins = sum(1 for b in day_bins if b['predicted_level'] >= 80)
        # Industry-standard values (sources: ISWA, NREL, World Bank "What a Waste 2.0")
        BINS_PER_TRUCK = 25    # Large public containers per rear-loader route
        WORKERS_PER_TRUCK = 3  # 1 driver + 2 collectors (ISWA standard)
        FUEL_PER_TRUCK = 35    # Liters of diesel per urban collection route (~70 km)
        trucks = max(1, -(-full_bins // BINS_PER_TRUCK)) if full_bins > 0 else 0

        weekly[day_key] = {
            'date': day_date.strftime('%Y-%m-%d'),
            'bins': day_bins,
            'resources': {
                'full_bins': full_bins,
                'trucks_needed': trucks,
                'workers_needed': trucks * WORKERS_PER_TRUCK,
                'fuel_liters': trucks * FUEL_PER_TRUCK,
            }
        }

    return weekly

# Initialize TypePredictionmodel (lazy, with error handling)
predictor = None
try:
    predictor = TypePredictionmodel(file_path="weights_pth/densenet201_garbage.pth")
    print("[Prediction] TypePredictionmodel loaded successfully.")
except Exception as e:
    print(f"[Prediction] Warning: Failed to load TypePredictionmodel: {e}")

# --- trash image prediction endpoint ---
@router.post("/predict/trash_type")
async def predict_trash_type(request: Request):
    if predictor is None:
        raise HTTPException(status_code=503, detail="Trash type prediction model is not available.")

    form = await request.form()
    file = form.get("file")
    
    if not file:
        raise HTTPException(status_code=400, detail="No file provided")
    
    tmp_file_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
            tmp_file.write(file.file.read())
            tmp_file_path = tmp_file.name
        
        predicted_class = predictor.predict(tmp_file_path)
        return {"predicted_class": predicted_class}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error during prediction: {str(e)}")
    finally:
        if tmp_file_path and os.path.exists(tmp_file_path):
            os.remove(tmp_file_path)