import os
import tempfile
from fastapi import APIRouter, HTTPException, Request
from predictions.prediction_type import TypePredictionmodel

router = APIRouter()

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
    """Predict the type of trash from an image with inference time."""
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
        
        result = predictor.predict(tmp_file_path)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error during prediction: {str(e)}")
    finally:
        if tmp_file_path and os.path.exists(tmp_file_path):
            os.remove(tmp_file_path)